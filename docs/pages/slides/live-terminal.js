// =============================================================================
// Packathon - Live Terminal Resolver & Launcher for Presentations
// =============================================================================

(function (window) {
  'use strict';

  const STORAGE_KEY = 'packathon_terminal_url';

  function getTerminalUrl() {
    const params = new URLSearchParams(window.location.search);
    if (params.has('term')) {
      const term = params.get('term');
      localStorage.setItem(STORAGE_KEY, term);
      return term;
    }
    return localStorage.getItem(STORAGE_KEY) || '';
  }

  function openLiveTerminal() {
    let url = getTerminalUrl();
    if (!url) {
      const isIt = (document.documentElement.lang === 'it');
      url = prompt(
        isIt
          ? "Inserisci l'URL del terminale ttyd (es. https://<codespace>-7681.app.github.dev o http://localhost:7681):"
          : "Enter ttyd terminal URL (e.g. https://<codespace>-7681.app.github.dev or http://localhost:7681):",
        "http://localhost:7681"
      );
      if (url && url.trim()) {
        url = url.trim();
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://' + url;
        }
        localStorage.setItem(STORAGE_KEY, url);
      } else {
        return;
      }
    }
    window.open(url, '_blank');
  }

  function configureTerminalUrl() {
    const current = getTerminalUrl();
    const isIt = (document.documentElement.lang === 'it');
    const newUrl = prompt(
      isIt
        ? "Configura o aggiorna l'URL del terminale ttyd (o premi 'T'):"
        : "Configure or update ttyd terminal URL (or press 'T'):",
      current || "http://localhost:7681"
    );
    if (newUrl !== null) {
      const trimmed = newUrl.trim();
      if (trimmed) {
        let finalUrl = trimmed;
        if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
          finalUrl = 'https://' + finalUrl;
        }
        localStorage.setItem(STORAGE_KEY, finalUrl);
      } else {
        localStorage.removeItem(STORAGE_KEY);
      }
    }
  }

  // Keyboard shortcut: Press 'T' to configure terminal URL
  window.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (!e.ctrlKey && !e.metaKey && !e.altKey && (e.key === 't' || e.key === 'T')) {
      configureTerminalUrl();
    }
  });

  // Inject standard styling for .terminal-btn so markdown stays minimal
  const style = document.createElement('style');
  style.textContent = `
    .terminal-btn {
      display: inline-block;
      margin-top: 15px;
      padding: 8px 16px;
      background: #2563eb;
      color: #ffffff !important;
      font-size: 0.8em;
      font-weight: 600;
      border: 1px solid #3b82f6;
      border-radius: 6px;
      cursor: pointer;
      text-decoration: none;
      transition: background 0.2s ease;
    }
    .terminal-btn:hover {
      background: #1d4ed8;
    }
  `;
  document.head.appendChild(style);

  // Export to global scope
  window.openLiveTerminal = openLiveTerminal;
  window.configureTerminalUrl = configureTerminalUrl;
  window.getTerminalUrl = getTerminalUrl;

})(window);
