document.getElementById('extension-id').textContent = chrome.runtime.id;
async function refresh() {
  try {
    const state = await chrome.runtime.sendMessage({ type: 'status' });
    const status = document.getElementById('status');
    const dot = document.getElementById('status-dot');
    status.textContent = state.active ? `Focus is on · ${state.domains.length} website${state.domains.length === 1 ? '' : 's'}` :
      state.connected ? 'Connected · sites are unlocked' : 'Connect settime to get started';
    dot.className = 'status-dot' + (state.active ? ' active' : state.connected ? '' : ' warning');
    document.getElementById('error').textContent = state.connected ? '' :
      (state.error || 'Paste your extension ID into settime → Browser Focus → Connect Chrome.');
  } catch {
    document.getElementById('status').textContent = 'Extension unavailable';
    document.getElementById('error').textContent = 'Reload this extension in chrome://extensions.';
    document.getElementById('status-dot').className = 'status-dot warning';
  }
}
void refresh(); setInterval(refresh, 1000);
