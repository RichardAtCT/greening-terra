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
tools/deploy.sh               # export, then butler push build/web richard/greening-tessera:web
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

See `SPEC.md` section 7.2. Every tunable number lives in a `.tres` file under `data/`, and scripts only read those resources.
