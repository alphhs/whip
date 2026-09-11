# Assets — bring your own

Nothing in this folder ships with the repo. The models and audio used during
development came from Sketchfab and elsewhere under licences that don't permit
redistribution, so you supply your own.

**Everything degrades gracefully.** Missing a file just means that weapon has no
model or no sound; the game still runs, aims and does damage.

| file | what it is | used by |
|---|---|---|
| `ak47.glb`    | rifle, any orientation      | slot 3 AK-47 |
| `flamer.glb`  | flamethrower / cannon       | slot 4 Flamethrower |
| `wand.glb`    | wand, thin and long         | slot 5 Avada Kedavra |
| `molotov.glb` | bottle                      | slot 6 Molotov |
| `avada.mp3`   | a voice line to cast with   | slot 5 (optional) |

The **Whip** and **Lightsaber** need no assets at all — both are generated in code.

## Adding a model

Drop the `.glb` in and add a row to `MODELS` at the top of the module block in
`overlay.html`:

```js
gun: { file:"assets/ak47.glb", fwd:[1,0,0], up:[0,1,0], len:1.55, aim:true,
       pos:[0.62,-0.60,0], roll:-0.16, cant:0.10, kick:0.42 },
```

`fwd` is the model's own forward axis in **its** local space — the barrel, the
tip, whichever end points at the target. Models export in wildly different
orientations (the ones used in development were +X, +Y and +Z respectively), so
check yours rather than assuming. `len` normalises the longest extent.

## Sounds

`sounds/A.mp3` … `E.mp3` are whip cracks, played at random with pitch and filter
varied per hit. Any short crack samples work. Without them the whip is silent;
every other weapon synthesises its audio in code and needs no files.
