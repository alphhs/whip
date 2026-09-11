const { app, BrowserWindow, globalShortcut, ipcMain, screen } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFile } = require('child_process');

// The whole point: we never send a keystroke. We drop a file, and the
// PostToolUse hook feeds it to Claude between tool calls — no interrupt.
const WHIP_DIR = path.join(os.homedir(), '.claude', 'whip');

// Whips are addressed to ONE Claude session. The hook registers each live
// session in reg/; we aim at the most recently active one, which is the one
// actually working — i.e. the one you want to whip.
function liveSessions() {
  const now = Math.floor(Date.now() / 1000);
  let attached = null;
  try { attached = fs.readFileSync(path.join(WHIP_DIR, 'attached'), 'utf8').trim(); } catch {}
  try {
    return fs.readdirSync(path.join(WHIP_DIR, 'reg'))
      .filter(f => f.endsWith('.json'))
      .map(f => {
        let r; try { r = JSON.parse(fs.readFileSync(path.join(WHIP_DIR,'reg',f),'utf8')); } catch { return null; }
        try { process.kill(r.pid, 0); } catch { return null; }        // session is gone
        // soreness decays one step per 10 min, same rule the pet state defines
        let sore = 0;
        try {
          const [n, last] = fs.readFileSync(path.join(WHIP_DIR,'pet',r.id),'utf8').split('	').map(Number);
          sore = Math.max(0, (n || 0) - (last ? Math.floor((now - last)/600) : 0));
        } catch {}
        const idle = now - (r.seen || 0);
        return { id:r.id, cwd:r.cwd || '?', name:(r.name || (r.cwd||'?').split('/').pop()),
                 ts:r.seen || 0, idle, busy: idle < 8, attached: r.id === attached, sore };
      })
      .filter(Boolean)
      .sort((a,b) => (b.attached?1:0)-(a.attached?1:0) || b.ts - a.ts);
  } catch { return []; }
}

let overlay = null;
let ready = false, showQueued = false;

function createOverlay() {
  overlay = new BrowserWindow({
    show: false,
    transparent: true,
    frame: false,
    alwaysOnTop: true,
    focusable: false,
    skipTaskbar: true,
    resizable: false,
    hasShadow: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      autoplayPolicy: 'no-user-gesture-required',  // cracks must fire on drag, not just click
    },
  });
  overlay.setAlwaysOnTop(true, 'screen-saver');
  overlay.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  overlay.loadFile('overlay.html');
  overlay.webContents.on('did-finish-load', () => {
    ready = true;
    if (showQueued) {                 // hotkey arrived before the page was up
      showQueued = false;
      overlay.webContents.send('show', { sessions: liveSessions(), cursor: cursorInWindow(), safe: safeInset() });
      sendFocusedRect();
    }
    if (process.env.WHIP_DEBUG) console.log('[dbg] did-finish-load; windows=' + BrowserWindow.getAllWindows().length);
  });
  if (process.env.WHIP_DEBUG) {
    overlay.webContents.on('console-message', (_e, _lvl, msg) => console.log('[renderer] ' + msg));
  }
  overlay.on('closed', () => { overlay = null; ready = false; });
}

// Follow the cursor's display instead of assuming the primary one.
function moveToCursorDisplay() {
  const { bounds } = screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
  overlay.setBounds(bounds);
}

// The renderer only learns the pointer from mousemove, so before you move it
// the whip would spawn at (0,0) — the top-left corner instead of your hand.
// Rect of whatever window is focused when you hit the hotkey — i.e. the
// Claude window you're looking at. Async: osascript costs ~100ms and we
// don't want the overlay to lag behind the keypress.
const RECT_SCRIPT = [
  'tell application "System Events"',
  '  set p to first application process whose frontmost is true',
  '  set w to first window of p',
  '  set {x, y} to position of w',
  '  set {ww, hh} to size of w',
  '  return (x as string) & "," & (y as string) & "," & (ww as string) & "," & (hh as string)',
  'end tell',
].join('\n');

function sendFocusedRect() {
  execFile('osascript', ['-e', RECT_SCRIPT], { timeout: 1200 }, (err, out) => {
    if (err || !overlay || !overlay.isVisible()) return;
    const n = String(out).trim().split(',').map(Number);
    if (n.length !== 4 || n.some(v => !isFinite(v))) return;
    const b = overlay.getBounds();
    overlay.webContents.send('anchor', {           // window-relative
      x: n[0] - b.x, y: n[1] - b.y, w: n[2], h: n[3],
    });
  });
}

// The overlay covers the display's full bounds so effects can cover the whole
// screen, but the menu bar and Dock sit on top of it. Report that inset so the
// HUD can stay inside the area the user can actually see.
function safeInset() {
  const d = screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
  const b = d.bounds, w = d.workArea;
  return { t: w.y - b.y, l: w.x - b.x,
           r: (b.x + b.width) - (w.x + w.width),
           b: (b.y + b.height) - (w.y + w.height) };
}

function cursorInWindow() {
  const c = screen.getCursorScreenPoint(), b = overlay.getBounds();
  return { x: c.x - b.x, y: c.y - b.y };
}

function hideOverlay() {
  if (overlay) overlay.hide();
  globalShortcut.unregister('Escape');             // give the keys straight back
  for (const k of ['1','2','3','4','5','6','7','R']) globalShortcut.unregister(k);
}

function toggle() {
  if (!overlay) return;
  if (overlay.isVisible()) { hideOverlay(); return; }
  moveToCursorDisplay();
  overlay.showInactive();          // never steal focus from the terminal
  // Borrow the CS keys only while the whip is up, then hand them straight
  // back. Same rule as Escape: never hold a key globally at idle.
  globalShortcut.register('Escape', hideOverlay);
  for (const k of ['1','2','3','4','5','6','7']) {
    globalShortcut.register(k, () => overlay.webContents.send('key', k));
  }
  globalShortcut.register('R', () => overlay.webContents.send('key', 'r'));
  if (ready) {
    overlay.webContents.send('show', { sessions: liveSessions(), cursor: cursorInWindow(), safe: safeInset() });
    sendFocusedRect();
  } else {
    showQueued = true;   // otherwise the overlay shows as a fully invisible window
  }
}

ipcMain.on('crack', (_e, payload) => {
  try {
    const { sessionId, msg, weapon } = payload || {};
    const id = sessionId || (liveSessions()[0] || {}).id;
    if (!id) return;                           // nothing running; nothing to hit
    fs.mkdirSync(path.join(WHIP_DIR, 's'), { recursive: true });
    fs.mkdirSync(path.join(WHIP_DIR, 'pet'), { recursive: true });
    // Tagged src:game so the hook never presents a canned slogan as something
    // the user said. Only words the user actually typed get src:user.
    fs.writeFileSync(path.join(WHIP_DIR, 's', id), JSON.stringify({
      text: String(msg || 'FASTER'), src: 'game', weapon: String(weapon || 'whip') }));
    // soreness lives with the session, so it survives the overlay closing
    const pf = path.join(WHIP_DIR, 'pet', id);
    let n = 0; try { n = Number(fs.readFileSync(pf,'utf8').split('\t')[0]) || 0; } catch {}
    fs.writeFileSync(pf, `${n + 1}\t${Math.floor(Date.now()/1000)}`);
  } catch (err) {
    console.warn('could not arm whip:', err.message);
  }
});

ipcMain.handle('sounds', () => {
  const dir = path.join(__dirname, 'sounds');
  return ['A','B','C','D','E'].map(n => {
    try { return fs.readFileSync(path.join(dir, n + '.mp3')); } catch { return null; }
  }).filter(Boolean);
});

ipcMain.on('dismiss', hideOverlay);

// No requestSingleInstanceLock(): launchd's one-job-one-process already
// guarantees a single instance, and a stale Electron lock makes every
// spawn quit on start, which KeepAlive then retries forever.
// Safe now that no launchd KeepAlive is respawning us: a second launch
// exits instead of fighting the first one for the hotkey and serving stale code.
if (!app.requestSingleInstanceLock()) {
  console.error('whipclaude is already running — this instance is exiting.');
  app.exit(0);
}

app.whenReady().then(() => {
  if (process.platform === 'darwin' && app.dock) app.dock.hide(); // utility, not an app
  if (!overlay) createOverlay();

  if (!globalShortcut.register('CommandOrControl+Shift+W', toggle)) {
    console.error('Could not register Cmd+Shift+W — another app owns it.');
  }
  // NEVER hold Escape globally: globalShortcut grabs it machine-wide, so it
  // would stop reaching Claude Code (where Esc is the interrupt) and every
  // other app. Only borrow it while the whip is actually on screen.

  console.log('whipclaude ready — Cmd+Shift+W to summon, Esc to dismiss');
});

app.on('will-quit', () => globalShortcut.unregisterAll());
app.on('window-all-closed', e => e.preventDefault());
