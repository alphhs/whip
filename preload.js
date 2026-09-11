const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('whip', {
  crack:   (sessionId, msg, weapon) => ipcRenderer.send('crack', { sessionId, msg, weapon }),
  dismiss: ()    => ipcRenderer.send('dismiss'),
  onShow:  (fn)  => ipcRenderer.on('show', (_e, payload) => fn(payload)),
  sounds:  ()    => ipcRenderer.invoke('sounds'),
  presets: ()    => ipcRenderer.invoke('presets'),
  onAnchor:(fn)  => ipcRenderer.on('anchor', (_e, r) => fn(r)),
  onKey:   (fn)  => ipcRenderer.on('key', (_e, k) => fn(k)),
});
