export const idle = () => ({ active: false, domains: [], expiresAt: 0, remaining: 0 });
export function normalizeState(value, now = Date.now() / 1000) {
  if (!value || value.active !== true || !Number.isFinite(value.expiresAt) ||
      value.expiresAt <= now || value.expiresAt > now + 5 ||
      !Number.isFinite(value.remaining) || value.remaining <= 0 ||
      !Array.isArray(value.domains) || value.domains.length > 100) return idle();
  const domains = [...new Set(value.domains.filter(domain => typeof domain === 'string' &&
    domain.length <= 253 && domain.split('.').length >= 2 && domain.split('.').every(label =>
      /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(label))))];
  return domains.length ? { active: true, domains, expiresAt: value.expiresAt, remaining: value.remaining } : idle();
}
export function rulesFor(state) {
  return state.active ? [{ id: 1, priority: 1,
    action: { type: 'redirect', redirect: { extensionPath: '/blocked.html' } },
    condition: { requestDomains: state.domains, resourceTypes: ['main_frame'], requestMethods: ['get'] }
  }] : [];
}
