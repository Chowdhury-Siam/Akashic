(() => {
  const config = window.YUTAKA_SITE || {};
  const menu = document.getElementById('menu-toggle');
  const nav = document.getElementById('site-nav');
  menu?.addEventListener('click', () => {
    const open = menu.getAttribute('aria-expanded') !== 'true';
    menu.setAttribute('aria-expanded', String(open));
    menu.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    nav?.classList.toggle('open', open);
  });
  nav?.querySelectorAll('a').forEach(a => a.addEventListener('click', () => {
    nav.classList.remove('open'); menu?.setAttribute('aria-expanded', 'false');
  }));
  document.getElementById('year').textContent = String(new Date().getFullYear());
  const stores = { play: config.playStoreUrl, microsoft: config.microsoftStoreUrl };
  document.querySelectorAll('[data-store]').forEach(link => {
    const url = stores[link.dataset.store];
    if (typeof url === 'string' && /^https:\/\//.test(url)) {
      link.href = url; link.target = '_blank'; link.rel = 'noopener noreferrer'; link.removeAttribute('aria-disabled');
      link.querySelector('.download-status').textContent = '↗';
    } else { link.removeAttribute('href'); link.setAttribute('aria-disabled', 'true'); }
  });
  if (/^https:\/\//.test(config.githubUrl || '')) {
    document.querySelectorAll('[data-github], #github-link').forEach(link => { link.href = config.githubUrl; });
  }
})();
