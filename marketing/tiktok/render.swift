// A video.html-t WebKittel rendereli 60 fps-sel, és ffmpeg-gel összerakja a zenével.
// Használat (a radir mappából):
//   swift marketing/tiktok/render.swift video <zene.mp3>      → marketing/tiktok/brag.mp4
//   swift marketing/tiktok/render.swift stills 1.0 7.3 …      → marketing/tiktok/work/still-<t>.jpg
import AppKit
import WebKit

setvbuf(stdout, nil, _IONBF, 0)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let dir = root.appending(path: "marketing/tiktok")
let args = Array(CommandLine.arguments.dropFirst())
let (W, H, FPS, DURATION) = (1080, 1920, 60, 22.04)
let POSTER_T = 9.0 // ez kerül a 0. képkockára (borítókép)

final class Renderer: NSObject, WKNavigationDelegate {
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 540, height: 960))
    var ffmpeg: Process?
    var pipe: FileHandle?

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { print("hiba: \(error)"); exit(1) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { print("hiba: \(error)"); exit(1) }

    func start() {
        web.navigationDelegate = self
        web.loadFileURL(dir.appending(path: "video.html"), allowingReadAccessTo: root)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            do {
                print("betöltve, várakozás a betűkre és képekre")
                _ = try await webView.callAsyncJavaScript("await window.ready; return 1", contentWorld: .page)
                print("kész a betöltés")
                if args.first == "stills" {
                    for s in args.dropFirst() {
                        let data = try await frame(Double(s)!)
                        try data.write(to: dir.appending(path: "work/still-\(s).jpg"))
                    }
                } else {
                    try await video(audio: args.dropFirst().first!)
                }
                exit(0)
            } catch {
                print("hiba: \(error)")
                exit(1)
            }
        }
    }

    func frame(_ t: Double) async throws -> Data {
        // rejtett ablakban nincs requestAnimationFrame; a layout kikényszerítése után a snapshot az új állapotot rajzolja
        _ = try await web.callAsyncJavaScript("render(t); await Promise.all([...document.querySelectorAll('#scr img')].filter(i => i.style.opacity === '1').map(i => i.decode().catch(() => {}))); document.body.offsetHeight; return 1",
                                              arguments: ["t": t], contentWorld: .page)
        let cfg = WKSnapshotConfiguration()
        cfg.rect = CGRect(x: 0, y: 0, width: 540, height: 960)
        let image = try await web.takeSnapshot(configuration: cfg)
        // pontosan 1080×1920-ra rajzolva (Retina 2× és 1× kijelzőn is)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: W, height: H))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.95])!
    }

    func video(audio: String) async throws {
        let out = dir.appending(path: "brag.mp4").path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        // a zene vége (20,6 s-tól) elhalkul: ez a lecsengés
        p.arguments = ["-v", "error", "-y", "-f", "image2pipe", "-framerate", "\(FPS)", "-c:v", "mjpeg", "-i", "-",
                       "-i", audio, "-af", "afade=t=out:st=20.6:d=1.44",
                       "-c:v", "libx264", "-preset", "slow", "-crf", "15", "-pix_fmt", "yuv420p", "-r", "\(FPS)",
                       "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", "-shortest", out]
        let inPipe = Pipe()
        p.standardInput = inPipe
        try p.run()
        let count = Int((DURATION * Double(FPS)).rounded())
        for i in 0..<count {
            let t = i == 0 ? POSTER_T : Double(i) / Double(FPS)
            inPipe.fileHandleForWriting.write(try await frame(t))
            if i % 120 == 0 { print("képkocka \(i)/\(count)") }
        }
        try inPipe.fileHandleForWriting.close()
        p.waitUntilExit()
        print("kész: \(out)")
    }
}

let app = NSApplication.shared
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 960), styleMask: [.borderless], backing: .buffered, defer: false)
let renderer = Renderer()
window.contentView = renderer.web
renderer.start()
app.run()
