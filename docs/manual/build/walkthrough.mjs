/**
 * Production operator walkthrough (writes only explicitly identified (점검) fixtures).
 * Run outside the sandbox:
 * NODE_PATH=/Volumes/E_SSD/02_GitHub.nosync/0060_seoullive/node_modules \
 * BASE_URL=https://example.test EMAIL=... TEMP_PASSWORD=... NEW_PASSWORD=... \
 * node docs/manual/build/walkthrough.mjs
 * Also accepts --BASE_URL=value (or --BASE_URL value), likewise for all env options.
 * Never approves automatic WeChat sending or confirms customer payments.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright'); // Same NODE_PATH-aware loader as capture.mjs.
const dir = path.dirname(fileURLToPath(import.meta.url));
const options = { ...process.env };
for (let i = 2; i < process.argv.length; i++) {
  const match = process.argv[i].match(/^--?(BASE_URL|EMAIL|TEMP_PASSWORD|NEW_PASSWORD|OUT_DIR)(?:=(.*))?$/);
  if (!match) throw new Error(`알 수 없는 인자: ${process.argv[i]}`);
  options[match[1]] = match[2] ?? process.argv[++i];
}
if (!options.BASE_URL) throw new Error('BASE_URL 필수');
const base = new URL(options.BASE_URL);
if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password) throw new Error('BASE_URL은 인증정보 없는 HTTP(S) URL이어야 합니다');
const out = path.resolve(options.OUT_DIR || path.join(dir, 'out/walkthrough'));
const FACTORY = '(점검) 매뉴얼 시험 공장';
const CONTACT = '(점검) 陈经理';
const MEMO = `(점검) 매뉴얼 점검 발주 ${new Date().toISOString()}`;
const FEEDBACK = '(점검) 매뉴얼 점검용 의견입니다';
const CLAIM = '(점검) 시험 클레임';
const results = [], state = {};
let current, page, browser, context;
class Skip extends Error {}
const skip = note => { throw new Skip(note); };
const check = (value, note) => { if (!value) throw new Error(note); };
// Tokens and passwords must never appear in logs/result notes.
function redact(value) {
  let text = String(value).replace(/\/po\/confirm\/[^\s"'<>?]+/g, '/po/confirm/[REDACTED]');
  for (const secret of [options.TEMP_PASSWORD, options.NEW_PASSWORD].filter(Boolean)) text = text.split(secret).join('[REDACTED]');
  return text;
}
function note(value) { current.note.push(redact(value)); }
function observe(p) {
  p.on('console', msg => { if (msg.type() === 'error' && current) note(`console: ${msg.text()}`); });
  p.on('pageerror', err => { if (current) note(`pageerror: ${err.message}`); });
  p.on('response', response => { if (response.status() >= 400 && current) note(`HTTP ${response.status()} ${response.url()}`); });
  p.on('dialog', async dialog => {
    // Only the exact, scoped mutation helper below may accept a confirmation.
    if (state.confirmDialog) await dialog.accept(); else await dialog.dismiss();
  });
}
async function go(url, target = page) {
  const destination = new URL(url, base);
  check(destination.origin === base.origin, '외부 URL 이동 금지');
  const response = await target.goto(destination.href, { waitUntil: 'networkidle' });
  check(!response || response.status() < 400, `화면 열기 실패: HTTP ${response?.status()}`);
  if (destination.pathname !== '/login') check(new URL(target.url()).pathname !== '/login', '로그인 세션 없음');
}
async function visible(locator, message = '화면 요소 없음') {
  await locator.first().waitFor({ state: 'visible' });
  check(await locator.first().isVisible(), message);
}
async function textIs(text, target = page) { await visible(target.getByText(text, { exact: true })); }
// Each write is permitted only for the precise form action about to be clicked.
// Background JS cannot submit payments, delete data, change the channel, or send externally.
let permittedAction = null;
async function write(form, button, target = page) {
  check(await form.count() === 1, '저장 폼이 유일하지 않음');
  const action = new URL(await form.getAttribute('action'), target.url());
  check(action.origin === base.origin && !/confirm_payment|\/channel$|resend_wechat|tokens/.test(action.pathname), '금지된 쓰기 동작');
  const oldForm = await form.elementHandle();
  permittedAction = action.pathname;
  state.confirmDialog = true;
  try {
    await Promise.all([
      target.waitForResponse(r => new URL(r.url()).pathname === action.pathname && r.request().method() !== 'GET').then(r => check(r.status() < 400, `저장 실패 HTTP ${r.status()}`)),
      form.getByRole('button', { name: button, exact: true }).click(),
    ]);
    if (action.pathname !== '/operator_feedbacks') {
      await target.waitForFunction(element => !element.isConnected, oldForm);
    }
    await target.waitForLoadState('networkidle');
    // Wait for Turbo's replacement document, including redirects to the same path.
    await target.locator('html[aria-busy="true"]').waitFor({ state: 'detached' });
    await target.waitForLoadState('networkidle');
  } finally { permittedAction = null; state.confirmDialog = false; }
}
const formAt = action => page.locator(`form[action="${action}"]`);
async function auth() { if (!state.auth) skip('로그인 단계 실패'); }
async function safeFactory() {
  check(state.supplier, '점검 거래처 없음');
  if (/^\/wechat\/\d+$/.test(new URL(page.url()).pathname)) {
    await visible(page.getByRole('heading', { name: FACTORY, exact: true }));
    check(await page.locator('select[name="supplier_id"]').inputValue() === state.supplier, '대화 거래처 ID 불일치');
    check((await page.locator('input[name="wechat_display_name"]').inputValue()) === CONTACT, '점검 대화명 불일치');
  } else {
    check(await page.locator(`a[href="/suppliers/${state.supplier}"]`).filter({ hasText: FACTORY }).count() > 0, '점검 거래처 연결 확인 실패');
  }
}
async function safePO() {
  await safeFactory();
  await textIs(MEMO);
  const rows = page.locator('table tbody tr');
  check(await rows.count() === 1 && (await rows.first().locator('td').nth(2).innerText()).trim() === '1', '점검 발주는 품목 1개·수량 1만 허용');
}
async function poStatus() {
  const panel = page.locator('div.bg-white').filter({ has: page.getByRole('heading', { name: '발주 정보', exact: true }) });
  const status = (await panel.locator('span').first().innerText()).trim();
  return ({ draft: '작성 중', submitted: '제출됨', confirmed: '확정됨', received: '입고됨', cancelled: '취소됨' })[status] ?? status;
}
async function mode() {
  await go('/wechat');
  await visible(page.getByRole('region', { name: '채널 방식', exact: true }));
  state.mode = await page.locator('select[name="wechat_channel_mode"]').inputValue();
  note(`채널 방식: ${state.mode} (변경 없음)`);
  return state.mode;
}
async function manualMode() {
  if (!['manual', 'mac_app'].includes(await mode())) skip('공식계정 채널: 외부 발송 방지를 위해 건너뜀');
}
async function step(id, chapter, title, run) {
  current = { id, chapter, title, status: 'pass', note: [], screenshot: null };
  try { await run(); }
  catch (error) { current.status = error instanceof Skip ? 'skip' : 'fail'; note(error.message); }
  finally {
    if (page && !page.isClosed()) {
      try {
        const filename = `${String(id).padStart(2, '0')}.png`;
        await page.screenshot({ path: path.join(out, filename), fullPage: true, animations: 'disabled' });
        current.screenshot = filename;
      } catch (error) { note(`스크린샷 실패: ${error.message}`); if (current.status === 'pass') current.status = 'fail'; }
    }
    current.note = [...new Set(current.note)].join('\n');
    results.push(current);
    await fs.writeFile(path.join(out, 'result.json'), JSON.stringify(results, null, 2) + '\n');
    console.log(`${id}. ${current.status}: ${title}`);
    current = null;
  }
}
await fs.mkdir(out, { recursive: true });
try {
  browser = await chromium.launch({ headless: true });
  context = await browser.newContext({ viewport: { width: 1366, height: 900 }, locale: 'ko-KR', serviceWorkers: 'block' });
  context.setDefaultTimeout(15000);
  context.on('page', observe);
  await context.route('**/*', async route => {
    const request = route.request(), url = new URL(request.url());
    if (!['GET', 'HEAD', 'OPTIONS'].includes(request.method()) &&
        (url.origin !== base.origin || url.pathname !== permittedAction)) {
      if (current) note(`안전 차단: ${request.method()} ${url.pathname}`);
      await route.abort('blockedbyclient');
    } else await route.continue();
  });
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: base.origin });
  page = await context.newPage();
  await step(1, 1, '로그인·첫 비밀번호 변경', async () => {
    check(options.EMAIL && options.TEMP_PASSWORD && options.NEW_PASSWORD, 'EMAIL, TEMP_PASSWORD, NEW_PASSWORD 필수');
    async function login(password) {
      await go('/login');
      const form = formAt('/login');
      await form.locator('[name="email"]').fill(options.EMAIL);
      await form.locator('[name="password"]').fill(password);
      await write(form, '로그인');
    }
    try { await login(options.TEMP_PASSWORD); }
    catch (error) { note(`임시 비밀번호 로그인: ${error.message}; NEW_PASSWORD 재시도 예정`); }
    if (new URL(page.url()).pathname === '/account/password') {
      note('첫 로그인 비밀번호 변경 화면 확인');
      const form = formAt('/account/password');
      await form.locator('[name="current_password"]').fill(options.TEMP_PASSWORD);
      await form.locator('[name="password"]').fill(options.NEW_PASSWORD);
      await form.locator('[name="password_confirmation"]').fill(options.NEW_PASSWORD);
      await write(form, '비밀번호 변경');
      await textIs('비밀번호를 바꿨습니다');
      note('비밀번호 변경 성공 안내 확인');
    } else {
      note('강제 변경 화면 없음: NEW_PASSWORD로 로그인 재시도');
      await context.clearCookies();
      await login(options.NEW_PASSWORD);
      check(!['/login', '/account/password'].includes(new URL(page.url()).pathname), 'NEW_PASSWORD 로그인 실패 또는 강제 변경 미완료');
    }
    await go('/');
    await visible(page.locator('[aria-label="데스크톱 관리자 메뉴"]'));
    state.auth = true;
  });
  await step(2, 0, '의견 보내기·의견함 확인', async () => {
    await auth();
    await go('/feedbacks_admin?kind=stuck&manual_chapter=0');
    if (await page.getByRole('link', { name: FEEDBACK, exact: true }).count()) { note('기존 점검 의견 재사용'); return; }
    const toggle = page.locator('#operator-feedback-toggle');
    const kind = page.locator('#operator-feedback-kind');
    await toggle.click();
    try {
      await kind.waitFor({ state: 'visible', timeout: 3000 });
    } catch (error) {
      if (error.name !== 'TimeoutError') throw error;
      // The first click can precede Stimulus connecting after navigation.
      if (!await kind.isVisible()) await toggle.click();
      await visible(kind);
    }
    await kind.selectOption({ label: '막힘·헷갈림' });
    await page.locator('#operator-feedback-body').fill(FEEDBACK);
    await page.locator('#operator-feedback-chapter').selectOption('0');
    await write(formAt('/operator_feedbacks'), '보내기');
    await visible(page.locator('[data-operator-feedback-target="message"]').filter({ hasText: /보냈|감사|접수/ }));
    await go('/feedbacks_admin?kind=stuck&manual_chapter=0');
    await visible(page.getByRole('link', { name: FEEDBACK, exact: true }));
  });
  await step(3, 1, '운영자 메뉴', async () => {
    await auth(); await go('/');
    const nav = page.locator('[aria-label="데스크톱 관리자 메뉴"]');
    for (const label of ['위챗', '거래처', '발주', '주문 관리', '판매현황', '재고관리', /^의견함/]) await visible(nav.getByRole('link', { name: label, exact: true }));
  });
  await step(4, 2, '점검 거래처 등록', async () => {
    await auth(); await go('/suppliers');
    await visible(page.getByRole('heading', { name: '거래처 관리', exact: true }));
    const existing = page.getByRole('link', { name: FACTORY, exact: true });
    if (await existing.count()) { note('기존 점검 거래처 재사용'); }
    else {
      await go('/suppliers/new');
      const form = formAt('/suppliers');
      for (const [field, value] of Object.entries({ name: FACTORY, contact_person: '(점검) 담당자', phone: '000-0000-0000', email: 'manual-check@jieum.test', notes: '(점검) 매뉴얼 점검용' })) await form.locator(`[name="supplier[${field}]"]`).fill(value);
      await write(form, '등록');
      await textIs('거래처가 등록되었습니다.');
      check(new URL(page.url()).pathname === '/suppliers', '거래처 목록 경로 확인 실패');
    }
    await visible(existing);
    const supplierPath = await existing.first().getAttribute('href');
    check(/^\/suppliers\/\d+$/.test(supplierPath || ''), '거래처 링크 경로 확인 실패');
    state.supplier = supplierPath.split('/').pop();
    await go(supplierPath);
    await visible(page.getByRole('heading', { name: FACTORY, exact: true }));
    // Refuse submitting even a reused fixture if its email could reach a real supplier.
    await textIs('manual-check@jieum.test'); await textIs('000-0000-0000');
    check(/^\/suppliers\/\d+$/.test(new URL(page.url()).pathname), '거래처 상세 경로 확인 실패');
  });
  await step(5, 3, '채널 확인·점검 대화 상대', async () => {
    await auth(); if (!state.supplier) skip('점검 거래처 없음');
    await manualMode();
    let row = page.locator('tbody tr').filter({ hasText: CONTACT }).filter({ has: page.getByRole('link', { name: FACTORY, exact: true }) });
    if (await row.count()) { await go(await row.first().getByRole('link', { name: FACTORY, exact: true }).getAttribute('href')); note('기존 점검 대화 재사용'); }
    else {
      const form = formAt('/wechat');
      await form.locator('[name="supplier_id"]').selectOption({ label: FACTORY });
      await form.locator('[name="wechat_display_name"]').fill(CONTACT);
      await write(form, '대화 상대 추가');
    }
    await safeFactory();
    check(/^\/wechat\/\d+$/.test(new URL(page.url()).pathname), '대화 상세 경로 확인 실패');
    state.contact = new URL(page.url()).pathname;
    await go('/wechat');
    row = page.locator('tbody tr').filter({ hasText: CONTACT }).filter({ hasText: FACTORY });
    await visible(row);
  });
  await step(6, 4, '점검 발주 생성·제출', async () => {
    await auth(); if (!state.contact) skip('점검 대화 상대 없음');
    await manualMode();
    await go('/purchase_orders/new');
    const form = formAt('/purchase_orders');
    await form.locator('[name="purchase_order[supplier_id]"]').selectOption({ label: FACTORY });
    const due = new Date(); due.setDate(due.getDate() + 21);
    await form.locator('[name="purchase_order[expected_delivery_date]"]').fill(new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Seoul', year: 'numeric', month: '2-digit', day: '2-digit' }).format(due));
    await form.locator('[name="purchase_order[notes]"]').fill(MEMO);
    const variant = form.locator('select[name$="[variant_id]"]').first();
    const value = await variant.locator('option').evaluateAll(nodes => nodes.find(n => n.value)?.value);
    check(value, '상품·옵션 목록 비어 있음'); await variant.selectOption(value);
    await form.locator('input[name$="[quantity]"]').first().fill('1');
    await form.locator('input[name$="[unit_price]"]').first().fill('1');
    await write(form, '발주서 생성');
    check(/^\/purchase_orders\/\d+$/.test(new URL(page.url()).pathname), '발주 저장 실패');
    state.po = new URL(page.url()).pathname;
    await safePO();
    if (await poStatus() === '작성 중') await write(formAt(`${state.po}/submit`), '제출');
    const status = await poStatus();
    check(status === '제출됨', '제출됨 상태 아님');
    note(`상태: ${status}`);
    state.submitted = true;
  });
  await step(7, 5, '발주 통보문 복사·보냈음 표시', async () => {
    await auth(); if (!state.submitted) skip('발주 제출 단계 실패');
    // 제출 직후 화면에서 통보문이 보이는지 확인한다. 새로고침하지 않는다.
    check(new URL(page.url()).pathname === state.po, '제출 직후 발주 화면 아님');
    await safePO();
    check(await poStatus() === '제출됨', '제출됨 상태 아님');
    const section = page.locator('section').filter({ has: page.getByRole('heading', { name: '위챗 발송 내역', exact: true }) });
    const item = section.locator('li').filter({ hasText: FACTORY }).first();
    await visible(item.locator('[data-clipboard-target="source"]'));
    await item.getByRole('button', { name: '복사', exact: true }).click();
    await visible(item.locator('[data-clipboard-target="status"]').filter({ hasText: /복사했/ }));
    const source = await item.locator('[data-clipboard-target="source"]').innerText();
    state.confirm = source.match(/https?:\/\/[^\s<>]+\/po\/confirm\/[^\s<>]+/)?.[0];
    if (await item.getByRole('button', { name: '보내기 승인', exact: true }).count()) skip('자동 발송 승인 대기 상태: 외부 발송 방지를 위해 승인하지 않음');
    if (await item.getByRole('button', { name: '보냈음 표시', exact: true }).count()) {
      await write(item.locator('form').filter({ has: page.getByRole('button', { name: '보냈음 표시', exact: true }) }), '보냈음 표시');
    } else note('기존 처리 기록 재사용; 보내기 승인은 누르지 않음');
    await visible(section.locator('li').filter({ hasText: FACTORY }).first().getByText(/^처리:/));
    note('실제 위챗 외부 발송 없음');
  });
  await step(8, 6, '점검 답장 기록·보낼 통보문', async () => {
    await auth(); if (!state.contact) skip('점검 대화 없음');
    await manualMode(); await go(state.contact); await safeFactory();
    const history = page.locator('ol[aria-label="대화 내역"]');
    if (!await history.getByText('(점검) 收到', { exact: true }).count()) {
      await page.locator('#received_message_content').fill('(점검) 收到');
      await write(formAt(`${state.contact}/receive_message`), '답장 기록');
    } else note('기존 받은 메시지 재사용');
    await visible(history.getByText('(점검) 收到', { exact: true }));
    if (!await history.getByText('(점검) 谢谢', { exact: true }).count()) {
      const form = formAt(`${state.contact}/send_message`);
      await form.locator('textarea').fill('(점검) 谢谢');
      await write(form, '보낼 통보문 만들기');
    } else note('기존 보낼 메시지 재사용');
    const item = history.locator('li').filter({ has: page.getByText('(점검) 谢谢', { exact: true }) }).first();
    if (await item.getByRole('button', { name: '보냈음 표시', exact: true }).count()) await write(item.locator('form'), '보냈음 표시');
    await visible(item.getByText(/^처리:/));
    note('실제 위챗 외부 발송 없음');
  });
  await step(9, 7, '공장 확정 링크·수량 1 입고', async () => {
    await auth(); if (!state.submitted) skip('발주 제출 단계 실패');
    await go(state.po); await safePO();
    let status = await poStatus();
    if (status === '입고됨') { note('이미 입고됨: 재입고하지 않음'); return; }
    if (status === '제출됨') {
      const body = await page.locator('body').innerText();
      const link = state.confirm || body.match(/https?:\/\/[^\s<>]+\/po\/confirm\/[^\s<>]+/)?.[0];
      check(link, '공장 확정 링크 없음');
      check(link.startsWith('https://'), '공장 확정 링크가 https://로 시작하지 않음');
      const url = new URL(link); check(url.origin === base.origin && /^\/po\/confirm\/[^/]+$/.test(url.pathname), '확정 링크 출처/경로 불일치');
      const factoryPage = await context.newPage();
      try {
        await go(url.href, factoryPage);
        await textIs(MEMO, factoryPage);
        const form = factoryPage.locator(`form[action="${url.pathname}"]`);
        await write(form, '발주서 확정하기', factoryPage);
        await visible(factoryPage.getByText('발주서가 확정되었습니다. 감사합니다!', { exact: true }));
        await factoryPage.screenshot({ path: path.join(out, '09-factory-confirm.png'), fullPage: true });
      } finally { await factoryPage.close(); }
      await go(state.po); await safePO(); status = await poStatus();
    }
    check(status === '확정됨', '확정됨 상태 확인 실패'); note('확정됨 확인');
    await write(formAt(`${state.po}/receive`), '입고 처리');
    check(await poStatus() === '입고됨', '입고됨 상태 확인 실패');
    note('품목 1개·수량 1 전체 입고 확인');
  });
  await step(10, 8, '손님 주문·입금 확인 버튼 존재만 확인', async () => {
    await auth(); await go('/admin_orders');
    await visible(page.getByRole('heading', { name: '주문 관리', exact: true }));
    const orders = page.locator('table').filter({ has: page.getByRole('columnheader', { name: '주문번호', exact: true }) });
    await visible(orders);
    const pending = orders.locator('tbody tr').filter({ has: page.getByRole('cell', { name: 'pending', exact: true }) });
    if (await pending.count() === 0) skip('입금 대기 주문 없음');
    for (const row of await pending.all()) {
      await visible(row.locator('form[action$="/confirm_payment"]').getByRole('button', { name: /입금 확인/ }));
    }
    note('입금 확인 버튼 존재 확인. 클릭하지 않음');
  });
  await step(11, 9, '판매현황·재고관리 열기', async () => {
    await auth();
    // Independently check both pages even if the first fails.
    const failures = [];
    for (const [url, filename] of [['/sales', '11-sales.png'], ['/inventory/scan', '11-inventory.png']]) {
      try { await go(url); await visible(page.locator('h1')); await page.screenshot({ path: path.join(out, filename), fullPage: true }); note(`${url} 열림`); }
      catch (error) { failures.push(error.message); }
    }
    check(!failures.length, failures.join('; '));
  });
  await step(12, 10, '점검 거래처 클레임 저장', async () => {
    await auth(); if (!state.supplier) skip('점검 거래처 없음');
    await go('/supplier_claims');
    const existing = page.locator('div.p-4').filter({ hasText: CLAIM }).filter({ hasText: FACTORY });
    if (await existing.count()) { await go(await existing.first().getByRole('link').getAttribute('href')); note('기존 점검 클레임 재사용'); }
    else {
      await go('/supplier_claims/new');
      const form = formAt('/supplier_claims');
      const supplier = form.locator('select[name="supplier_claim[supplier_id]"]');
      await supplier.selectOption({ label: FACTORY });
      check(await supplier.inputValue() === state.supplier, '클레임 거래처 ID 불일치');
      await form.locator('textarea[name="supplier_claim[description]"]').fill(CLAIM);
      await write(form, '접수');
    }
    await textIs(CLAIM); check((await page.locator('body').innerText()).includes(FACTORY), '클레임 거래처 확인 실패');
    check(/^\/supplier_claims\/\d+$/.test(new URL(page.url()).pathname), '클레임 상세 저장 확인 실패');
  });
  await step(13, 11, '문제 해결', async () => skip('11장은 문제 해결 참고 문서로 별도 화면 없음'));
} finally {
  if (browser) await browser.close();
  console.table(results.map(({ id, chapter, title, status, note }) => ({ id, chapter, title, status, note })));
  if (results.some(result => result.status === 'fail')) process.exitCode = 1;
}
