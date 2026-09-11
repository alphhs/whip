#!/usr/bin/env python3
"""Normalise whip crack samples so five of them sound like one whip.

Raw samples vary enormously: the set shipped here spanned 1375-3442Hz in
brightness, 49-195ms in attack, and 1.5x in level. Random-picking between those
and then pitch-shifting on top is what makes a crack sound inconsistent.

  - trim to just before the transient, so the crack lands WHEN YOU SWING
  - match loudness across the set
  - record each sample's brightness to sounds/profile.json, so playback can
    compensate rather than letting a dull sample sound like a different object
"""
import wave, array, math, json, subprocess, pathlib, sys

SRC = pathlib.Path(__file__).resolve().parent.parent / "sounds"
SR, KEEP, LEAD = 22050, 0.62, 0.012

def read(p):
    tmp = "/tmp/_prep.wav"
    subprocess.run(["afconvert","-f","WAVE","-d",f"LEI16@{SR}",str(p),tmp], capture_output=True)
    w = wave.open(tmp); a = array.array('h'); a.frombytes(w.readframes(w.getnframes()))
    return a[::w.getnchannels()] if w.getnchannels() > 1 else a

def centroid(a, sr):
    zc = sum(1 for i in range(1, len(a)) if (a[i-1] < 0) != (a[i] < 0))
    return zc / (len(a)/sr) / 2

prof = {}
names = [p.stem for p in sorted(SRC.glob("*.mp3"))] or [p.stem for p in sorted(SRC.glob("*.wav"))]
for n in names:
    src = SRC/f"{n}.mp3"
    if not src.exists(): src = SRC/f"{n}.wav"
    a = read(src)
    hit = max(range(len(a)), key=lambda i: abs(a[i]))
    s = max(0, hit - int(SR*LEAD))
    seg = a[s:s+int(SR*KEEP)]
    rms = math.sqrt(sum(float(x)*x for x in seg)/len(seg)) or 1
    g = min(4.0, 4200/rms)                       # match level across the set
    out = array.array('h', (max(-32767, min(32767, int(x*g))) for x in seg))
    fade = int(SR*0.05)                          # no click on the tail
    for i in range(fade):
        out[len(out)-fade+i] = int(out[len(out)-fade+i] * (1 - i/fade))
    w = wave.open(str(SRC/f"{n}.wav"), 'w'); w.setnchannels(1); w.setsampwidth(2)
    w.setframerate(SR); w.writeframes(out.tobytes()); w.close()
    prof[n] = round(centroid(out[:int(SR*0.06)], SR))
    print(f"  {n}: attack {hit/SR:.3f}s -> 0.012s, gain x{g:.2f}, brightness {prof[n]}Hz")

target = sorted(prof.values())[len(prof)//2]
json.dump({"target": target, "brightness": prof}, open(SRC/"profile.json","w"), indent=2)
print(f"  target brightness {target}Hz -> sounds/profile.json")
