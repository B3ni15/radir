// KRÉTA API doksi: másolás gomb a kódblokkokon, és a tartalomjegyzékben az éppen olvasott fejezet kiemelése.
document.querySelectorAll('.code .copy').forEach((button) => {
  button.addEventListener('click', async () => {
    const text = button.parentElement.querySelector('pre').innerText;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = 'Másolva';
    } catch {
      button.textContent = 'Nem sikerült';
    }
    setTimeout(() => { button.textContent = 'Másolás'; }, 1600);
  });
});

const links = new Map([...document.querySelectorAll('.toc a')].map((a) => [a.getAttribute('href').slice(1), a]));
const observer = new IntersectionObserver((entries) => {
  for (const e of entries) {
    if (!e.isIntersecting) continue;
    links.forEach((a) => a.classList.remove('on'));
    links.get(e.target.id)?.classList.add('on');
  }
}, { rootMargin: '-96px 0px -70% 0px' });
links.forEach((_, id) => { const el = document.getElementById(id); if (el) observer.observe(el); });
