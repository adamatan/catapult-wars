# Roman Catapults

A two-player turn-based artillery duel in Godot — Scorched Earth with onagers,
dressed in the imperial Roman style of the mockups in `reference/`.

Two commanders sit on opposite sides of a procedurally generated valley. Each
turn you may reposition up to three steps, set elevation and force, and loose a
stone. Blast damage falls off with distance, craters permanently reshape the
ground, and a machine whose footing is blown away drops into the hole. Last one
standing wins.

**v1 is local hotseat, two human players, in a browser.** No AI, no netplay.

## Running it

```bash
scripts/fetch_godot.sh          # Godot 4.6-stable + matching web export templates
.godot-bin/godot --path .       # play on the desktop
```

```bash
scripts/build_web.sh            # export to build/web/
python3 tools/serve.py build/web 8000
# then open http://127.0.0.1:8000/index.html
```

The engine and its export templates must be the **same version** — that is the
whole reason `fetch_godot.sh` pins one and installs both.

### Hosting

The web preset is built **without thread support**, and this is verified rather
than assumed: `tools/browser_check.mjs` loads the export from a server that
sends no COOP/COEP headers and confirms it boots with
`crossOriginIsolated=false` and no `SharedArrayBuffer`. So it drops onto any
ordinary static host — GitHub Pages, itch.io, a plain nginx — with no special
configuration.

Two things worth knowing when you deploy: `index.wasm` is ~37 MB uncompressed,
so serve it gzipped or brotli (it drops to roughly a quarter of that), and
`.wasm` must be served as `application/wasm` or the browser refuses to stream
it. `tools/serve.py` sets that mapping; most real hosts already do.

## Controls

| | |
|---|---|
| Mouse | drag the angle dial, the force bar, the step rule; click FIRE |
| Up / Down | elevation |
| Left / Right | force |
| A / D | reposition |
| Space | loose the stone |

## How it fits together

```
src/core/      ballistics, damage, match state — no nodes, no rendering
src/battle/    terrain, catapults, projectile, explosion, the turn machine
src/hud/       the Roman interface, all custom-drawn
src/ui/        title and victory screens
tools/         screenshot harness, playthrough test, browser check, static server
tests/         headless logic tests
```

A few decisions worth knowing before you change anything:

**Projectiles do not use `RigidBody2D`.** `src/core/ballistics.gd` integrates
motion by hand in fixed substeps. That makes a shot fully determined by
`(angle, power, wind)` — reproducible, unit-testable against the closed-form
range equation, and cheap to replay as the ghost arc that lingers after each
shot. Collision is a heightmap lookup, not a physics query, so nothing tunnels
through thin ground at speed.

**Terrain is a heightmap**, one sample every ~1.9px. Craters lower samples
inside a circle. Nothing can overhang or tunnel — that is the price, and it
buys collision that costs an array index.

**Players live in an ordered array**, never `player_a`/`player_b`. v1 ships
two; the mockups show four banners, and the turn rotation, banner row and win
check already iterate.

**The turn state machine is explicit** — `AIM → FIRING → IMPACT → TURN_END` —
and input is accepted only in `AIM`. That is what makes the classic artillery
bug, a second shot queued while the first is in the air, unreachable. There is
a regression test for it in `tools/playthrough.gd`.

**The HUD emits intent and nothing else.** It never reads or writes game state;
`src/battle/battlefield.gd` decides what a signal means and pushes state back.

**Wind is implemented but off.** `Ballistics` takes a wind term and the tests
cover it, but v1 runs at zero and shows no indicator, because none of the
reference mockups have one. Turning it on is a design decision, not a code one.

## Art

The reference images are flat renders with the catapults, banners and HUD baked
in, so they cannot be used as game assets directly. `scripts/make_backdrops.py`
cuts the one usable band out of each — squeezed between the mockup's own player
chips above (y < 150) and its painted catapults below (y > 355), and between
its legion standards on either side — and writes four horizon plates plus the
sky, haze and terrain colours sampled from them. At runtime the plate sits
between a procedural sky and a haze fade, with the generated terrain in front.

Everything else — the dial, the coin knobs, the laurels, the aquila, the
catapults — is drawn in code from `src/hud/roman_style.gd`, so it stays sharp
at any resolution and re-tints per player without a second set of assets.

Fonts are Arsenal Small Caps and Crimson Pro, both SIL Open Font License; the
licences ship alongside them in `assets/fonts/`.

## Checks

```bash
# logic: integrator vs closed form, damage falloff, craters, turn rotation
.godot-bin/godot --headless --path . --script tests/run_tests.gd

# whole matches played to a winner, headlessly
xvfb-run -a -s "-screen 0 1920x1080x24" .godot-bin/godot --path . \
    --script tools/playthrough.gd -- 6

# screenshots of every screen, for eyeballing a change
xvfb-run -a -s "-screen 0 1920x1080x24" .godot-bin/godot --path . \
    --resolution 1920x1080 --script tools/shoot.gd -- all build/shots

# the export actually boots and plays in a real browser
scripts/build_web.sh
python3 tools/serve.py build/web 8000 &
node tools/browser_check.mjs
```

`build/` is gitignored and holds a `.gdignore`, without which the editor
imports the screenshots as project assets and packs them into the next export.

## Not in v1, deliberately

AI opponent, network play, weapon and shield inventory, wind indicator, more
than two players (the data model is ready), sound, fall damage.
