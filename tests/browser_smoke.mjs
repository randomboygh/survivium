// Opens the exported web build in headless Chrome (software WebGL), walks around,
// prints the browser console and a small screenshot as base64, and fails on script errors.
// Run from the repo root after exporting to build/web and serving it on port 8060.
import { chromium } from 'playwright-core';

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const page = await browser.newPage({ viewport: { width: 640, height: 360 } });
const errors = [];
page.on('console', (m) => {
  const text = m.text();
  console.log(`[console.${m.type()}] ${text}`);
  if (/SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Invalid get|Invalid set/.test(text)) errors.push(text);
});
page.on('pageerror', (e) => {
  console.log(`[pageerror] ${e.message}`);
  errors.push(e.message);
});

await page.goto('http://localhost:8060/index.html');
// Wait until the world is built (main.gd prints "world ready").
const deadline = Date.now() + 180000;
let ready = false;
page.on('console', (m) => { if (m.text().includes('world ready')) ready = true; });
while (!ready && Date.now() < deadline) await page.waitForTimeout(1000);
if (!ready) errors.push('world was not ready within 180 s');

await page.waitForTimeout(3000);
for (const key of ['KeyD', 'KeyS', 'KeyA', 'KeyW']) {
  await page.keyboard.down(key);
  await page.waitForTimeout(800);
  await page.keyboard.up(key);
}
// Dig in front of the player and switch to winter to exercise shaders and meshing.
await page.mouse.click(330, 190);
await page.keyboard.press('KeyZ');
await page.keyboard.press('KeyZ');
await page.waitForTimeout(4000);

const shot = await page.screenshot({ type: 'jpeg', quality: 70 });
console.log(`SCREENSHOT_BASE64 ${shot.toString('base64')}`);
await browser.close();

if (errors.length) {
  console.log(`Smoke test failed with ${errors.length} error(s)`);
  process.exit(1);
}
console.log('Smoke test passed');
