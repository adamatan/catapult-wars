// Loads the exported web build in Chromium and proves it actually plays.
//
// A headless `--export-release` can succeed and still produce something that
// never boots, so this drives the real thing: wait for the engine to start,
// screenshot the title, click through to a match, fire a shot, and screenshot
// the result. Any page error or failed request is a failure.
//
//   node tools/browser_check.mjs [baseUrl] [outDir]

import { mkdir } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

// Playwright may be installed globally rather than beside this repo, and ESM
// imports ignore NODE_PATH, so fall back to asking npm where it lives.
const chromium = await (async () => {
  let mod;
  try {
    mod = await import('playwright');
  } catch {
    const root = execFileSync('npm', ['root', '-g'], { encoding: 'utf8' }).trim();
    mod = await import(pathToFileURL(`${root}/playwright/index.js`).href);
  }
  // Playwright is CommonJS; loaded by absolute path its named exports are not
  // statically detectable, so they arrive under `default` instead.
  return mod.chromium ?? mod.default?.chromium;
})();

const BASE_URL = process.argv[2] ?? 'http://127.0.0.1:8000/index.html';
const OUT_DIR = process.argv[3] ?? 'build/shots/web';

// The canvas is 1920x1080 in game space; these are fractions of it, so the
// clicks land correctly whatever the browser scales the canvas to.
const ADVANCE_BUTTON = { x: 0.5, y: 0.75 };
const FIRE_BUTTON = { x: 0.82, y: 0.85 };

const problems = [];

async function main() {
  await mkdir(OUT_DIR, { recursive: true });

  const browser = await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium',
    args: [
      '--use-gl=angle',
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      '--no-sandbox',
    ],
  });
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });

  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
  page.on('requestfailed', (r) =>
    problems.push(`requestfailed: ${r.url()} ${r.failure()?.errorText ?? ''}`));
  page.on('console', (m) => {
    if (m.type() === 'error') problems.push(`console.error: ${m.text()}`);
  });

  console.log(`loading ${BASE_URL}`);
  const response = await page.goto(BASE_URL, { waitUntil: 'load', timeout: 60_000 });
  if (!response?.ok()) problems.push(`page returned HTTP ${response?.status()}`);

  // Cross-origin isolation is what Godot needs for threads. The server serves
  // no COOP/COEP headers, so this reports whether the build needs them.
  const isolated = await page.evaluate(() => globalThis.crossOriginIsolated === true);
  const hasSAB = await page.evaluate(() => typeof SharedArrayBuffer !== 'undefined');
  console.log(`crossOriginIsolated=${isolated}  SharedArrayBuffer=${hasSAB}`);

  const canvas = page.locator('canvas');
  await canvas.waitFor({ state: 'visible', timeout: 60_000 });

  // Godot boots asynchronously behind the loading bar; wait for the canvas to
  // have real content rather than trusting a fixed sleep.
  await waitForCanvasToRender(page, 90_000);

  await shoot(page, 'web-title');
  await assertNotBlank(page, 'title');

  await clickCanvas(page, canvas, ADVANCE_BUTTON);
  await page.waitForTimeout(2500);
  await shoot(page, 'web-battle');
  await assertNotBlank(page, 'battle');

  await clickCanvas(page, canvas, FIRE_BUTTON);
  await page.waitForTimeout(600);
  await shoot(page, 'web-flight');
  await page.waitForTimeout(3500);
  await shoot(page, 'web-resolved');

  await browser.close();

  if (problems.length) {
    console.error('\nFAILED');
    for (const p of problems) console.error('  ' + p);
    process.exit(1);
  }
  console.log('\nPASS  the web build boots, renders and takes a shot');
}

/**
 * Poll until the canvas has real content on it.
 *
 * Not "until two frames differ" — the title screen is deliberately static, so
 * a difference test reports a perfectly good build as never having rendered.
 * Contrast is the honest signal: a booting Godot canvas is a flat colour.
 */
async function waitForCanvasToRender(page, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if ((await canvasLumaSpread(page)) >= 25) return;
    await page.waitForTimeout(500);
  }
  problems.push('canvas never rendered anything');
}

async function clickCanvas(page, canvas, at) {
  const box = await canvas.boundingBox();
  if (!box) {
    problems.push('canvas has no bounding box');
    return;
  }
  await page.mouse.click(box.x + box.width * at.x, box.y + box.height * at.y);
}

async function shoot(page, name) {
  await page.screenshot({ path: `${OUT_DIR}/${name}.png` });
  console.log(`  wrote ${OUT_DIR}/${name}.png`);
}

/** A build that boots to a black rectangle is a failure that a screenshot alone hides. */
async function assertNotBlank(page, label) {
  const spread = await canvasLumaSpread(page);
  console.log(`  ${label}: luma spread ${spread.toFixed(1)}`);
  if (spread < 12) problems.push(`${label} screen is effectively blank (spread ${spread})`);
}

/** Difference between the brightest and darkest pixel the canvas is showing. */
async function canvasLumaSpread(page) {
  return await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) return 0;
    const scratch = document.createElement('canvas');
    scratch.width = 160;
    scratch.height = 90;
    const ctx = scratch.getContext('2d');
    ctx.drawImage(canvas, 0, 0, scratch.width, scratch.height);
    const { data } = ctx.getImageData(0, 0, scratch.width, scratch.height);
    let min = 255;
    let max = 0;
    for (let i = 0; i < data.length; i += 4) {
      const luma = 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];
      min = Math.min(min, luma);
      max = Math.max(max, luma);
    }
    return max - min;
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
