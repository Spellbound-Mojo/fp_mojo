(() => {
  let dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  try { const saved = localStorage.getItem('fp-mojo-theme'); if (saved) dark = saved === 'dark'; } catch (_) {}
  document.documentElement.className = dark ? 'github-dimmed' : 'catppuccin-light';
})();
