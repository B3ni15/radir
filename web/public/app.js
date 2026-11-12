// Radír landing: sima görgetés (Lenis) és a görgetésre forgó 3D telefon.
(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const tour = document.querySelector('.tour');
  const stage = tour.querySelector('.stage');
  const phone = tour.querySelector('.phone3d');
  const screens = [...phone.querySelectorAll('.front img')];
  const steps = [...tour.querySelectorAll('.step')];
  const titles = [...tour.querySelectorAll('.titles li')];

  // a telefon pereme: egymás mögötti lekerekített rétegek, így oldalról is kerek
  const layers = phone.querySelector('.layers');
  for (let z = -12; z <= 12; z += 2) {
    const i = document.createElement('i');
    i.style.transform = `translateZ(${z}px)`;
    layers.append(i);
  }

  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const ease = (t) => 1 - Math.pow(1 - t, 3);
  const INTRO = 0.14; // ennyi idő alatt fordul elő a hátoldalról
  let current = -1;

  function show(index) {
    if (index === current) return;
    current = index;
    screens.forEach((el, i) => el.classList.toggle('on', i === index));
    steps.forEach((el, i) => el.classList.toggle('on', i === index));
    titles.forEach((el, i) => el.classList.toggle('on', i === index));
    stage.classList.toggle('is-night', index === steps.length - 1);
  }

  function update() {
    const r = tour.getBoundingClientRect();
    const p = clamp(-r.top / (r.height - innerHeight));
    let rx, ry, s, index;
    if (p < INTRO) {
      const t = ease(p / INTRO);
      ry = lerp(200, -14, t); rx = lerp(16, 4, t); s = lerp(.86, 1, t); index = 0;
    } else {
      const q = (p - INTRO) / (1 - INTRO) * steps.length; // 0 … 5
      index = Math.min(steps.length - 1, Math.floor(q));
      ry = -14 * Math.cos(Math.PI * q); rx = 4 + 3 * Math.sin(Math.PI * q); s = 1;
    }
    if (reduce) { ry = -10; rx = 3; s = 1; }
    phone.style.setProperty('--ry', ry.toFixed(2) + 'deg');
    phone.style.setProperty('--rx', rx.toFixed(2) + 'deg');
    phone.style.setProperty('--s', s.toFixed(3));
    show(index);
  }

  let queued = false;
  const onScroll = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => { queued = false; update(); });
  };

  // Lenis csak akkor, ha betöltött és nincs csökkentett mozgás; különben natív görgetés
  if (!reduce && window.Lenis) {
    const lenis = new Lenis({ lerp: 0.1, anchors: true });
    lenis.on('scroll', update);
    const raf = (t) => { lenis.raf(t); requestAnimationFrame(raf); };
    requestAnimationFrame(raf);
  } else {
    addEventListener('scroll', onScroll, { passive: true });
  }
  addEventListener('resize', onScroll);
  update();
})();
