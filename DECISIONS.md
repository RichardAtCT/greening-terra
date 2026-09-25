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

## M1: Prototype parity

11. **Sim and view are separate.** `GameSim` (`scripts/systems/`) owns every rule and has no scene access; `scenes/world/planet.gd` only feeds it the player's position and draws its state. The balance sim and tests drive the same `GameSim`.
12. **Drone routing is still the prototype's**: each hauler takes route `index % routes`. SPEC 4.5's dispatcher replaces it in M4, as planned.
13. **Planets 2 and 3 already exist, but only as re-skins**: the prototype's palettes and its pay/terraform multipliers, on Planet 1's layout. That keeps the prototype's "launch to the next world" flow working until M5 adds the real content. As in the prototype, after the third planet the list repeats with a numeral ("Tessera-4 II").
14. **Planet data files.** Machines, nodes and the tutorial are separate `.tres` files shared by all three planets, so a tweak lands everywhere at once.
15. **Pads show text, like the prototype.** SPEC 6's item icons on pads are an art task for M3.
16. **World labels always draw on top** (no depth test), and the panel behind them is a rounded-rectangle shader. The prototype's canvas sprites could be hidden behind buildings; these can't, which reads better on a small screen.
17. **Frame time is capped at 0.05 s** for the sim, as in the prototype, so a stall never skips a whole transfer chain.
18. **Recipe input order** comes from Godot's dictionary sort, so the greenhouse label reads "O₂ · Plate" rather than the prototype's "plate · O₂". This is cosmetic.
19. **Draw calls.** Each resource node, drone and the greenhouse seedlings are merged into single meshes, and item stacks use one MultiMesh per item type. A late-game Planet 1 has about 150 drawables before frustum culling. The real iPhone frame rate still needs checking on a device.
20. **Seedpods have a food value of 1** already, so M4's colonists have data to read.
