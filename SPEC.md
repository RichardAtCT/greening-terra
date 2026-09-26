# Greening Tessera: Product & Technical Spec (v1)

An ad-free arcade idle game about terraforming planets. You walk a small astronaut around, dig raw resources, feed machines, carry products to the Colony Hub and slowly turn a dead world green. Drones take over the hauling as you expand. Three planets make up version 1.

- **Audience:** Richard and family. Private itch.io link, no monetisation, no ads, no analytics, no network calls.
- **Engine:** Godot 4.7.2 (latest stable at project start, pinned in `tools/setup_godot.sh`), GDScript only.
- **Primary platform:** Web (HTML5), played mainly in Safari on iPhone and added to the Home Screen. Desktop browsers second. Native iOS/Android export is out of scope but must not be blocked.
- **Reference:** `reference/greening-tessera-prototype.html` is the working Three.js prototype. Open it in a browser to feel the loop. The v1 build must at least match its feel before adding anything new.
- **Decisions log:** `DECISIONS.md` records every choice made where this spec was open or ambiguous. Where they differ, this spec has been updated to match.

---

## 1. Design pillars

1. **No ads, no nagging, no timers that sell you anything.** Every design decision that looks like a mobile-game dark pattern is out.
2. **Always visible progress.** The planet itself is the progress bar: sky, ground, water, plants and colonists change as the terraform % rises.
3. **Hands-on to hands-off.** You start by carrying everything yourself. By the end of a planet, drones and colonists run the chain and you're optimising.
4. **Playable by a child.** Icons over text on pads, no fail states, no reading required to make progress. Hazards slow you down; they never wipe progress.
5. **Tunable from data.** All numbers live in data resources so balancing never needs code changes.

---

## 2. Core loop (carried over from the prototype)

| Verb | How it works |
|---|---|
| Move | Floating virtual joystick (touch anywhere, drag). WASD / arrows on desktop. Gamepad nice-to-have. |
| Dig | Walk into a resource node. One item every 0.2 s goes onto your back stack until the pack is full. Nodes shrink, empty, then respawn. |
| Carry | Items stack visibly on the astronaut's back. Stack capacity is upgradeable. |
| Feed | Stand on a machine's **IN** pad. Matching items fly off your stack into the machine's input queue. |
| Collect | Stand on a machine's **OUT** pad to pick up products. |
| Deliver | Stand on the Colony Hub **DELIVER** pad. Products become credits (₵) and terraform %. |
| Build / buy | Stand on a **BUILD** or upgrade pad. Credits drain into it in chunks until the cost is met. Partial payments persist. After a purchase the pad dims and rests for 2 s, so standing still never buys the next level by accident. |
| Automate | The Drone Bay produces haulers that run routes (node → machine, machine → machine, machine → hub). |

Rules to keep from the prototype:
- Item transfers happen one item at a time on short intervals (0.07 s), with a flying-item animation. This "drain" feel is the genre's core satisfaction; don't make transfers instant.
- Raw resources cannot be sold, only processed goods.
- Machines have an input queue cap (20 per input type) and an output cap (40). A full output pauses the machine.
- Pads highlight when the player stands on them.

---

## 3. Planets (v1 content)

Each planet adds one new resource, one or two new machines, one hazard, and a distinct look. Credits reset per planet; pack and boots upgrades and chosen bonuses carry over.

### Planet 1: Tessera-4 (rust desert)
- **Resources:** Regolith (rust rock), Ice (blue crystal).
- **Machines:** Smelter (regolith → plate), Electrolyser (ice → O₂), Greenhouse (plate + O₂ → seedpod).
- **Terraform values:** plate 0.0108%, O₂ 0.0272%, seedpod 0.048%, divided by the planet's terraform divisor (1.0 here). The prototype's values (0.15 / 0.4 / 1.6) finished the planet in about 5 minutes; these were tuned with the balance sim for a ~30-minute greedy run, including colonists, machine and hauler upgrades and dig speed speeding up the chain. Credits are unchanged: plate ₵2, O₂ ₵3, seedpod ₵9.
- **Early balance: SWAP pad.** Until the Greenhouse reaches Mk II, a SWAP pad beside it trades 2 of whichever input you have more of (plate or O₂, counting its queue and your back) for 1 of the one it's short of. The objective bar points to it while the Greenhouse sits idle for want of an input (DECISIONS #82).
- **Hazard: dust storm.** Every 4–6 minutes after 15% terraform. Lasts 30 s, with thick orange fog, driving dust and a louder wind. Player speed −30%, drones −40%. Telegraphed 10 s ahead by a HUD warning (with a bong) and a darkening sky. Frequency falls as terraform rises (the gap grows up to 1.5× by 60%) and storms stop at 60%.
- **Look:** maroon haze → pink dusk → blue sky; rust ground → ochre; lakes from 25%; lichen spreading out from the hub from ~15%; forests from 55%.
- **Target duration:** 25–35 minutes.

### Planet 2: Orrin b (frozen world)
- **New resource:** Carbonite (dark CO₂-rich rock), north-east of the hub.
- **New machines:**
  - Refinery (₵90): carbonite → polymer (₵4, 0.03%).
  - Heat Tower: polymer → heat. Heat is not an item: a burning tower (1 polymer every 6 s) keeps machines within 9 m at full speed through a cold snap, and each burn adds 0.05% terraform directly. Towers are built on three fixed plots (₵60, ₵90, ₵120), each covering two machines; the player chooses which plots to unlock first. Haulers keep them fed.
- **Hazard: cold snap.** Every 3–4.5 minutes between 8% and 85% (the gap grows to 1.3×). Warned 10 s ahead, lasts 45 s. Machines outside any burning Heat Tower's radius run at 50% speed, with frost visible on the machine. Snow falls and a pale fog rolls in.
- **Chain:** the Planet 1 chain still exists, plus polymer. Seedpods here need plate + O₂ + polymer.
- **Look:** violet night → teal → blue; frost that melts off the ground via shader, back from the hub and round burning towers, gone by 55%; meltwater lakes; tundra grass rather than forest early (grass sooner, trees later, mostly pines).
- **Economy:** pay ×1.5, terraform divisor 2.05, up to 16 haulers.
- **Target duration:** 35–45 minutes.

### Planet 3: Kessik (sulphur volcanic world)
- **New resource:** Sulphur (yellow crystal), north-west of the hub, plus three geothermal vents: fixed plots that power the buildings on them (+50% speed).
- **New machines** (all three on vents):
  - Scrubber (₵20): sulphur → filter. Each filter delivered clears 0.08% toxicity and sells for ₵1.
  - Ice Melter (₵60): ice → water.
  - Algae Pond (₵180): O₂ + water → biomass (₵12, 0.07%). **Biomass is the colonists' food here;** Kessik has no Greenhouse.
- **Hazard: meteor shower.** One every 6–8 min between 5% and 95%. Three meteors land at impact points marked 5 s ahead: one on a machine, two on open ground. A machine that's hit is "damaged" and stops until the player stands on its REPAIR pad and pays 5 plates from their back. Drones never repair. Meteors never hit the hub, a Heat Tower or the Smelter (so plates, and a repair, are always possible).
- **Two meters:** terraform % and toxicity. Toxicity starts at 100% and caps terraform % at (100 − toxicity). Deliveries still count while capped: they're banked as growth and show as the filters clear the air (DECISIONS #70).
- **Look:** mustard haze → green-grey → blue; basalt ground; steam and haze rising from the vents over dark craters; algae-green lakes.
- **Economy:** pay ×1.6, terraform divisor 2.7, up to 16 haulers.
- **Target duration:** 45–60 minutes.

### Between planets: star map
- A simple screen: three planet nodes on a line with a rocket animation between them. Completed planets show as green. It opens from the win screen (after the bonus pick) or from the menu once a planet is done; "Launch" flies the rocket to the next world. After Kessik the route starts again at Tessera-4 II.
- The player can revisit a completed planet in a free-play mode where nothing is at stake. This is a nice-to-have, **not built** (see 11).

---

## 4. New systems

### 4.1 Colonists
- Landers arrive at the hub at terraform milestones (10%, 25%, 40%, 55%, 70%, 85%). Each brings 2 colonists: 12 per planet.
- The HUD's colony panel shows when the next lander comes ("lander at 25%"), and once the tutorial is done the objective bar says it too.
- Landers come one at a time: a lander appears as terraform passes a milestone and touches down 5 s later on a landing pad east of the hub. A save from before colonists existed catches up, one lander after another.
- Colonists auto-assign to built machines, a maximum of 2 per machine (4 once upgraded; none at a Heat Tower), spread one per machine before doubling up. Each working colonist makes the machine 25% faster. They walk there visibly and stand working beside it. The rest are off duty and stroll near their habitat.
- **Food:** each colonist eats 1 seedpod (or biomass on P3) every 90 s, taken from the hub's stock. A hungry colonist stops working and shows a small pod icon but never leaves or dies. The player feeds them by delivering food as normal. The hub keeps a food store, shown in the HUD, that deliveries top up before converting the surplus to credits. Food priority: the hub keeps enough food for 5 minutes and sells the rest. A pod that goes into the store still adds its terraform %.
- **Habitats:** three plots near the hub, each housing 4. Habitat 1 is built free by the first lander; the others are BUILD pads (₵120, ₵240), each offered once the one before it stands. Colonists with no room wait by the landing pad and move in when a habitat is built.
- Colonists are simple: Kenney Mini Characters, walk-to-target in straight lines that slide round buildings (the ground is flat and every obstacle is a circle, so there's no navmesh).

### 4.2 Hazards
Common hazard framework: `HazardDef` (kind, start %, end %, interval range and growth, duration, telegraph time, effects, sounds, look), run by `HazardDirector`. Three kinds: a storm slows the player and haulers (Tessera-4), a cold snap slows machines away from heat (Orrin b), and a meteor shower damages machines until repaired (Kessik). The HUD shows an incoming-hazard banner with an icon and countdown, then how long is left. All effects are temporary slow-downs or repairs, never loss of items or credits. The random gaps are seeded from the planet and the hazard count, so saves and the balance sim repeat exactly.

### 4.3 Planet bonuses
When a planet reaches 100%, the player picks 1 of 3 random bonuses from a pool (seeded, so a reload offers the same three; never one already taken). Bonuses are permanent for the save. They're `BonusDef`s in `data/bonuses/`.

| Bonus | Effect |
|---|---|
| Swift Haulers | Drones +25% speed |
| Deep Pockets | Pack +4 |
| Head Start | Every new planet starts with the Drone Bay and 1 drone built |
| Overclock | All machines +15% speed |
| Trade Charter | Hub pays +25% credits |
| Weather Shield | Hazard durations −30% |
| Big Lander | +2 colonists per lander (habitats grow to fit) |
| Rich Veins | Resource nodes hold +50% and respawn 30% faster |

### 4.4 Upgrades (carried over, extended)
- **Outfitter:** pack +4 (10 levels), boots +12% speed (6 levels), dig speed +15% (5 levels). All three carry over between planets.
- **Drone Bay:** buy haulers (cost ×1.55 each, max 8 on P1 and 16 on P2–3). Once the whole chain is built, a HAULERS pad upgrades every hauler, alternating +1 cargo and +15% speed (6 levels, ₵250 ×1.7 each). Both are per planet.
- **Machines:** each machine gets an UPGRADE pad beside it once the whole chain is built (Heat Towers aside): +50% speed and +10 output cap per mark, up to Mk IV, and room for 2 more colonists once upgraded (P1: Smelter and Electrolyser ₵120/300/700, Greenhouse ₵200/500/1100).

### 4.5 Drone routing
Replace the prototype's fixed modulo assignment with a small dispatcher:
- Each tick, idle drones pick the highest-scoring job. The score is urgency (target input queue low, source output nearly full) minus travel distance, plus a bonus for how full a hold the job fills and for carrying goods on to another machine rather than selling them. The weights are in `GameTuning`.
- Jobs: node → machine input, machine output → machine input, machine output → hub.
- Reservations stop two drones chasing the same 3 items. They're read off the drones themselves (items still to pick up, items on the way), so they can't go stale.
- Drones with nothing to do hover by the Drone Bay and ask again every tick.
- A debug overlay (F3 or the backtick key, or "Debug overlay" in Settings) draws each drone's current job as a line, coloured by kind, with a panel of fps, draw calls, jobs, colony and hazard state.

---

## 5. Profiles & saves
- **Three save profiles** chosen on the title screen so each family member has their own game. Each has a name and a colour. Erasing a profile needs two taps. Names and colours are stored in `user://profiles.json`.
- Saves go to `user://profile_N.json`. On web this maps to IndexedDB, and each file is also kept in localStorage, which is written at once and read first. Each save has a `version` field and a migration function. If the browser keeps nothing, the title screen warns that progress won't last.
- Autosave every 10 s, on every purchase, and when the page is hidden (use `JavaScriptBridge` to listen for `visibilitychange` on web).
- Settings stored separately: music volume, SFX volume, haptics on/off where supported, and a reduced-effects toggle (fewer particles, no screen shake).
- **Export/import save:** the in-game menu has **Back up save** (shows the save as one line of text, `GT1:` + base64 JSON, to copy) and **Restore save** (paste it back). This is the backup against Safari clearing site data. On web, text entry uses the browser's `prompt()`, because Godot's text fields don't open the iPhone keyboard.

---

## 6. Controls & UI
- **HUD, top-left:** planet name, terraform % bar, stage name ("Barren regolith" … "Terraformed"), air pressure (kPa) and mean temperature (°C). These are live and derived from terraform %, as in the prototype. On Kessik, a toxicity bar, with the part of the terraform bar it holds back shaded.
- **HUD, top-right:** credits, pack count, food store (once colonists arrive), menu button.
- **Bottom:** a one-line objective with a guide arrow on the ground and a bobbing marker over the target, as in the prototype, driven by data (`TutorialStep` resources).
- **Pads:** each pad shows an icon (the item's own shape and colour) plus a short label. The icon alone should be enough to play.
- **Toasts** for milestones: "Electrolyser online", "Lander arrived: 2 colonists".
- **Safe areas:** respect iPhone notch and home-indicator insets.
- **Juice budget:** item fly arcs, a pop scale when items land on the stack, a coin tick sound on delivery, a small camera nudge on building completion, and a confetti burst when a planet reaches 100%. Keep it tasteful.

---

## 7. Technical architecture

### 7.1 Project settings
- **Renderer: Compatibility** (OpenGL ES 3 / WebGL 2). This is required for the web export. Don't use Forward+ or Mobile features.
- **Web export:** turn thread support off (single-threaded build) so hosting needs no special cross-origin headers. Enable VRAM texture compression for mobile. Export as a PWA if supported, so the Home Screen icon opens full-screen.
- **Performance budget (iPhone 12 or newer, Safari):** 60 fps target and 30 fps floor; under 150 draw calls; total download under 40 MB. Use MultiMesh for vegetation, rocks and item stacks on pads.

### 7.2 Folder layout
```
res://
  data/            # .tres resources; data/game.tres links everything
    items/ machines/ planets/ upgrades/ hazards/ bonuses/   # plus game_tuning.tres, terraform.tres, *_tuning.tres
  scenes/
    world/         # planet root, terrain, terraform controller, planet effects, label layer
    actors/        # player, drone swarm, colony (colonists and lander)
    buildings/     # machine (generic), hub, drone bay, outfitter, habitat, heat tower
    pads/          # pad view, pad batch (slabs and icons)
    ui/            # hud (with the bonus picker), title, settings, debug overlay, star map
  scripts/
    autoload/      # GameState, SaveManager, EventBus, DisplayScale, Audio
    data/          # Resource class definitions (ItemDef, PlanetDef, ...)
    systems/       # pure rules: GameSim, Economy, DroneBrain, Tutorial, BotPlayer, WorldState, ...
  shaders/         # pad, dust, ground_terraform (with frost), water, ground_ring, steam, frost_overlay
  assets/          # fonts, models (source GLBs), meshes (baked), materials, audio (with LICENSES.md)
  addons/gut/      # GUT 9.7.1 test framework (excluded from export)
tests/             # GUT tests: unit/ and smoke/
tools/
  setup_godot.sh export_web.sh test.sh deploy.sh
  balance_sim.gd
  dev/             # screenshot.gd, bake_models.gd
reference/greening-tessera-prototype.html
```
Scene-specific scripts sit next to their scene (for example `scenes/actors/player.gd`). Everything in `scripts/systems/` is free of scene access, so tests and the balance sim can run it headless.

### 7.3 Data model (custom Resources)
- `GameDefs` (`data/game.tres`): the root. Holds the items, planets, upgrades (pack, boots, hauler count, hauler upgrades, dig), bonuses, `GameTuning`, `TerraformDef`, `PlayerTuning`, `JuiceTuning` and `ColonyTuning`.
- `ItemDef`: id, display name, short pad label, colour, emissive, shape, stack height, sell value (0 = raw, can't be sold), terraform value, food value, detox value (toxicity cleared on delivery).
- `RecipeDef`: inputs {item: count}, output item (none for a Heat Tower), time, and terraform per cycle when there's no output.
- `MachineDef`: id, name, recipe, build cost, starts built, position, scene, footprint, collision radius, label height, pad offsets (IN, OUT, BUILD, UPGRADE, REPAIR, SWAP), IN pad colour and label, queue cap (20), output cap (40), upgrade costs (one per mark), speed and output cap per mark, heat radius (Heat Towers), whether colonists work it, and the early SWAP pad (ratio, the level it goes at, the objective hint).
- `ResourceNodeDef`: item, max stock, positions, drone idle point, look (colour and a baked mesh it tints).
- `PlanetDef`: name, seed, palette (sky start/mid/end, ground start/end, moss, water deep/shallow), pay multiplier, terraform divisor, hub/depot/bay/outfitter layout, machines, resource nodes, lakes, clear zones, habitat plots and costs, landing pad, lander milestones and colonists per lander, hazard, surface (vents and their boost, starting toxicity, frost and its colour, steam colour), vegetation (when grass, flowers and trees come, their hue and saturation, share of pines), tutorial, win text, balance target minutes and `balance_enforced`.
- `UpgradeDef`: cost = round((base + step × level) × growth^level), max level, amount per level. Used for pack, boots and haulers.
- `TutorialDef` → `TutorialStep` (text, marker target, `TutorialCondition`s that complete it, "keep saving" text for a pay pad).
- `GameTuning`: transfer, dig and pay intervals, radii, respawn time, drone speed, capacity and waits, what each hauler upgrade adds, dispatcher weights, fly time, autosave interval.
- `ColonyTuning` (`data/colony_tuning.tres`): lander descent and stay, machine boost, colonists per machine, walking speed and work spots, meal interval, food reserve, habitat capacity.
- `HazardDef` (`data/hazards/`: dust storm, cold snap, meteor shower): see 4.2, plus the look (sky darkening, fog, dust or snow colour and fall, frost).
- `TerraformDef`: stage names and limits, pressure and temperature formulas, and how % maps to sky, fog, light, lakes, dust, the ground-moss front, moss patches, grass, flowers and trees.
- `PlayerTuning`, `CameraTuning` (including the build-complete nudge), `JoystickTuning`.
- `JuiceTuning` (`data/juice.tres`): stack pop, pick-up pitch climb, building pop and dust puff, pad icon size and motion, colonist waddle and work nod, hungry icon, lander drop and lift-off, confetti.
- `AudioDef` (`data/audio.tres`) → `SoundDef`s (variations, volume, pitch jitter, minimum repeat interval), plus the wind (and its storm boost) and birdsong levels.
- `BonusDef` (`data/bonuses/`): id, name, one-line description, kind, amount (and a second amount for Rich Veins), card colour.

Resource scripts declare the prototype's values as defaults. Godot leaves unchanged values out of `.tres` files, so edit them in the Inspector.

Planet layouts can be authored as scenes with marker nodes (plots, nodes, lakes) that the `PlanetDef` references, which is easier to edit visually in Godot.

### 7.4 Key systems
- **GameState** (autoload): holds the loaded `GameDefs` and the running `GameSim` for the active profile. Forwards the sim's signals through EventBus.
- **GameSim** (`scripts/systems/game_sim.gd`): all the rules for one planet: mining, pads, paying, machines, drones, tutorial, win. Its state is a serialisable `WorldState` (credits, terraform %, stack, queues, built flags, paid amounts, drones, upgrades, stats, nodes). The planet scene feeds it the player's position each frame and draws what it reports.
- **Economy:** pure functions for costs, payouts, feeding, machine cycles and pay chunks, so the balance sim and tests can call them without scenes.
- **TerraformController:** maps terraform % to shader uniforms (ground tint, frost amount, water level, haze density and colour) and to vegetation MultiMesh instance thresholds. The spread pattern radiates out from the hub, with a threshold per instance, as in the prototype.
- **Dispatcher:** drone job scoring and reservations (see 4.5). `DroneBrain` flies each drone's job.
- **Colony:** landers, habitats, colonist work assignment and walking, food.
- **HazardDirector:** schedules, telegraphs and applies hazard effects; `intensity()` drives the look.

### 7.5 Balance simulator (important)
`tools/balance_sim.gd` runs headless (`godot --headless --script tools/balance_sim.gd`). It simulates each planet with:
- a scripted player (`BotPlayer`) who follows a greedy strategy: always do the most valuable affordable action, with walk time derived from distances;
- drones and colonists running the real Economy and Dispatcher code;
- accelerated time.

It prints a table of time to each milestone (first build, drone bay, the food machine, 25/50/75/100%) and fails if any enforced planet falls outside its target duration (`PlanetDef.target_minutes`) by more than 20%. It also reports upgrades bought, bonuses, colonists housed and waiting, habitats, meals stored as food, time spent hungry, hazards, repairs and (Kessik) when the air cleared. Each planet starts with the kit and bonuses the bot ended the last one with. Run it after any balance change. `--scale-tf` and `--scale-machine-time` try changes in memory without editing data; `--no-colony`, `--no-hazard` and `--no-bonus` show what each system does to the pace; `--bonus=` starts with given bonuses; `--log` prints every purchase and toast.

### 7.6 Testing
Tests use **GUT 9.7.1** (`tools/test.sh`). Engine errors during a test count as failures.
- Unit tests for Economy (costs, payouts, recipe consumption, food), SaveManager (round-trip and migration), Dispatcher (no double-reservation, no idle drone while a job exists), Colony (landers, habitats, work, food), the dust storm, and M5 (heat towers and cold snaps, toxicity, vents, meteors and repairs, every bonus, the upgrades, the version 3 save, the bot's repairs).
- Smoke tests that load the planet scene headless and run it (every planet with its hazard), the win screen's bonus pick, the star map, and a draw-call count of every planet's worst case.

### 7.7 Build & deploy
- `export_presets.cfg` committed with a "Web" preset.
- A script (`tools/deploy.sh`) that exports headless and pushes to itch.io with **butler** (`butler push build/web richardat/greening-tessera:web`). The itch.io page is set to private or restricted with a download key.
- A GitHub Action (`.github/workflows/ci.yml`) runs the tests and the balance sim, and exports the web build, on every push to `main` and on every PR. The build is uploaded as an artifact.

---

## 8. Art & audio
- **Style:** low-poly, flat-shaded, with a limited palette per planet. Everything lit by one sun plus hemisphere light, and fog that changes with terraform %.
- **Asset sources (CC0; check each pack's licence and record it in `assets/LICENSES.md`):**
  - Kenney: Space Kit, Mini Characters, Nature Kit, Interface/UI audio, Impact sounds.
  - Quaternius: Ultimate Space Kit, Stylized Nature MegaKit, Ultimate Modular Sci-Fi.
- **Shaders:** terraform ground (tints the base colour, blends in a moss texture by a mask that grows from the hub, and P2's frost), stylised water, frost overlay on machines (P2), steam and haze from vents (P3; a screen-distortion shimmer would cost a screen copy per frame), glowing ground rings (heat radius, meteor targets), pads with a text atlas.
- **Audio:** ambient wind loop per planet whose pitch and volume fall as the air thickens; later, soft birdsong on P1 above 70%. Short UI sounds for pick-up, drop, coin, build complete and lander.

---

## 9. Milestones & acceptance criteria

| # | Milestone | Done when | Status |
|---|---|---|---|
| M0 | Pipeline | Empty Godot project exports to web, deploys to itch.io with butler, and opens full-screen from the iPhone Home Screen with touch input working. **Do this first.** | Built and merged. itch.io push and iPhone check still to do by hand. |
| M1 | Prototype parity | Planet 1 with the full prototype loop: dig, stack, 3 machines, hub, pay pads, drone bay, outfitter, basic drones, terraform visuals, tutorial steps. Holds 60 fps on iPhone. | Built. 60 fps on iPhone not yet measured. |
| M2 | Data + saves + sim | All numbers in data resources; 3 profiles; autosave and export/import; balance sim reports P1 in 25–35 min. | Built. Balance sim: P1 in 29 min. |
| M3 | Planet 1 art pass | Real models, terraform shaders, audio, juice. Looks like a finished game on one planet. | Built. 60 fps on iPhone not yet measured. |
| M4 | Colonists + hazards + dispatcher | Landers, colonists and food; dust storm; dispatcher replaces modulo routing; debug overlay. | Built. Balance sim: P1 in 30 min. Worst-case late game 131 drawables before culling. New sounds not yet heard. |
| M5 | Planets 2 & 3 + star map + bonuses | Full 3-planet campaign playable end to end; bonus picker; balance sim passes for all three. | Built. Balance sim: 30, 41 and 51 min. Worst-case drawables 67 / 85 / 85. New sounds not yet heard. |
| M6 | Polish | Settings, reduced-effects mode, onboarding tuned so a young child can get to the first build unaided, performance pass, and a final family playtest. | Settings panel (volumes, vibration, fewer effects) already exists. |

---

## 10. Out of scope for v1
Ads, in-app purchases, analytics, accounts, cloud saves, leaderboards, multiplayer, offline earnings, procedural planets, native store builds.

## 11. Open questions (decide during build)
- Late-game credit sink: machine, hauler and dig-speed upgrades keep the greedy bot buying until late; it ends with ₵0.8k, ₵6.7k and ₵7.7k unspent (from ₵15–32k). Something to spend on in the last third of Planets 2 and 3 (cosmetics for the colony?) is still open.
- Should drones need recharging at the bay, as a light extra loop?
- On P3, toxicity caps terraform but banks what's delivered (DECISIONS #70). Does it feel good to see 0% while delivering, until the first filters land?
- Free-play revisit of completed planets: keep or drop?
- Idle colonists: an upgraded machine takes four colonists, so all twelve can work once Planet 1's machines are upgraded. Heat Towers take none.
- Hazard frequency for a child: the greedy bot sees one storm, five cold snaps and six meteor showers. A slower player sees more (they're timed in minutes, not %). Check that it doesn't feel nagging, especially repairs.
