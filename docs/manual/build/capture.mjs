import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright'); // CommonJS resolution honors NODE_PATH.
const dir = path.dirname(fileURLToPath(import.meta.url));
const base = new URL(process.argv[2] || 'http://localhost:3053');
const ids = JSON.parse(await fs.readFile(path.join(dir, 'out/demo_ids.json'), 'utf8'));
const screens = JSON.parse(await fs.readFile(path.join(dir, 'screens.json'), 'utf8'));
const out = path.join(dir, 'out/shots');
await fs.mkdir(out, { recursive: true });
function expand(value) {
  return value.replace(/\{(\w+)\}/g, (_, key) => {
    if (ids[key] == null) throw new Error(`demo_ids.json: missing ${key}`);
    return String(ids[key]);
  });
}
const browser = await chromium.launch({ headless: true });
try {
  const context = await browser.newContext({ viewport: { width: 1366, height: 900 }, deviceScaleFactor: 2, locale: 'ko-KR' });
  const page = await context.newPage();
  await page.goto(new URL('/login', base).href, { waitUntil: 'networkidle' });
  await page.locator('input[name="email"]').fill('admin@jieun.test');
  await page.locator('input[name="password"]').fill(process.env.MANUAL_ADMIN_PASSWORD || 'JieunDev!2026');
  await Promise.all([page.waitForURL(url => !url.pathname.startsWith('/login')), page.locator('input[type="submit"][value="로그인"]').click()]);
  const failures = [];
  // Playwright bounding boxes are viewport-relative; screenshot clips use document coordinates.
  async function documentBox(locator) {
    const box = await locator.boundingBox();
    if (!box) return null;
    const scroll = await page.evaluate(() => ({ x: window.scrollX, y: window.scrollY }));
    return { ...box, x: box.x + scroll.x, y: box.y + scroll.y };
  }
  for (const screen of screens) {
    try {
      const url = new URL(expand(screen.url), base);
      if (url.origin !== base.origin) throw new Error(`외부 캡처 URL 금지: ${url}`);
      await page.goto(url.href, { waitUntil: 'networkidle' });
      if (new URL(page.url()).pathname === '/login') throw new Error('관리자 로그인 세션을 확인하세요');
      await page.evaluate(async () => {
        await document.fonts.ready;
        await Promise.all([...document.images].map(img => img.decode().catch(() => {})));
        window.scrollTo(0, 0);
      });
      await page.addStyleTag({ content: '*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important} body>header{position:static!important}' });
      const dimensions = await page.evaluate(() => ({ width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight }));
      let clip = { x: 0, y: 0, ...dimensions };
      let scope = page;
      if (screen.clip === 'menu-row') {
        const links = page.locator('nav[aria-label="관리 메뉴"] a');
        const first = await documentBox(links.first());
        const last = await documentBox(links.filter({ hasText: new RegExp(`^${screen.menuEnd || 'KPI'}$`) }).first());
        if (!first || !last) throw new Error('관리 메뉴 줄을 찾지 못했습니다');
        clip = { x: first.x, y: first.y - 4, width: last.x + last.width - first.x, height: Math.max(first.height, last.y + last.height - first.y) + 8 };
      } else if (screen.clip === 'conversation-top' || screen.clip === 'conversation-forms') {
        const topPanel = screen.clip === 'conversation-top';
        const first = await documentBox(page.locator(topPanel ? "main section:has(h2:text-is('거래처 연결'))" : "main h2:text-is('받은 메시지 붙여넣기')").first());
        const last = await documentBox(page.locator(topPanel ? "ol[aria-label='대화 내역']" : `form[action='/wechat/${ids.contact_id}/send_message']`).first());
        if (!first || !last) throw new Error(`${screen.id}: 대화 분할 영역을 찾지 못했습니다`);
        clip = { x: first.x, y: first.y, width: Math.max(first.width, last.x + last.width - first.x), height: last.y + last.height - first.y };
      } else if (screen.clip) {
        const selector = screen.clip === 'main' ? 'body > main' : expand(screen.clip);
        let locator = page.locator(selector);
        if (screen.clipBadge) {
          const badgePrefix = screen.clipBadge.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          locator = locator.filter({ has: page.getByText(new RegExp(`^${badgePrefix}`)) });
        }
        if (screen.clipText) locator = locator.filter({ hasText: expand(screen.clipText) });
        scope = locator.first();
        const box = await documentBox(scope);
        if (!box) throw new Error(`${screen.id}: clip not found: ${selector}`);
        clip = { x: Math.max(0, box.x), y: Math.max(0, box.y), width: box.width, height: box.height };
        if (screen.clipRows) {
          const rows = scope.locator(screen.clipItems || 'tbody > tr');
          const count = Math.min(await rows.count(), screen.clipRows);
          if (count) {
            const last = await documentBox(rows.nth(count - 1));
            clip.height = Math.min(clip.height, last.y + last.height - clip.y + 4);
          }
        }
      }
      if (screen.clipMaxWidth) {
        // Keep the left columns and the payment action within a readable crop.
        clip.width = Math.min(clip.width, screen.clipMaxWidth);
        const payment = await documentBox(page.locator(`form[action='/admin_orders/${ids.pending_order_id}/confirm_payment'] button`).first());
        if (!payment || payment.x < clip.x || payment.x + payment.width > clip.x + clip.width) {
          throw new Error(`${screen.id}: 900px clip 안에 입금 확인 버튼이 없습니다`);
        }
      }
      const callouts = [];
      const warnings = [];
      for (const point of screen.callouts || []) {
        try {
          const locator = point.selector ? (screen.clipBadge ? scope : page).locator(expand(point.selector)) : scope.getByText(point.text, { exact: true });
          const target = locator.first();
          if (!await target.isVisible()) throw new Error('현재 화면에 없음');
          const box = await documentBox(target);
          if (!box) throw new Error('bounding box 없음');
          const x = Math.max(box.x, clip.x), y = Math.max(box.y, clip.y);
          const right = Math.min(box.x + box.width, clip.x + clip.width), bottom = Math.min(box.y + box.height, clip.y + clip.height);
          if (right <= x || bottom <= y) throw new Error('캡처 영역 밖');
          callouts.push({ ...point, box: { x: x - clip.x, y: y - clip.y, width: right - x, height: bottom - y } });
        } catch (error) {
          const warning = `${screen.id}  ${point.n}: ${point.label}: ${error.message}`;
          console.warn(warning); warnings.push(warning);
        }
      }
      await page.screenshot({ path: path.join(out, `${screen.id}.png`), clip, fullPage: true, animations: 'disabled', timeout: 60000 });
      await fs.writeFile(path.join(out, `${screen.id}.json`), JSON.stringify({ id: screen.id, chapter: screen.chapter, url: url.pathname, coordinateSystem: 'CSS pixels relative to clip; PNG pixels = CSS pixels * deviceScaleFactor', deviceScaleFactor: 2, width: clip.width, height: clip.height, clip, callouts, warnings }, null, 2) + '\n');
      console.log(`${screen.id}: ${callouts.length} points`);
    } catch (error) {
      const failure = `${screen.id}: ${error.message}`;
      failures.push(failure);
      console.warn(`캡처 실패: ${failure}`);
    }
  }
  if (failures.length) {
    console.error(`캡처 실패 목록 (${failures.length}):\n${failures.map(failure => `- ${failure}`).join('\n')}`);
    process.exitCode = 1;
  }
} finally { await browser.close(); }
