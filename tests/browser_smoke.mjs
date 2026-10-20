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

// Opens the page, makes the world from the first screen and waits until it is built:
// the phone taps "Создать мир", the desktop presses Enter.
async function open(name, options, init, tapDpr) {
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
  // The world setup screen prints where its start button is.
  let deadline = Date.now() + 120000;
  const shown = () => log.find((t) => t.startsWith('world setup shown'));
  while (!shown() && Date.now() < deadline) await page.waitForTimeout(500);
  if (!shown()) errors.push(`${name}: the world setup screen did not show within 120 s`);
  else if (tapDpr) {
    const r = (shown().match(/-?[\d.]+/g) || []).map(Number);
    await page.touchscreen.tap((r[0] + r[2] / 2) / tapDpr, (r[1] + r[3] / 2) / tapDpr);
  } else {
    await page.keyboard.press('Enter');
  }
  // Wait until the world is built (main.gd prints "world ready").
  deadline = Date.now() + 180000;
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
    jump: field(/jump (\[[^\]]*\])/),
    hotbar: field(/hotbar (\[[^\]]*\])/),
    menu: field(/menu (\[[^\]]*\])/),
    test: field(/test (\[[^\]]*\])/),
    season: field(/season (\[[^\]]*\])/),
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
    dpr,
  );
  const d0 = await debug(page, log);
  console.log(`phone layout: ${d0.line}`);
  const visibleBottom = (390 * dpr);
  const inside = (r) => r.length === 4 && r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= 844 * dpr + 1 && r[1] + r[3] <= visibleBottom + 1;
  if (!inside(d0.stick)) errors.push(`phone: joystick is outside the visible screen: ${d0.stick}`);
  if (!inside(d0.buttons)) errors.push(`phone: the action button is outside the visible screen: ${d0.buttons}`);
  if (!inside(d0.jump)) errors.push(`phone: the jump button is outside the visible screen: ${d0.jump}`);
  if (!inside(d0.hotbar)) errors.push(`phone: the hotbar is outside the visible screen: ${d0.hotbar}`);
  if (!inside(d0.menu)) errors.push(`phone: the menu button is outside the visible screen: ${d0.menu}`);

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

    // Hold the joystick with one finger and jump with another: the second finger
    // must reach the jump button.
    if (d1.jump.length === 4) {
      const jx = (d1.jump[0] + d1.jump[2] / 2) / dpr;
      const jy = (d1.jump[1] + d1.jump[3] / 2) / dpr;
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: cx, y: cy, id: 0 }] });
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: cx, y: cy, id: 0 }, { x: jx, y: jy, id: 1 }] });
      await page.waitForTimeout(600);
      let rose = false;
      let last = d1;
      for (let i = 0; i < 3 && !rose; i++) {
        last = await debug(page, log);
        rose = last.player[1] - d1.player[1] > 0.05;
      }
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      if (!rose) errors.push(`phone: jump with a second finger while holding the joystick did nothing: ${d1.player} -> ${last.player}`);
    }
  }
  if (d0.test.length === 4) {
    // Open the playtest page with the flask button and tap the season's "next" arrow.
    const center = (r) => [(r[0] + r[2] / 2) / dpr, (r[1] + r[3] / 2) / dpr];
    await page.touchscreen.tap(...center(d0.test));
    await page.waitForTimeout(500);
    const d2 = await debug(page, log);
    if (d2.season.length === 4 && d2.season[2] > 0) {
      const before = log.length;
      await page.touchscreen.tap(...center(d2.season));
      await page.waitForTimeout(1000);
      if (!log.slice(before).some((t) => t.startsWith('season:'))) errors.push('phone: the season arrow on the playtest page did not react to a tap');
    } else {
      errors.push(`phone: the playtest page did not open: ${d2.line}`);
    }
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
  }
  if (d0.menu.length === 4) {
    // The pause menu opens and closes.
    const center = (r) => [(r[0] + r[2] / 2) / dpr, (r[1] + r[3] / 2) / dpr];
    await page.touchscreen.tap(...center(d0.menu));
    await page.waitForTimeout(500);
    const d3 = await debug(page, log);
    if (!/menu \[/.test(d3.line)) errors.push(`phone: no debug line after opening the menu: ${d3.line}`);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
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
