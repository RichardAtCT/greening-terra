# Decisions

Choices made where the spec was open or ambiguous. The rule is: pick what's closest to the prototype's behaviour and write it down here.

## M0: Pipeline

1. **Engine pinned to Godot 4.7.2** (latest stable at project start). `tools/setup_godot.sh` downloads exactly this version; bump `GODOT_VERSION` there and `config/features` in `project.godot` together.
2. **GUT rather than gdUnit4.** GUT 9.7.1 targets Godot 4.7 and runs headless with a single command (`-s addons/gut/gut_cmdln.gd`) and a proper exit code, with no extra runner or flags. It's vendored in `addons/gut/` and excluded from the web export.
3. **Where scripts live.** Section 7.2 doesn't say where Resource class definitions go, so they're in `scripts/data/` (the `.tres` values stay in `data/`). Scripts that belong to one scene sit next to it (`scenes/actors/player.gd`). Pure logic that tests and the balance sim call goes in `scripts/systems/` (e.g. `movement.gd`).
4. **UI units are CSS pixels.** Stretch mode is `disabled`, and the `DisplayScale` autoload sets `content_scale_factor` to the device pixel ratio. That makes the joystick exactly the prototype's size (112 px base, 46 px knob, 50 px travel) on any phone, while 3D still renders at full resolution.
5. **Joystick input.** Same as the prototype: the first touch anywhere spawns it, and only that finger drives it. Mouse drag also works on desktop (via `emulate_touch_from_mouse`), like the prototype's pointer events. Joystick and keyboard vectors are added together, then capped at full speed.
6. **Player is a `CharacterBody3D`** (floating motion mode). The prototype does its own circle push-out against buildings; using Godot's body now means building collisions in M1 need no extra code. The world-radius clamp (40 m) is kept.
7. **Physics interpolation is on.** The player moves in the physics step; the camera eases in `_process`, reading the interpolated transform, so it stays smooth on 120 Hz screens.
8. **PWA display is `standalone`.** iOS Safari doesn't support `fullscreen` in the manifest; standalone is what Home Screen apps get there. Status bar style is `black` (not `black-translucent`) until the HUD handles safe-area insets, so nothing sits under the notch.
9. **Download size.** The stock single-threaded web template's `index.wasm` is 39.5 MB raw, about 10 MB gzipped. The 40 MB budget (section 7.1) is treated as transfer size. If itch.io doesn't compress it, a custom template with unused modules stripped is an M6 performance task.
10. **Environment values in the test scene.** Sky colour, fog (near 14, far 48), sun and ground colour are set in `test_world.tscn` for now. They move into the `PlanetDef` palette in M1, when terraform % starts driving them.
