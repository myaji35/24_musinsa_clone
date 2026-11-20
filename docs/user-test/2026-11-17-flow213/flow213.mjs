import { chromium } from '/tmp/ujt/pw1115/node_modules/playwright/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';

// 작성 전용: 명시적으로 실행했을 때만 브라우저를 열고 테스트 데이터를 생성한다.
const BASE = process.env.BASE || 'http://127.0.0.1:3073';
const OUT = resolve(process.env.OUT || 'tmp/e2e/flow213-output');
const password = process.env.E2E_PASS;
const adminEmail = process.env.E2E_ADMIN;
const email = `e2e-213-${Date.now()}@example.com`;
const report = { base: BASE, email, startedAt: new Date().toISOString(), orders: [], steps: [] };
let browser, member, admin, activePage, activeStep;
const errorText = error => error instanceof Error ? error.message : String(error);
const save = () => writeFile(join(OUT, 'result.json'), JSON.stringify(report, null, 2) + '\n');
const field = (page, name) => page.locator(`[name="${name}"]:not([type="hidden"])`);
async function go(page, path) {
  const response = await page.goto(new URL(path, BASE).href, { waitUntil: 'load' });
  if (response?.status() >= 400) throw new Error(`HTTP ${response.status()}: ${page.url()}`);
}
async function visible(locator) { await locator.waitFor({ state: 'visible' }); }
async function text(page, value) { await visible(page.locator('main').getByText(value, { exact: true }).filter({ visible: true })); }
async function clickTo(page, locator, path) {
  await Promise.all([
    page.waitForURL(url => typeof path === 'string' ? url.pathname === path : path.test(url.pathname), { waitUntil: 'load' }),
    locator.click(),
  ]);
}
async function step(number, name, page, action) {
  activePage = page;
  activeStep = { number, name, url: page.url(), success: false, message: '' };
  report.steps.push(activeStep);
  const message = await action();
  activeStep.url = page.url();
  activeStep.screenshot = `${String(number).padStart(2, '0')}-${name}.png`;
  await page.screenshot({ path: join(OUT, activeStep.screenshot), fullPage: true });
  activeStep.success = true;
  activeStep.message = message || '확인 완료';
  await save();
}
async function signupFields(page) {
  for (const [name, value] of Object.entries({ name: '흐름213', email, password, password_confirmation: password })) {
    await field(page, `member[${name}]`).fill(value);
  }
}
const orderCard = (page, number) => page.locator('main').locator('ul.md\\:hidden > li').filter({ hasText: number });
async function order(page) {
  await go(page, '/');
  const product = await page.locator('a[href^="/products/"]').first().getAttribute('href');
  if (!product) throw new Error('첫 공개 상품을 찾지 못했습니다.');
  await go(page, product);
  const buy = page.locator('form#buy');
  const variant = buy.locator('input[name="variant_id"]:not(:disabled)').first();
  await variant.waitFor({ state: 'attached' });
  await variant.locator('..').click();
  await field(page, 'quantity').fill('1');
  await clickTo(page, buy.getByRole('button', { name: '장바구니', exact: true }), '/cart');
  await clickTo(page, page.getByRole('link', { name: /주문하기/ }).first(), '/checkout/new');
  for (const [name, value] of Object.entries({ recipient_name: '흐름213', phone: '01000002130', postal_code: '04524', address1: '서울특별시 중구 세종대로 110', address2: 'E2E 테스트' })) {
    await field(page, `checkout[${name}]`).fill(value);
  }
  await field(page, 'checkout[privacy_consent]').check();
  await clickTo(page, page.getByRole('button', { name: '주문하기', exact: true }), /^\/orders\/[^/]+$/);
  await text(page, '결제 대기');
  const checkoutUrl = page.url();
  await page.screenshot({ path: join(OUT, `${String(activeStep.number).padStart(2, '0')}-order-complete.png`), fullPage: true });
  await go(page, '/my/orders');
  const card = page.locator('main').locator('ul.md\\:hidden > li').first();
  await visible(card);
  const number = (await card.innerText()).match(/ORD-\d{8}-[A-Z0-9]+/)?.[0];
  if (!number || report.orders.some(item => item.number === number)) throw new Error('새 주문번호를 확인하지 못했습니다.');
  await visible(card.getByText('결제 대기', { exact: true }).filter({ visible: true }));
  const claimPath = await card.getByRole('link', { name: '취소 요청', exact: true }).getAttribute('href');
  const result = { number, checkoutUrl, claimPath };
  report.orders.push(result);
  return result;
}
async function cancel(page, order, immediate) {
  await go(page, '/my/orders');
  await clickTo(page, orderCard(page, order.number).getByRole('link', { name: '취소 요청', exact: true }), /^\/my\/orders\/\d+\/claims\/new$/);
  await page.locator('input[name="order_claim[kind]"][value="cancel"]').check();
  await field(page, 'order_claim[reason_code]').selectOption('changed_mind');
  await clickTo(page, page.getByRole('button', { name: '요청하기', exact: true }), '/my/orders');
  const card = orderCard(page, order.number);
  await visible(card.getByText(immediate ? '취소 완료' : '취소 접수', { exact: true }).filter({ visible: true }));
  if (immediate) await visible(card.getByText('취소', { exact: true }).filter({ visible: true }));
}

await mkdir(OUT, { recursive: true });
try {
  if (!password || !adminEmail) throw new Error('E2E_PASS와 E2E_ADMIN이 필요합니다.');
  browser = await chromium.launch({ headless: true });
  const phone = await browser.newContext({ viewport: { width: 360, height: 780 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  member = await phone.newPage();
  member.setDefaultTimeout(15000);
  member.on('dialog', dialog => dialog.accept());
  await step(1, 'join-consent-errors', member, async () => {
    await go(member, '/join');
    await signupFields(member);
    await member.getByRole('button', { name: '회원가입', exact: true }).click();
    for (const message of ['이용약관에 동의해 주세요.', '개인정보 수집·이용에 동의해 주세요.', '만 14세 이상만 가입할 수 있습니다.']) {
      await visible(member.locator('main').getByRole('alert').getByText(message, { exact: true }).filter({ visible: true }));
    }
    return '동의 안내 3개 확인';
  });
  await step(2, 'join-success', member, async () => {
    await signupFields(member);
    for (const name of ['terms_agreement', 'privacy_agreement', 'age_confirmation']) await field(member, `member[${name}]`).check();
    await clickTo(member, member.getByRole('button', { name: '회원가입', exact: true }), '/');
    await text(member, '회원가입이 완료되었습니다.');
  });
  let first, second;
  await step(3, 'first-order', member, async () => { first = await order(member); return `주문 완료: ${first.number}`; });
  await step(4, 'immediate-cancel', member, async () => { await cancel(member, first, true); });
  await step(5, 'second-pending-order', member, async () => { second = await order(member); return `결제 대기: ${second.number}`; });
  const desktop = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  admin = await desktop.newPage();
  admin.setDefaultTimeout(15000);
  admin.on('dialog', dialog => dialog.accept());
  await step(6, 'confirm-payment', admin, async () => {
    await go(admin, '/login');
    await field(admin, 'email').fill(adminEmail);
    await field(admin, 'password').fill(password);
    await Promise.all([admin.waitForURL(url => url.pathname !== '/login'), admin.getByRole('button', { name: '로그인', exact: true }).click()]);
    await go(admin, '/admin_orders');
    const row = admin.locator('tr:visible').filter({ hasText: second.number });
    const form = row.locator('form[action$="/confirm_payment"]');
    await form.getByRole('button', { name: '입금 확인', exact: true }).click();
    await visible(row.getByRole('cell', { name: 'paid', exact: true }));
  });
  await step(7, 'paid-cancel-request', member, async () => {
    await go(member, '/my/orders');
    await visible(orderCard(member, second.number).getByText('결제 완료', { exact: true }).filter({ visible: true }));
    await cancel(member, second, false);
  });
  let claimId;
  await step(8, 'refund-completed', admin, async () => {
    await go(admin, '/admin/order_claims');
    const row = admin.locator('tr:visible').filter({ hasText: second.number });
    await clickTo(admin, row.getByRole('link', { name: '상세', exact: true }), /^\/admin\/order_claims\/\d+$/);
    claimId = new URL(admin.url()).pathname.split('/').at(-1);
    report.claimId = claimId;
    await admin.getByRole('button', { name: '승인', exact: true }).click();
    await visible(admin.getByRole('button', { name: '환불 완료', exact: true }));
    await admin.getByRole('button', { name: '환불 완료', exact: true }).click();
    const section = admin.locator('main').locator('section').filter({ has: admin.getByRole('heading', { name: '요청 내용', exact: true }) });
    await visible(section.locator('dt').filter({ hasText: /^상태$/ }).locator('+ dd').getByText('완료', { exact: true }).filter({ visible: true }));
    await visible(admin.locator('main').locator('dt').filter({ hasText: /^주문 상태$/ }).locator('+ dd').getByText('취소', { exact: true }).filter({ visible: true }));
  });
  await step(9, 'access-logs', admin, async () => {
    await go(admin, '/admin/access_logs');
    const row = admin.locator('tr:visible').filter({ has: admin.getByRole('cell', { name: `OrderClaim #${claimId}`, exact: true }) })
      .filter({ has: admin.getByRole('cell', { name: '주문 클레임 상세', exact: true }) });
    await visible(row.first());
    return `방금 처리한 클레임 #${claimId} 상세 화면 접속기록 확인`;
  });
  await step(10, 'profile-password', member, async () => {
    await go(member, '/my/edit');
    await field(member, 'user[name]').fill('흐름213수정');
    await clickTo(member, member.getByRole('button', { name: '저장', exact: true }), '/my');
    await text(member, '흐름213수정');
    await go(member, '/my/password');
    await field(member, 'password_change[current_password]').fill(password);
    await field(member, 'password_change[password]').fill(password + 'x');
    await field(member, 'password_change[password_confirmation]').fill(password + 'x');
    await clickTo(member, member.getByRole('button', { name: '비밀번호 변경', exact: true }), '/my');
    await text(member, '비밀번호를 변경했습니다.');
  });
  await step(11, 'withdraw-login-rejected', member, async () => {
    await go(member, '/my/withdraw');
    await field(member, 'withdrawal[password]').fill(password + 'x');
    await field(member, 'withdrawal[acknowledge]').check();
    await clickTo(member, member.getByRole('button', { name: '회원 탈퇴', exact: true }), '/');
    await text(member, '회원 탈퇴가 완료되었습니다. 그동안 이용해 주셔서 감사합니다.');
    await member.screenshot({ path: join(OUT, '11-withdraw-home.png'), fullPage: true });
    await go(member, '/login');
    await field(member, 'email').fill(email);
    await field(member, 'password').fill(password + 'x');
    await member.getByRole('button', { name: '로그인', exact: true }).click();
    await text(member, '이메일 또는 비밀번호가 올바르지 않습니다.');
    if (new URL(member.url()).pathname !== '/login') throw new Error('탈퇴 후 로그인 실패 경로가 아닙니다.');
    return '탈퇴 후 홈·완료 문구 및 같은 이메일 로그인 실패 확인';
  });
  report.success = true;
} catch (error) {
  report.success = false;
  report.error = errorText(error);
  if (activeStep) {
    activeStep.success = false;
    activeStep.url = activePage.url();
    activeStep.message = report.error;
    activeStep.screenshot = `${String(activeStep.number).padStart(2, '0')}-${activeStep.name}-failed.png`;
    await activePage.screenshot({ path: join(OUT, activeStep.screenshot), fullPage: true }).catch(e => { activeStep.screenshotError = errorText(e); });
  }
  await save();
  process.exitCode = 1;
} finally {
  await browser?.close().catch(error => { report.closeError = errorText(error); });
  report.finishedAt = new Date().toISOString();
  await save();
}
