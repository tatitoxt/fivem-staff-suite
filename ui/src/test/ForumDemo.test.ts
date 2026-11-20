import { afterEach, expect, it, vi } from 'vitest';
import { isForumDemo, send, useMock } from '../nui';

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('routes the forum demo into the browser mock and keeps regular builds isolated', () => {
  vi.stubEnv('DEV', false);
  vi.stubEnv('MODE', 'production');
  expect(useMock()).toBe(false);
  vi.stubEnv('MODE', 'forum-demo');
  expect(isForumDemo()).toBe(true);
  expect(useMock()).toBe(true);
});

it('prevents the demo bundle from making requests to a FiveM resource', async () => {
  vi.stubEnv('MODE', 'forum-demo');
  window.GetParentResourceName = () => 'staff_suite';
  const fetcher = vi.fn();
  vi.stubGlobal('fetch', fetcher);
  expect(useMock()).toBe(false);
  expect(await send('audit_verify')).toBeNull();
  expect(fetcher).not.toHaveBeenCalled();
});
