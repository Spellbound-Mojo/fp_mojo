(() => {
  const toggle = document.getElementById('theme-toggle');
  const labelTheme = () => toggle.setAttribute('aria-label', document.documentElement.classList.contains('github-dimmed') ? 'Switch to light theme' : 'Switch to dark theme');
  labelTheme();
  toggle.addEventListener('click', () => {
    const dark = !document.documentElement.classList.contains('github-dimmed');
    document.documentElement.className = dark ? 'github-dimmed' : 'catppuccin-light';
    try { localStorage.setItem('fp-mojo-theme', dark ? 'dark' : 'light'); } catch (_) {}
    labelTheme();
  });
  const button = document.getElementById('nav-toggle');
  const closeNav = () => { document.body.classList.remove('nav-open'); button.setAttribute('aria-expanded', 'false'); };
  button.addEventListener('click', () => {
    const open = document.body.classList.toggle('nav-open');
    button.setAttribute('aria-expanded', String(open));
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') { closeNav(); button.focus(); }
    if (event.key === '/' && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) {
      event.preventDefault(); window.location.href = `${base_url}/search/`;
    }
  });
  document.querySelectorAll('pre').forEach(pre => {
    const code = pre.querySelector('code');
    if (!code || !navigator.clipboard) return;
    const copy = document.createElement('button');
    copy.className = 'copy-code'; copy.textContent = 'Copy'; copy.setAttribute('aria-label', 'Copy code');
    copy.addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(code.textContent); copy.textContent = 'Copied'; }
      catch (_) { copy.textContent = 'Select to copy'; }
      setTimeout(() => { copy.textContent = 'Copy'; }, 1800);
    });
    pre.parentElement.classList.add('code-container'); pre.parentElement.append(copy);
  });
})();
