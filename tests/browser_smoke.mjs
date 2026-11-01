// Opens the exported web build in headless Chrome (software WebGL): as a desktop browser,
// as a phone in landscape whose toolbar hides the bottom of the page, and as a phone
// held upright opening a link to a server. Plays a little in the first two, joins in the
// third, prints the browser console and a screenshot of each as base64, and fails on
// script errors or touch controls outside the visible screen. Software WebGL
// draws a frame in a second or more and every input event waits for one, so the test sends
// as few events as it can.
// Run from the repo root after exporting to build/web and serving it on port 8060:
//     node tests/browser_smoke.mjs [desktop] [phone] [upright]     (all when none is named)
import { chromium } from 'playwright-core';

const URL = 'http://localhost:8060/index.html';
// Phone toolbar the page is laid out under, in CSS pixels.
const TOOLBAR = 60;
const asked = process.argv.slice(2);
const runs = (name) => asked.length === 0 || asked.includes(name);

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const errors = [];

// The button `key` of a line like "menu page single: play [P: (x, y), S: (w, h)], new …".
const rectOf = (line, key) => {
  const at = line.indexOf(` ${key} [`);
  return at < 0 ? '' : line.slice(at + key.length + 2, line.indexOf(']', at) + 1);
};

// Opens the page, goes into the world from the main menu and waits until it is built:
// the phone taps «Одиночная игра», "Новый мир" and then "Создать мир" on the setup
// screen (the same world, so the menu goes straight in), the desktop presses Enter on
// «Одиночная игра» and on "Играть".
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
  // The main menu and the setup screen print where their buttons are.
  const waitFor = async (prefix, what) => {
    const deadline = Date.now() + 120000;
    const line = () => log.find((t) => t.startsWith(prefix));
    while (!line() && Date.now() < deadline) await page.waitForTimeout(500);
    if (!line()) errors.push(`${name}: ${what} did not show within 120 s`);
    return line();
  };
  const tap = async (rect) => {
    const r = (rect.match(/-?[\d.]+/g) || []).map(Number);
    const x = (r[0] + r[2] / 2) / tapDpr;
    const y = (r[1] + r[3] / 2) / tapDpr;
    // A tap outside the viewport lands nowhere: say so instead of waiting in vain later.
    const view = page.viewportSize();
    if (x < 0 || y < 0 || x >= view.width || y >= view.height) errors.push(`${name}: the button at ${rect} is outside the visible screen (${view.width}x${view.height} CSS px)`);
    await page.touchscreen.tap(x, y);
  };
  const menu = await waitFor('main menu shown', 'the main menu');
  if (menu && tapDpr) {
    // The easter egg: ten taps on the sparrow of the name blow it up and bring out the
    // «Тестирование» buttons (the flask is tapped in the game below).
    const sparrow = rectOf(menu, 'sparrow');
    for (let i = 0; sparrow && i < 10; i++) {
      await tap(sparrow);
      await page.waitForTimeout(120);
    }
    await waitFor('easter egg', 'the easter egg after ten taps on the sparrow');
    await tap(rectOf(menu, 'single'));
    const single = await waitFor('menu page single', 'the page «Одиночная игра»');
    if (single) await tap(rectOf(single, 'new'));
    const setup = await waitFor('world setup shown', 'the world setup screen');
    if (setup) await tap(setup);
  } else if (menu) {
    await page.keyboard.press('Enter');
    if (await waitFor('menu page single', 'the page «Одиночная игра»')) await page.keyboard.press('Enter');
  }
  // Wait until the world is built (main.gd prints "world ready").
  const deadline = Date.now() + 180000;
  while (!log.some((t) => t.includes('world ready')) && Date.now() < deadline) await page.waitForTimeout(1000);
  if (!log.some((t) => t.includes('world ready'))) errors.push(`${name}: world was not ready within 180 s`);
  // The menu goes in once the world's first frames have settled (main_menu.gd settled),
  // which under software GL takes minutes of frames seconds long: at least three minutes
  // from when the world was ready, which can come late in the wait above (a phone run
  // closed the menu just after the old shared limit, 2026-11-01).
  if (menu) {
    const settled = Math.max(deadline + 60000, Date.now() + 180000);
    while (!log.some((t) => t.includes('main menu closed')) && Date.now() < settled) await page.waitForTimeout(1000);
    if (!log.some((t) => t.includes('main menu closed'))) errors.push(`${name}: the main menu did not go into the world`);
  }
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
  // A software-WebGL winter frame takes over 3 s, and the screenshot waits behind the
  // frames already queued: the default 30 s is not always enough.
  const shot = await page.screenshot({ type: 'jpeg', quality: 70, scale: 'css', timeout: 120000 });
  console.log(`SCREENSHOT_BASE64 ${name} ${shot.toString('base64')}`);
}

// --- Desktop: keyboard and mouse -------------------------------------------------
if (runs('desktop')) {
  const { context, page } = await open('desktop', { viewport: { width: 1280, height: 720 } });
  for (const key of ['KeyD', 'KeyS']) {
    await page.keyboard.down(key);
    await page.waitForTimeout(800);
    await page.keyboard.up(key);
  }
  // Dig in front of the player and switch to winter to exercise shaders and meshing.
  await page.mouse.click(660, 380);
  await page.keyboard.press('KeyZ');
  await page.keyboard.press('KeyZ');
  await page.waitForTimeout(1000);
  await screenshot('desktop', page);
  await context.close();
}

// --- Phone in landscape, with a toolbar covering the bottom of the page ----------
if (runs('phone')) {
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
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: cx + 40, y: cy }] });
    await page.waitForTimeout(1000);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    const d1 = await debug(page, log);
    // Few frames are drawn in software, so a short step shows the joystick works.
    if (!(d1.player[0] - d0.player[0] > 0.2)) errors.push(`phone: joystick did not move the player: ${d0.player} -> ${d1.player}`);

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
  if (d0.test.length === 4 && d0.test[2] > 0) {
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
  await screenshot('phone', page);
  await context.close();
}

// --- Phone held upright, opening a link to a server --------------------------------
// The link fills «Присоединиться»; with a name typed in, «Подключиться» starts the game
// again joined to the server, which is not there: the screen comes back saying why.
if (runs('upright')) {
  const dpr = 3;
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: dpr,
    isMobile: true, hasTouch: true });
  const page = await context.newPage();
  const log = [];
  page.on('console', (m) => {
    const text = m.text();
    log.push(text);
    console.log(`[upright console.${m.type()}] ${text}`);
    if (/SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Invalid get|Invalid set/.test(text)) errors.push(`upright: ${text}`);
  });
  page.on('pageerror', (e) => errors.push(`upright: ${e.message}`));
  await page.goto(`${URL}?server=127.0.0.1:9`);
  const waitFor = async (prefix, what, from = 0) => {
    const deadline = Date.now() + 120000;
    const line = () => log.slice(from).find((t) => t.startsWith(prefix));
    while (!line() && Date.now() < deadline) await page.waitForTimeout(500);
    if (!line()) errors.push(`upright: ${what} did not show within 120 s`);
    return line() || '';
  };
  const tap = async (rect) => {
    const r = (rect.match(/-?[\d.]+/g) || []).map(Number);
    const x = (r[0] + r[2] / 2) / dpr;
    const y = (r[1] + r[3] / 2) / dpr;
    if (!(r.length === 4 && x >= 0 && y >= 0 && x < 390 && y < 844)) errors.push(`upright: the button at ${rect} is outside the visible screen`);
    await page.touchscreen.tap(x, y);
  };
  const shown = await waitFor('join screen shown', 'the link to a server opening «Присоединиться»');
  if (shown) {
    for (const key of ['url', 'name', 'go', 'back']) {
      const r = (rectOf(shown, key).match(/-?[\d.]+/g) || []).map(Number);
      if (r.length !== 4 || r[0] < 0 || r[1] < 0 || (r[0] + r[2]) / dpr > 390 || (r[1] + r[3]) / dpr > 844) {
        errors.push(`upright: «Присоединиться»'s ${key} is not on the screen: ${rectOf(shown, key)}`);
      }
    }
    await tap(rectOf(shown, 'name'));
    await page.keyboard.type('Тест');
    await page.waitForTimeout(500);
    const before = log.length;
    await tap(rectOf(shown, 'go'));
    const asked = await waitFor('joining ', 'joining the server of the link', before);
    if (!asked.includes('ws://127.0.0.1:9 as Тест')) errors.push(`upright: joined not as asked: ${asked}`);
    const back = await waitFor('join screen shown', '«Присоединиться» after the failed joining', log.indexOf(asked) + 1);
    if (back && !log.some((t) => / failed: /.test(t))) errors.push('upright: the failed joining said nothing');
  }
  await screenshot('upright', page);
  await context.close();
}

await browser.close();
if (errors.length) {
  for (const e of errors) console.log(`ERROR ${e}`);
  console.log(`Smoke test failed with ${errors.length} error(s)`);
  process.exit(1);
}
console.log('Smoke test passed');
