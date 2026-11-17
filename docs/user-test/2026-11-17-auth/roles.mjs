import { chromium } from '/tmp/ujt/pw1115/node_modules/playwright/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const BASE = process.env.BASE || 'http://127.0.0.1:3073';
const OUT = process.env.OUT;
if (!OUT) throw new Error('OUT 환경변수가 필요합니다.');
await mkdir(OUT, { recursive: true });
const result = { base: BASE, startedAt: new Date().toISOString(), roles: {} };
const save = () => writeFile(join(OUT, 'result.json'), JSON.stringify(result, null, 2));
const browser = await chromium.launch({ headless: true });

try {
  for (const role of ['guest', 'member', 'operator', 'admin']) {
    const report = result.roles[role] = { success: false, steps: [] };
    let context;
    let page;
    let httpStatus = null;
    let activeStep;
    const path = () => new URL(page.url()).pathname;
    const step = async (name, action) => {
      activeStep = { name, success: false };
      report.steps.push(activeStep);
      try {
        await action();
        activeStep.success = true;
      } finally {
        activeStep.url = page.url();
        activeStep.httpStatus = httpStatus;
        activeStep.scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth).catch(() => null);
      }
    };
    const goto = async (url) => {
      httpStatus = null;
      const response = await page.goto(new URL(url, BASE).href, { waitUntil: 'load' });
      if (response) httpStatus = response.status();
      assert(httpStatus !== null && httpStatus < 400, `HTTP ${httpStatus}: ${page.url()}`);
    };
    // Turbo 폼도 최종 HTML 응답 상태를 기록한다.
    const submit = async (button, expectedPath) => {
      httpStatus = null;
      const responsePromise = page.waitForResponse(response => {
        const request = response.request();
        return new URL(response.url()).origin === new URL(BASE).origin &&
          ['document', 'fetch', 'xhr'].includes(request.resourceType()) &&
          response.headers()['content-type']?.includes('text/html') &&
          (response.status() >= 400 || new URL(response.url()).pathname === expectedPath);
      });
      const [response] = await Promise.all([responsePromise, button.click()]);
      httpStatus = response.status();
      assert(httpStatus < 400, `폼 제출 실패: HTTP ${httpStatus}`);
      await page.waitForURL(url => url.pathname === expectedPath);
    };
    const capture = async (name, menuOpen = false) => {
      for (const [width, height] of [[1440, 900], [375, 812]]) {
        await step(`${name}-${width}`, async () => {
          await page.setViewportSize({ width, height });
          if (menuOpen) {
            const menu = page.locator('header details.menu');
            if (!(await menu.getAttribute('open') !== null)) await menu.locator('summary').click();
          }
          await page.evaluate(async () => { await document.fonts.ready; });
          activeStep.width = width;
          activeStep.height = height;
          activeStep.screenshot = `${role}-${name}-${width}.png`;
          await page.screenshot({ path: join(OUT, activeStep.screenshot), fullPage: true });
        });
      }
      await page.setViewportSize({ width: 1440, height: 900 });
    };
    const login = async (email) => {
      assert(email && process.env.E2E_PASS, '계정 이메일 및 E2E_PASS 환경변수가 필요합니다.');
      await goto('/login');
      await page.getByLabel('이메일', { exact: true }).fill(email);
      await page.getByLabel('비밀번호', { exact: true }).fill(process.env.E2E_PASS);
      await submit(page.getByRole('button', { name: '로그인', exact: true }), '/inventory/scan');
    };
    try {
      context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
      page = await context.newPage();
      page.setDefaultTimeout(15000);
      if (role === 'guest') {
        for (const [name, url] of [['home', '/'], ['login', '/login'], ['join', '/join']]) {
          await step(name, () => goto(url));
          await capture(name);
        }
      } else if (role === 'member') {
        await step('join', async () => {
          assert(process.env.E2E_PASS, 'E2E_PASS 환경변수가 필요합니다.');
          await goto('/join');
          await page.getByLabel('이름', { exact: true }).fill('테스트');
          await page.getByLabel('이메일', { exact: true }).fill(`e2e-${Date.now()}@example.com`);
          await page.getByLabel('비밀번호', { exact: true }).fill(process.env.E2E_PASS);
          await page.getByLabel('비밀번호 확인', { exact: true }).fill(process.env.E2E_PASS);
          await submit(page.getByRole('button', { name: '회원가입', exact: true }), '/');
        });
        await step('product', async () => {
          const href = await page.locator('a[href]').evaluateAll(links =>
            links.map(link => link.getAttribute('href')).find(href => /^\/products\/\d+$/.test(href)));
          assert(href, '홈에 공개 상품 링크가 없습니다.');
          await goto(href);
          // 실제 뷰의 aria-label은 "색상 사이즈"이며 radio는 sr-only이다.
          const option = page.locator('input[name="variant_id"]:not(:disabled)').first();
          const label = await option.getAttribute('aria-label');
          assert(label, '재고 있는 옵션이 없습니다.');
          await page.getByLabel(label, { exact: true }).check({ force: true });
        });
        await step('cart', async () => {
          await submit(page.getByRole('button', { name: '장바구니', exact: true }), '/cart');
        });
        await step('checkout', async () => {
          await goto(await page.getByRole('link', { name: '비회원 주문하기', exact: true }).getAttribute('href'));
          for (const [label, value] of [['받는 분', '테스트'], ['휴대폰', '010-0000-0000'], ['우편번호', '06000'], ['주소', '서울 테스트로 1']]) {
            await page.getByLabel(label, { exact: true }).fill(value);
          }
          await page.getByLabel(/^개인정보 수집·이용 동의/).check();
          httpStatus = null;
          const responsePromise = page.waitForResponse(response =>
            new URL(response.url()).origin === new URL(BASE).origin &&
            (/^\/orders\/[^/]+$/.test(new URL(response.url()).pathname) || response.status() >= 400) &&
            response.headers()['content-type']?.includes('text/html'));
          const [response] = await Promise.all([responsePromise, page.getByRole('button', { name: '주문하기', exact: true }).click()]);
          httpStatus = response.status();
          assert(httpStatus < 400, `주문 실패: HTTP ${httpStatus}`);
          await page.waitForURL(url => /^\/orders\/[^/]+$/.test(url.pathname));
          await page.getByRole('heading', { name: '주문 내역', exact: true }).waitFor();
          await page.getByText('결제 대기', { exact: true }).first().waitFor();
        });
        await capture('order-complete');
        await step('my-orders', async () => {
          await goto('/my/orders');
          await page.getByRole('heading', { name: '내 주문', exact: true }).waitFor();
          assert(await page.locator('tbody tr').count(), '회원 주문이 없습니다.');
        });
        await capture('my-orders');
        await step('inventory-denied', async () => {
          await goto('/inventory/scan');
          assert.equal(path(), '/');
          await page.getByText('접근 권한이 없습니다.', { exact: true }).waitFor();
        });
      } else if (role === 'operator') {
        await step('login', () => login(process.env.E2E_OPERATOR));
        await step('home', () => goto('/'));
        await capture('menu', true);
        await step('kpi-denied', async () => {
          await goto('/kpi');
          assert.equal(path(), '/inventory/scan');
          await page.getByText('이 화면은 관리자 전용입니다', { exact: true }).waitFor();
        });
      } else {
        await step('login', () => login(process.env.E2E_ADMIN));
        await step('users', () => goto('/admin/users'));
        await capture('users');
        await step('home', () => goto('/'));
        await capture('menu', true);
      }
      report.success = true;
    } catch (error) {
      report.error = { step: activeStep?.name, message: error.message, stack: error.stack };
      if (activeStep) activeStep.error = error.message;
    } finally {
      await context?.close();
      await save();
    }
  }
} finally {
  result.finishedAt = new Date().toISOString();
  await save();
  await browser.close();
}
