# Greening Tessera

An ad-free arcade idle game about terraforming planets, built in Godot 4 (GDScript, Compatibility renderer, web export first).

- Design and technical spec: [`SPEC.md`](SPEC.md)
- Working Three.js prototype: [`reference/greening-tessera-prototype.html`](reference/greening-tessera-prototype.html) (open it in a browser)
- Choices made along the way: [`DECISIONS.md`](DECISIONS.md)

## Setup

The project is pinned to **Godot 4.7.2**. To download the editor and the web export templates into `tools/godot/` (git-ignored), run:

```sh
tools/setup_godot.sh
```

This works on Linux x86_64 and macOS. The script links the templates into Godot's standard templates folder, so the editor finds them too. If you'd rather use your own Godot install, set `GODOT=/path/to/godot`; every script below respects it.

To open the project in the editor, run `tools/godot/godot -e` (or open `project.godot` from the Godot project manager).

## Running tests

Tests use [GUT](https://github.com/bitwes/Gut) 9.7.1, which is vendored in `addons/gut/`. They live in `tests/`: `tests/unit/` holds pure logic, and `tests/smoke/` loads scenes.

```sh
tools/test.sh                          # whole suite, headless; exits non-zero on failure
tools/test.sh -gselect=test_movement   # a single script
```

Settings are in `.gutconfig.json`. In the editor, you can also run tests from the GUT panel at the bottom.

## Balance simulator

```sh
tools/godot/godot --headless --script tools/balance_sim.gd                  # all planets
tools/godot/godot --headless --script tools/balance_sim.gd -- --planets=0   # Planet 1 only
```

A greedy scripted player (`scripts/systems/bot_player.gd`) plays each planet on the real `GameSim` in accelerated time. It prints the time to each milestone (first build, drone bay, greenhouse, 25/50/75/100%). It exits with code 1 if an enforced planet misses its `target_minutes` (set in its `PlanetDef`) by more than 20%. Run it after every balance change.

It also prints a colony line: colonists housed and waiting, habitats, pods stored as food, how much of the colonists' time was spent hungry, and how many hazards came.

To try a change without editing data, pass `--scale-tf=0.8` (terraform value per item) or `--scale-machine-time=1.2`. `--no-colony` (no landers) and `--no-hazard` (no dust storms) show what each system does to the pace. These change the loaded data in memory only.

## Screenshots without a phone

`tools/dev/screenshot.gd` renders any game state to a PNG (it needs a display; `xvfb-run` works on a server):

```sh
xvfb-run -a -s "-screen 0 1280x1024x24" tools/godot/godot --resolution 390x844 \
  -s tools/dev/screenshot.gd -- --tf=60 --drones=6 --built=all --out=/tmp/shot.png
```

## Models

The Kenney GLBs in `assets/models/` are sources only. `tools/dev/bake_models.gd` merges each one into a single vertex-coloured mesh (`assets/meshes/*.res`) and writes the building scenes in `scenes/buildings/`. That keeps each building, drone and rock to one draw call. After changing a model or its placement in that script, run:

```sh
tools/godot/godot --headless --import && tools/godot/godot --headless --script tools/dev/bake_models.gd
```

`tools/dev/screenshot.gd` also takes `--zoom=0.4` for a closer look, `--face=90` to turn the astronaut, and `--win=25` to show the win screen. For the colony and hazards: `--colonists=6` (habitats built to fit), `--hungry=1`, `--waiting=2`, `--food=5`, `--lander=2.5` (seconds before touchdown), `--storm=warn` or `--storm=on` (with `--storm-t=` seconds left), and `--debug=1` for the debug overlay. `--levels=1` sets every machine to Mk II, and `--haul=3` buys three hauler upgrades.

The Mini Characters used for colonists are rigged and use a colour-atlas texture. The bake tool poses them from their `idle` animation and samples the atlas into vertex colours, so they share the one vertex-colour material too.

## Exporting for web

```sh
tools/export_web.sh
```

This exports the **Web** preset (`export_presets.cfg`) headless into `build/web/`. The preset uses the Compatibility renderer, has thread support off (so it needs no cross-origin isolation headers), has VRAM compression on for desktop and mobile, and is a PWA with `standalone` display.

To try the build locally:

```sh
cd build/web && python3 -m http.server 8000
# then open http://localhost:8000
```

## Deploying to itch.io

```sh
tools/deploy.sh               # export, then butler push build/web richardat/greening-tessera:web
tools/deploy.sh --no-export   # push the existing build/web
```

Before the first deploy:

1. Install [butler](https://itch.io/docs/butler/installing.html) and put it on your `PATH` (or set `BUTLER=/path/to/butler`).
2. Run `butler login` once, or set `BUTLER_API_KEY` (from https://itch.io/user/settings/api-keys) in your environment.
3. On itch.io, create the project `greening-tessera`: set **Kind of project** to *HTML*, keep it private or restricted, and after the first push tick *This file will be played in the browser* on the `web` upload. Under embed options, turn on *Mobile friendly* and *Fullscreen button*, and turn off *Automatically start on page load* only if you want a click-to-play screen. **Do not** enable *SharedArrayBuffer support*, because the build is single-threaded.

To push to a different page, set `ITCH_TARGET=user/game:channel`.

### iPhone Home Screen

Open the game's own URL in Safari. For a full-screen PWA, use the direct HTML5 file URL rather than the itch.io page. Then tap **Share → Add to Home Screen**. The icon opens standalone, with no Safari chrome.

## Project layout

See `SPEC.md` section 7.2. Every tunable number lives in a `.tres` file under `data/`, and scripts only read those resources. The starting point is `data/game.tres`, which links items, planets, upgrades and tuning. Open any of these in the Godot Inspector to change the numbers.

- `scripts/systems/`: pure game rules with no scene access (`GameSim`, `Economy`, `Dispatcher`, `DroneBrain`, `Colony`, `HazardDirector`, `Tutorial`, `BotPlayer`, ...).
- `scripts/autoload/`: `GameState` (the running sim), `SaveManager` (profiles, saves, settings), `EventBus`, `DisplayScale`, `Audio` (sound effects, wind and birdsong).
- `assets/`: fonts, source models (`models/`, not exported), baked meshes (`meshes/`), shared materials and sound effects. Every pack is listed in `assets/LICENSES.md`.
- `shaders/`: pads, label panels, dust, the terraform ground and the lakes.
- `data/juice.tres` and `data/audio.tres`: feedback animation numbers and sound levels.
- `data/colony_tuning.tres` and `data/hazards/dust_storm.tres`: colonists, landers, food and habitats; the dust storm's timing, effects and look.
- `scenes/world/planet.tscn`: the playable planet. It builds everything from data and draws the sim's state. All haulers are drawn by one `DroneSwarm`, the colonists and lander by `ColonyView`, and every pad's slab and icons by `PadBatch`, to keep draw calls down.
- `scenes/ui/title.tscn`: the main scene, with three explorer profiles and settings.

## Debug overlay

Press **F3** (or the backtick key) in game, or turn on **Debug overlay** in Settings on a phone. It draws each hauler's current job as a line (amber: from the field, cyan: machine to machine, green: to the hub) and shows the frame rate, draw calls, every hauler's job, the colony and the next hazard.

## Saves

Each explorer's game is saved to `user://profile_N.json`, which is IndexedDB on web. The game saves every 10 s, after every purchase, on winning, and when the page is hidden. In the in-game menu, **Back up save** shows the save as one line of text to copy somewhere safe, and **Restore save** takes that text back. That's the fix for when Safari clears website data. Names, colours and settings are stored separately in `user://profiles.json` and `user://settings.json`.
