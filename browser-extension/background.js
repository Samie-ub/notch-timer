import { idle, normalizeState, rulesFor } from './focus.js';
let state = idle();
let connected = false;
let port;
let lastReply = 0;
let lastRequest = 0;
let error = '';
let queue = Promise.resolve();
let appliedKey;

// Serialize rule mutations; stale active updates must never overtake an unlock.
function apply(value) {
  state = normalizeState(value);
  queue = queue.catch(() => {}).then(async () => {
    state = normalizeState(state);
    const rules = rulesFor(state);
    const key = JSON.stringify(rules);
    if (key !== appliedKey) {
      const old = await chrome.declarativeNetRequest.getSessionRules();
      await chrome.declarativeNetRequest.updateSessionRules({ removeRuleIds: old.map(r => r.id), addRules: rules });
      appliedKey = key;
    }
    await chrome.action.setBadgeText({ text: state.active ? 'ON' : '' });
    await chrome.action.setBadgeBackgroundColor({ color: '#25784b' });
    const tabs = await chrome.tabs.query({});
    await Promise.allSettled(tabs.map(tab => chrome.tabs.sendMessage(tab.id, { type: 'focus', state })));
  }).catch(async failure => {
    error = `Focus could not be applied: ${failure.message}`;
    state = idle();
    appliedKey = undefined;
    // Best effort rollback; the watchdog retries if the API temporarily fails.
    const old = await chrome.declarativeNetRequest.getSessionRules();
    await chrome.declarativeNetRequest.updateSessionRules({ removeRuleIds: old.map(r => r.id) });
  });
  return queue;
}
function connect() {
  if (port) return;
  try {
    const current = chrome.runtime.connectNative('com.local.notchtimer.focus');
    port = current;
    lastReply = Date.now();
    current.onMessage.addListener(value => {
      if (port !== current) return;
      connected = true;
      lastReply = Date.now();
      error = '';
      void apply(value);
    });
    current.onDisconnect.addListener(() => {
      const reason = chrome.runtime.lastError?.message;
      if (port !== current) return;
      port = undefined;
      connected = false;
      error = reason || 'Connection closed. Sites are unlocked.';
      void apply(idle());
    });
    lastRequest = Date.now();
    current.postMessage({ type: 'status' });
  } catch (failure) {
    port = undefined;
    connected = false;
    error = failure.message;
    void apply(idle());
  }
}
function poll() {
  if (state.active && state.expiresAt <= Date.now() / 1000) void apply(idle());
  if (port && Date.now() - lastReply > 5000) {
    const old = port;
    port = undefined;
    connected = false;
    old.disconnect();
    void apply(idle());
  }
  if (!port) connect();
  else if (Date.now() - lastRequest >= 1000) {
    try { lastRequest = Date.now(); port.postMessage({ type: 'status' }); }
    catch { port = undefined; connected = false; void apply(idle()); }
  }
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (sender.id !== chrome.runtime.id || message?.type !== 'status') return;
  poll();
  queue.then(() => respond({ ...normalizeState(state), connected, error })).catch(() => respond({ ...idle(), connected: false, error }));
  return true;
});
chrome.alarms.onAlarm.addListener(poll);
chrome.runtime.onStartup.addListener(poll);
chrome.runtime.onInstalled.addListener(async () => {
  // Cover pages that were already open when the extension was installed/reloaded.
  const tabs = await chrome.tabs.query({});
  await Promise.allSettled(tabs.filter(tab => /^https?:/.test(tab.url || '')).map(tab =>
    chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['overlay.js'] })));
  poll();
});
// Native ports keep the worker alive; alarms recover it after termination.
void chrome.alarms.create('focus-watchdog', { periodInMinutes: 0.5 });
void apply(idle()).then(connect);
setInterval(poll, 1000);
