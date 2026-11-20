import { chromium } from '/tmp/ujt/pw1115/node_modules/playwright/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';

// 작성만 수행한 스크립트. 실행 시에만 브라우저와 출력 폴더를 생성한다.
const BASE = process.env.BASE || 'http://127.0.0.1:3073';
const OUT = resolve(process.env.OUT || 'tmp/e2e/responsive-output');
const devices = [
  { name: 'web', width: 1440, height: 900 },
  { name: 'pad-landscape', width: 1024, height: 768, isMobile: false, hasTouch: true },
  { name: 'pad-portrait', width: 820, height: 1180, hasTouch: true },
  { name: 'mobile', width: 430, height: 932, isMobile: true, hasTouch: true, deviceScaleFactor: 2 },
  { name: 'phone', width: 360, height: 780, isMobile: true, hasTouch: true, deviceScaleFactor: 2 },
];
const guestPages = [
  ['home', '/'], ['products', '/products'], ['product-detail', null],
  ['cart', '/cart'], ['checkout', '/checkouts/new'], ['orders-lookup', '/orders/lookup'],
  ['login', '/login'], ['join', '/join'], ['privacy', '/policies/privacy'],
];
const adminPages = [
  ['inventory-scan', '/inventory/scan'], ['admin-orders', '/admin_orders'],
  ['dashboard', '/dashboard'], ['suppliers', '/suppliers'],
  ['purchase-orders', '/purchase_orders'], ['admin-users', '/admin/users'],
  ['products-new', '/products/new'], ['my', '/my'], ['my-orders', '/my/orders'],
];
const report = { base: BASE, startedAt: new Date().toISOString(), devices, results: [], errors: [] };
const errorText = error => error instanceof Error ? error.message : String(error);
const url = path => new URL(path, BASE).href;

async function goto(page, path) {
  const response = await page.goto(url(path), { waitUntil: 'load' });
  if (response && response.status() >= 400) throw new Error(`HTTP ${response.status()}: ${page.url()}`);
  return response?.status() ?? null;
}

async function measure(page, touch) {
  await page.evaluate(async () => { await document.fonts.ready; });
  return page.evaluate(({ touch }) => {
    const all = [...document.querySelectorAll('body *')];
    const visible = element => {
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 && style.visibility === 'visible' &&
        style.display !== 'none' && !element.closest('[inert]') &&
        ![element, ...ancestors(element)].some(node => Number(getComputedStyle(node).opacity) === 0);
    };
    function ancestors(element) {
      const nodes = [];
      for (let node = element.parentElement; node; node = node.parentElement) nodes.push(node);
      return nodes;
    }
    const text = element => (element.innerText || element.getAttribute('aria-label') ||
      element.getAttribute('placeholder') || element.value || '').replace(/\s+/g, ' ').trim().slice(0, 30);
    const describe = element => {
      const rect = element.getBoundingClientRect();
      return { tag: element.tagName.toLowerCase(), class: (element.getAttribute('class') || '').slice(0, 60),
        text: text(element), width: +rect.width.toFixed(2), height: +rect.height.toFixed(2) };
    };
    const elements = all.filter(visible);
    const docScrollWidth = Math.max(document.documentElement.scrollWidth, document.body?.scrollWidth || 0);
    const overflowing = elements.filter(element => element.getBoundingClientRect().right > innerWidth + 1)
      .sort((a, b) => b.getBoundingClientRect().right - a.getBoundingClientRect().right);
    const smallTouch = touch ? elements.filter(element =>
      element.matches('a,button,input,select,summary,label[for]') &&
      (element.getBoundingClientRect().width < 40 || element.getBoundingClientRect().height < 40)) : [];
    // 직접 텍스트 노드를 가진 요소만 세어 조상 요소의 중복 집계를 피한다.
    const smallText = elements.filter(element =>
      !element.matches('script,style,noscript') &&
      [...element.childNodes].some(node => node.nodeType === Node.TEXT_NODE && node.textContent.trim()) &&
      parseFloat(getComputedStyle(element).fontSize) < 12);
    const horizontal = elements.filter(element => /^(auto|scroll)$/.test(getComputedStyle(element).overflowX) &&
      element.scrollWidth > element.clientWidth);
    const positioned = elements.filter(element => /^(fixed|sticky)$/.test(getComputedStyle(element).position))
      .map(element => ({ ...describe(element), position: getComputedStyle(element).position }));
    const totalHeight = positioned.reduce((sum, element) => sum + element.height, 0);
    const tables = elements.filter(element => element.matches('table')).map(element => {
      const container = element.parentElement;
      const width = element.getBoundingClientRect().width;
      return { ...describe(element), containerWidth: container.clientWidth,
        widerThanContainer: width > container.clientWidth };
    });
    return {
      innerWidth, innerHeight, docScrollWidth, hasHorizontalOverflow: docScrollWidth > innerWidth,
      horizontalOverflowPx: Math.max(0, docScrollWidth - innerWidth),
      overflowingElements: { count: overflowing.length, examples: overflowing.slice(0, 5).map(describe) },
      smallTouchTargets: { applicable: touch, count: smallTouch.length, examples: smallTouch.slice(0, 5).map(describe) },
      smallText: { count: smallText.length, examples: smallText.slice(0, 3).map(element =>
        ({ ...describe(element), fontSize: parseFloat(getComputedStyle(element).fontSize) })) },
      horizontalScrollContainers: { count: horizontal.length, elements: horizontal.map(describe) },
      fixedSticky: { elements: positioned, totalHeight, threshold: innerHeight * 0.3,
        exceeds30Percent: totalHeight > innerHeight * 0.3 },
      tables: { count: tables.length, hasOversizedTable: tables.some(table => table.widerThanContainer), elements: tables },
    };
  }, { touch });
}

async function capture(page, device, role, name, requestedPath, action, prerequisiteError) {
  const row = { device: device.name, role, page: name, requestedPath, errors: [] };
  report.results.push(row);
  if (prerequisiteError) row.errors.push(prerequisiteError);
  try { row.httpStatus = await action(); } catch (error) { row.errors.push(errorText(error)); }
  row.finalUrl = page.url();
  try { row.metrics = await measure(page, Boolean(device.hasTouch)); }
  catch (error) { row.errors.push(`측정: ${errorText(error)}`); }
  const screenshot = `${device.name}/${name}.png`;
  try {
    await page.screenshot({ path: join(OUT, screenshot), fullPage: true });
    row.screenshot = screenshot;
  } catch (error) { row.errors.push(`스크린샷: ${errorText(error)}`); }
  row.success = row.errors.length === 0;
}

async function login(page) {
  if (!process.env.E2E_ADMIN || !process.env.E2E_PASS) throw new Error('E2E_ADMIN 및 E2E_PASS가 필요합니다.');
  await goto(page, '/login');
  await page.locator('input[name="email"]').fill(process.env.E2E_ADMIN);
  await page.locator('input[name="password"]').fill(process.env.E2E_PASS);
  await Promise.all([
    page.waitForURL(destination => destination.pathname !== '/login', { waitUntil: 'load' }),
    page.getByRole('button', { name: '로그인', exact: true }).click(),
  ]);
}

async function addOneToCart(page, productPath) {
  if (!productPath) throw new Error('홈에서 첫 공개 상품 링크를 찾지 못했습니다.');
  await goto(page, productPath);
  const form = page.locator('form#buy');
  const variant = form.locator('input[name="variant_id"]:not(:disabled)').first();
  if (!await variant.count()) throw new Error('첫 공개 상품에 구매 가능한 옵션이 없습니다.');
  // sr-only 라디오는 화면상의 레이블을 통해 선택한다.
  await variant.locator('..').click();
  await form.locator('input[name="quantity"]').fill('1');
  await Promise.all([
    page.waitForURL(destination => destination.pathname === '/cart', { waitUntil: 'load' }),
    form.getByRole('button', { name: '장바구니', exact: true }).click(),
  ]);
  if (!await page.locator('input[name="quantity"]').count()) throw new Error('장바구니 상품을 확인하지 못했습니다.');
}

const cell = value => String(value ?? '—').replace(/\|/g, '\\|').replace(/[\r\n]+/g, ' ');
async function save() {
  await writeFile(join(OUT, 'report.json'), JSON.stringify(report, null, 2) + '\n');
  const lines = ['| 기기 | 페이지 | 가로넘침px | 작은터치 | 작은글씨 | 넘친요소예시 |',
    '| --- | --- | ---: | ---: | ---: | --- |'];
  for (const row of report.results) {
    const m = row.metrics;
    const examples = m?.overflowingElements.examples.map(element =>
      `${element.tag}.${element.class} ${element.text}`).join('; ') || '—';
    lines.push(`| ${[row.device, `${row.role}/${row.page}`, m?.horizontalOverflowPx,
      m?.smallTouchTargets.applicable ? m.smallTouchTargets.count : '해당 없음', m?.smallText.count,
      `${examples}${row.errors.length ? ` (오류: ${row.errors.join('; ')})` : ''}`].map(cell).join(' | ')} |`);
  }
  await writeFile(join(OUT, 'summary.md'), lines.join('\n') + '\n');
}

await mkdir(OUT, { recursive: true });
let browser;
try {
  browser = await chromium.launch({ headless: true });
  for (const device of devices) {
    await mkdir(join(OUT, device.name), { recursive: true });
    const { name, width, height, ...options } = device;
    for (const role of ['guest', 'admin']) {
      let context;
      try {
        context = await browser.newContext({ viewport: { width, height }, ...options });
        const page = await context.newPage();
        page.setDefaultTimeout(15000);
        page.setDefaultNavigationTimeout(30000);
        let productPath;
        let cartError;
        let loginError;
        if (role === 'admin') {
          try { await login(page); } catch (error) { loginError = `관리자 로그인 실패: ${errorText(error)}`; }
        }
        for (const [pageName, path] of role === 'guest' ? guestPages : adminPages) {
          await capture(page, device, role, pageName, path, async () => {
            if (role === 'admin' && loginError) throw new Error(loginError);
            if (pageName === 'product-detail') {
              if (!productPath) throw new Error('홈에서 첫 공개 상품 링크를 찾지 못했습니다.');
              return goto(page, productPath);
            }
            if (pageName === 'cart') {
              try { await addOneToCart(page, productPath); }
              catch (error) { cartError = `장바구니 준비 실패: ${errorText(error)}`; }
              const status = await goto(page, '/cart');
              if (cartError) throw new Error(cartError);
              return status;
            }
            if (pageName === 'checkout') {
              await goto(page, '/cart');
              const orderLink = page.getByRole('link', { name: /주문하기/ }).first();
              const destination = await orderLink.count() ? await orderLink.getAttribute('href') : path;
              const status = await goto(page, destination || path);
              if (cartError) throw new Error(cartError);
              if (new URL(page.url()).pathname === '/cart') throw new Error('주문서 접근이 장바구니로 리다이렉트되었습니다.');
              return status;
            }
            if (pageName === 'privacy') {
              await goto(page, '/');
              const footerLink = page.locator('footer').getByRole('link', { name: '개인정보처리방침', exact: true }).first();
              return goto(page, await footerLink.count() ? await footerLink.getAttribute('href') : path);
            }
            const status = await goto(page, path);
            if (pageName === 'home') productPath = await page.locator("a[href^='/products/']").first().getAttribute('href');
            if (role === 'admin' && new URL(page.url()).pathname === '/login') throw new Error('관리자 페이지가 로그인으로 리다이렉트되었습니다.');
            return status;
          });
          await save();
        }
      } catch (error) {
        report.errors.push({ device: name, role, error: errorText(error) });
        // 컨텍스트 생성 실패도 기기×페이지 표에서 빠지지 않게 기록한다.
        for (const [pageName, path] of role === 'guest' ? guestPages : adminPages) {
          if (!report.results.some(row => row.device === name && row.role === role && row.page === pageName)) {
            report.results.push({ device: name, role, page: pageName, requestedPath: path,
              success: false, errors: [errorText(error)] });
          }
        }
      } finally {
        await context?.close().catch(error => report.errors.push({ device: name, role, error: errorText(error) }));
        await save();
      }
    }
  }
} catch (error) {
  report.errors.push({ error: errorText(error) });
  process.exitCode = 1;
} finally {
  await browser?.close().catch(error => report.errors.push({ error: errorText(error) }));
  report.finishedAt = new Date().toISOString();
  await save();
}
