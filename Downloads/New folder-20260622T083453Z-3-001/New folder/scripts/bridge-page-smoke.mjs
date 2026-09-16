import { chromium } from 'playwright';

const BASE = process.env.BASE_URL ?? 'http://localhost:5173';
const logs = [];

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();

page.on('console', (msg) => {
  const text = msg.text();
  if (text.includes('[bridge]') || text.includes('Too many') || text.includes('301') || msg.type() === 'error') {
    logs.push(`[${msg.type()}] ${text}`);
  }
});

page.on('pageerror', (err) => {
  logs.push(`[pageerror] ${err.message}`);
});

await page.goto(`${BASE}/app/bridge`, { waitUntil: 'domcontentloaded', timeout: 60000 });
await page.waitForTimeout(3000);

const title = await page.locator('.titan-bridge-title, .titan-bridge-error h2, .titan-boot-error h1').first().textContent().catch(() => null);
const renderLogs = logs.filter((l) => l.includes('BridgeExperience render'));
const has301 = logs.some((l) => l.includes('301') || l.includes('Too many'));

console.log('URL:', page.url());
console.log('Visible title:', title);
console.log('Bridge render logs:', renderLogs.length);
console.log('React 301:', has301);
if (logs.length) console.log('Sample logs:', logs.slice(0, 8).join('\n'));

await browser.close();
process.exit(has301 || renderLogs.length > 10 ? 1 : 0);
