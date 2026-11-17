import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const escape = value => String(value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
if (!process.argv[2] || !process.argv[3]) throw new Error('Usage: node pdf.mjs render-jobs.json version');
const version = process.argv[3];
const config = JSON.parse(await fs.readFile(process.argv[2], 'utf8'));
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.goto(pathToFileURL(path.resolve(config.html)).href, { waitUntil: 'networkidle' });
  await page.emulateMedia({ media: 'print' });
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(image => image.decode()));
  });
  for (const job of config.jobs) {
    const header = `<div style="width:100%;margin:0 18mm;font:9px 'Apple SD Gothic Neo',sans-serif;color:#1F2A44;border-bottom:1px solid #888;padding-bottom:6px">${escape(job.title || 'JIEUM 운영자 매뉴얼')}</div>`;
    const footer = `<div style="width:100%;margin:0 18mm;font:9px 'Apple SD Gothic Neo',sans-serif;display:flex;justify-content:space-between;border-top:1px solid #888;padding-top:6px"><span>JIEUM 운영자 매뉴얼 v${escape(version)}</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>`;
    await page.pdf({ path: job.output, format: 'A4', printBackground: true, preferCSSPageSize: true,
      displayHeaderFooter: !job.cover, headerTemplate: header, footerTemplate: footer,
      margin: { top: '20mm', bottom: '20mm', left: '18mm', right: '18mm' },
      ...(job.pages ? { pageRanges: job.pages } : {}) });
  }
} finally { await browser.close(); }
