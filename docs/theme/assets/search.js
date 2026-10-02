(() => {
  const input = document.getElementById('search-query');
  const output = document.getElementById('search-results');
  let index, documents;
  function search() {
    output.replaceChildren();
    if (!index) { output.textContent = 'Loading search index…'; return; }
    const query = input.value.trim();
    if (query.length < 2) { output.textContent = 'Enter at least two characters.'; return; }
    let matches;
    try { matches = index.search(query); }
    catch (_) { output.textContent = 'Try a word or an API name, such as fold_left.'; return; }
    if (!matches.length) { output.textContent = 'No matching pages. Try a broader term.'; return; }
    for (const match of matches.slice(0, 20)) {
      const doc = documents[match.ref];
      const article = document.createElement('article');
      const heading = document.createElement('h2');
      const link = document.createElement('a'); link.href = `${base_url}/${doc.location}`; link.textContent = doc.title;
      const text = document.createElement('p'); text.textContent = doc.text.slice(0, 240) + (doc.text.length > 240 ? '…' : '');
      heading.append(link); article.append(heading, text); output.append(article);
    }
  }
  input.addEventListener('input', search);
  fetch(`${base_url}/search/search_index.json`).then(response => {
    if (!response.ok) throw new Error('Search index unavailable'); return response.json();
  }).then(data => {
    documents = Object.fromEntries(data.docs.map(doc => [doc.location, doc]));
    index = lunr(function () { this.ref('location'); this.field('title', {boost: 8}); this.field('text'); data.docs.forEach(doc => this.add(doc)); });
    input.value = new URLSearchParams(window.location.search).get('q') || ''; search(); input.focus();
  }).catch(() => { output.textContent = 'Search could not load. Serve the site over HTTP with pixi run docs-serve.'; });
})();
