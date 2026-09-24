import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import { idle, normalizeState, rulesFor } from '../../browser-extension/focus.js';

test('expired, malformed, and disabled sessions fail open', () => {
  const good = { active: true, domains: ['youtube.com'], remaining: 100, expiresAt: 104 };
  assert.equal(normalizeState(good, 100).active, true);
  for (const value of [null, {}, { ...good, expiresAt: 100 }, { ...good, expiresAt: 106 },
    { ...good, active: false }, { ...good, remaining: NaN }, { ...good, domains: ['*.com'] }]) {
    assert.deepEqual(normalizeState(value, 100), idle());
  }
  assert.equal(rulesFor(good)[0].condition.resourceTypes[0], 'main_frame');
  assert.deepEqual(rulesFor(good)[0].condition.requestMethods, ['get']);
  assert.deepEqual(rulesFor(idle()), []);
});

test('worker removes rules on native disconnect and lease expiry', async () => {
  let rules = [{ id: 99 }];
  let interval;
  let onMessage;
  let onDisconnect;
  let now = 100_000;
  const event = () => ({ addListener() {} });
  const chrome = {
    runtime: {
      id: 'test', onMessage: event(), onStartup: event(), onInstalled: event(),
      connectNative() { return {
        onMessage: { addListener(fn) { onMessage = fn; } },
        onDisconnect: { addListener(fn) { onDisconnect = fn; } },
        postMessage() {}, disconnect() {}
      }; }
    },
    declarativeNetRequest: {
      async getSessionRules() { return rules; },
      async updateSessionRules({ removeRuleIds, addRules = [] }) {
        rules = [...rules.filter(r => !removeRuleIds.includes(r.id)), ...addRules];
      }
    },
    action: { async setBadgeText() {}, async setBadgeBackgroundColor() {} },
    tabs: { async query() { return []; }, async sendMessage() {} },
    alarms: { onAlarm: event(), async create() {} }
  };
  const context = vm.createContext({ chrome, idle, normalizeState: value => normalizeState(value, now / 1000), rulesFor,
    Date: { now: () => now }, setInterval(fn) { interval = fn; } });
  const source = (await readFile(new URL('../../browser-extension/background.js', import.meta.url), 'utf8')).replace(/^import .*\n/, '');
  vm.runInContext(source, context);
  const settle = () => new Promise(resolve => setImmediate(resolve));
  await settle();
  assert.equal(rules.length, 0, 'clears stale rules on worker startup');
  const active = { active: true, domains: ['youtube.com'], expiresAt: 104, remaining: 60 };
  onMessage(active); await settle(); assert.equal(rules.length, 1);
  onDisconnect(); await settle(); assert.equal(rules.length, 0);
  interval(); await settle();
  onMessage(active); await settle(); assert.equal(rules.length, 1);
  now = 105_000; interval(); await settle(); assert.equal(rules.length, 0);
  now = 100_000;
  onMessage(active); onMessage(idle()); await settle();
  assert.equal(rules.length, 0, 'a queued active update cannot overtake an unlock');
});
