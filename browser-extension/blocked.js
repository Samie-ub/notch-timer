document.getElementById('back').addEventListener('click', () => history.back());
async function refresh() {
  let state;
  try { state = await chrome.runtime.sendMessage({ type: 'status' }); } catch { state = { active: false }; }
  const active = state.active && state.expiresAt > Date.now() / 1000;
  document.getElementById('title').textContent = active ? 'Focus session active' : 'You’re free to browse';
  const seconds = Math.ceil(state.remaining || 0);
  document.getElementById('status').textContent = active
    ? `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')} remaining. Take this moment to return to your task.`
    : 'Sites are unlocked. Enter the website address again or go back.';
}
void refresh(); setInterval(refresh, 1000);
