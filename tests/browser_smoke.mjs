// Opens the exported web build in headless Chrome (software WebGL) twice: as a desktop
// browser and as a phone in landscape whose toolbar hides the bottom of the page.
// Plays a little in each, prints the browser console and a screenshot of each as base64,
// and fails on script errors or touch controls outside the visible screen.
// Run from the repo root after exporting to build/web and serving it on port 8060.
import { chromium } from 'playwright-core';

const URL = 'http://localhost:8060/index.html';
// Phone toolbar the page is laid out under, in CSS pixels.
const TOOLBAR = 60;

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const errors = [];

async function open(name, options, init) {
  const context = await browser.newContext(options);
  if (init) await context.addInitScript(init);
  const page = await context.newPage();
  const log = [];
  page.on('console', (m) => {
    const text = m.text();
    log.push(text);
    console.log(`[${name} console.${m.type()}] ${text}`);
    if (/SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Invalid get|Invalid set/.test(text)) errors.push(`${name}: ${text}`);
  });
  page.on('pageerror', (e) => {
    console.log(`[${name} pageerror] ${e.message}`);
    errors.push(`${name}: ${e.message}`);
  });
  await page.goto(URL);
  // Wait until the world is built (main.gd prints "world ready").
  const deadline = Date.now() + 180000;
  while (!log.some((t) => t.includes('world ready')) && Date.now() < deadline) await page.waitForTimeout(1000);
  if (!log.some((t) => t.includes('world ready'))) errors.push(`${name}: world was not ready within 180 s`);
  await page.waitForTimeout(2000);
  return { context, page, log };
}

// F3 prints the layout and player state; returns the parsed line.
async function debug(page, log) {
  const before = log.length;
  await page.keyboard.press('F3');
  for (let i = 0; i < 20 && !log.slice(before).some((t) => t.startsWith('debug:')); i++) await page.waitForTimeout(250);
  const line = log.slice(before).find((t) => t.startsWith('debug:')) || '';
  const nums = (s) => (s || '').match(/-?[\d.]+/g)?.map(Number) || [];
  const field = (re) => nums(line.match(re)?.[1]);
  return {
    line,
    screen: field(/screen \(([^)]*)\)/),
    ui: field(/ ui (\[[^\]]*\])/),
    stick: field(/stick (\[[^\]]*\])/),
    buttons: field(/buttons (\[[^\]]*\])/),
    player: field(/player \(([^)]*)\)/),
  };
}

async function screenshot(name, page) {
  const shot = await page.screenshot({ type: 'jpeg', quality: 70, scale: 'css' });
  console.log(`SCREENSHOT_BASE64 ${name} ${shot.toString('base64')}`);
}

// --- Desktop: keyboard and mouse -------------------------------------------------
{
  const { context, page } = await open('desktop', { viewport: { width: 1280, height: 720 } });
  for (const key of ['KeyD', 'KeyS', 'KeyA', 'KeyW']) {
    await page.keyboard.down(key);
    await page.waitForTimeout(800);
    await page.keyboard.up(key);
  }
  // Dig in front of the player and switch to winter to exercise shaders and meshing.
  await page.mouse.click(660, 380);
  await page.keyboard.press('KeyZ');
  await page.keyboard.press('KeyZ');
  await page.waitForTimeout(3000);
  await screenshot('desktop', page);
  await context.close();
}

// --- Phone in landscape, with a toolbar covering the bottom of the page ----------
{
  const dpr = 3;
  const { context, page, log } = await open(
    'phone',
    { viewport: { width: 844, height: 390 }, deviceScaleFactor: dpr, isMobile: true, hasTouch: true },
    // The page believes it is TOOLBAR px taller than what is visible, as some mobile
    // browsers report while their toolbar is shown.
    `Object.defineProperty(window, 'innerHeight', { configurable: true,
      get: () => document.documentElement.clientHeight + ${TOOLBAR} });`,
  );
  const d0 = await debug(page, log);
  console.log(`phone layout: ${d0.line}`);
  const visibleBottom = (390 * dpr);
  const inside = (r) => r.length === 4 && r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= 844 * dpr + 1 && r[1] + r[3] <= visibleBottom + 1;
  if (!inside(d0.stick)) errors.push(`phone: joystick is outside the visible screen: ${d0.stick}`);
  if (!inside(d0.buttons)) errors.push(`phone: buttons are outside the visible screen: ${d0.buttons}`);

  if (d0.stick.length === 4) {
    // Push the joystick to the right for a second.
    const cdp = await context.newCDPSession(page);
    const cx = (d0.stick[0] + d0.stick[2] / 2) / dpr;
    const cy = (d0.stick[1] + d0.stick[3] / 2) / dpr;
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: cx, y: cy }] });
    for (let i = 1; i <= 5; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: cx + i * 8, y: cy }] });
      await page.waitForTimeout(50);
    }
    await page.waitForTimeout(1000);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    const d1 = await debug(page, log);
    if (!(d1.player[0] - d0.player[0] > 0.5)) errors.push(`phone: joystick did not move the player: ${d0.player} -> ${d1.player}`);
  }
  if (d0.buttons.length === 4) {
    // "Сезон" is the middle button of the second row.
    const before = log.length;
    await page.touchscreen.tap((d0.buttons[0] + d0.buttons[2] / 2) / dpr, (d0.buttons[1] + d0.buttons[3] * 0.75) / dpr);
    await page.waitForTimeout(1000);
    if (!log.slice(before).some((t) => t.startsWith('season:'))) errors.push('phone: the season button did not react to a tap');
  }
  await page.waitForTimeout(1000);
  await screenshot('phone', page);
  await context.close();
}

await browser.close();
if (errors.length) {
  for (const e of errors) console.log(`ERROR ${e}`);
  console.log(`Smoke test failed with ${errors.length} error(s)`);
  process.exit(1);
}
console.log('Smoke test passed');
