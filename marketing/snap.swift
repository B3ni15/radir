// Egy HTML oldal képe pontos méretben (WebKit, a radir mappából futtatva).
// swift marketing/snap.swift <oldal.html> <kimenet.jpg|png> <szélesség> <magasság>
import AppKit
import WebKit

setvbuf(stdout, nil, _IONBF, 0)
let a = CommandLine.arguments
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let page = root.appending(path: a[1]), out = root.appending(path: a[2])
let (W, H) = (Int(a[3])!, Int(a[4])!)

final class Snap: NSObject, WKNavigationDelegate {
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: W, height: H))
    func start() { web.navigationDelegate = self; web.loadFileURL(page, allowingReadAccessTo: root) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            do {
                _ = try await webView.callAsyncJavaScript(
                    "await document.fonts.ready; await Promise.all([...document.images].map(i => i.decode().catch(() => {}))); return 1",
                    contentWorld: .page)
                let image = try await webView.takeSnapshot(configuration: nil)
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                image.draw(in: NSRect(x: 0, y: 0, width: W, height: H))
                NSGraphicsContext.restoreGraphicsState()
                let data = out.pathExtension == "png" ? rep.representation(using: .png, properties: [:])!
                                                      : rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
                try data.write(to: out)
                print("kész: \(out.path)")
                exit(0)
            } catch { print("hiba: \(error)"); exit(1) }
        }
    }
}

let app = NSApplication.shared
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H), styleMask: [.borderless], backing: .buffered, defer: false)
let snap = Snap()
window.contentView = snap.web
snap.start()
app.run()
