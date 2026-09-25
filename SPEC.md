# Greening Tessera: Product & Technical Spec (v1)

An ad-free arcade idle game about terraforming planets. You walk a small astronaut around, dig raw resources, feed machines, carry products to the Colony Hub and slowly turn a dead world green. Drones take over the hauling as you expand. Three planets make up version 1.

- **Audience:** Richard and family. Private itch.io link, no monetisation, no ads, no analytics, no network calls.
- **Engine:** Godot 4 (latest stable 4.x at project start, pinned), GDScript only.
- **Primary platform:** Web (HTML5), played mainly in Safari on iPhone and added to the Home Screen. Desktop browsers second. Native iOS/Android export is out of scope but must not be blocked.
- **Reference:** `reference/greening-tessera-prototype.html` is the working Three.js prototype. Open it in a browser to feel the loop. The v1 build must at least match its feel before adding anything new.

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
| Build / buy | Stand on a **BUILD** or upgrade pad. Credits drain into it in chunks until the cost is met. Partial payments persist. |
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
- **Terraform values:** plate 0.15%, O₂ 0.4%, seedpod 1.6% (prototype values, to be tuned by the balance sim).
- **Hazard: dust storm.** Every 4–6 minutes after 15% terraform. Lasts 30 s, with thick orange fog and a wind sound. Player speed −30%, drones −40%. Telegraphed 10 s ahead by a HUD warning and darkening sky. Frequency falls as terraform rises and storms stop at 60%.
- **Look:** maroon haze → pink dusk → blue sky; rust ground → ochre; lakes from 25%; lichen spreading out from the hub from ~15%; forests from 55%.
- **Target duration:** 25–35 minutes.

### Planet 2: Orrin b (frozen world)
- **New resource:** Carbonite (dark CO₂-rich rock).
- **New machines:**
  - Refinery: carbonite → polymer.
  - Heat Tower: polymer → heat. Heat is not an item; it powers a warm radius around the tower.
- **Hazard: cold snap.** Machines outside any Heat Tower radius run at 50% speed during a snap, with frost visible on the machine. Snaps last 45 s. This introduces placement: Heat Towers are built on fixed plots, and the player chooses which plots to unlock first.
- **Chain:** the Planet 1 chain still exists (the greenhouse needs plates + O₂) plus polymer. Seedpods here need plate + O₂ + polymer. Tune so the player feels the upgrade.
- **Look:** violet night → teal → blue; frost sheen that melts off the ground via shader; meltwater lakes; tundra grass rather than forest early.
- **Target duration:** 35–45 minutes.

### Planet 3: Kessik (sulphur volcanic world)
- **New resource:** Sulphur (yellow crystal), plus geothermal vents (fixed plots that power buildings built on them).
- **New machines:**
  - Scrubber: sulphur → filter; delivering filters clears toxins.
  - Algae Pond: O₂ + water → biomass. Water comes from an Ice Melter: ice → water.
- **Hazard: meteor shower.** A few meteors land at marked impact points (shown 5 s ahead). A machine that's hit is "damaged" and stops until the player stands on it and pays 5 plates to repair it. Drones never repair. Keep it rare (one shower every 6–8 min) and never damage the hub.
- **Two meters:** terraform % and toxicity. Toxicity starts at 100% and caps terraform % at (100 − toxicity). Scrubbers are the way through.
- **Look:** mustard haze → green-grey → blue; basalt ground; steam from vents; algae-green lakes.
- **Target duration:** 45–60 minutes.

### Between planets: star map
- A simple screen: three planet nodes on a line with a rocket animation between them. Completed planets show as green.
- The player can revisit a completed planet in a free-play mode where nothing is at stake. This is a nice-to-have.

---

## 4. New systems

### 4.1 Colonists
- Landers arrive at the hub at terraform milestones (10%, 25%, 40%, 55%, 70%, 85%). Each brings 2 colonists: 12 per planet.
- Colonists auto-assign to built machines, a maximum of 2 per machine. Each assigned colonist makes the machine 25% faster. They walk there visibly and stand working beside it.
- **Food:** each colonist eats 1 seedpod (or biomass on P3) every 90 s, taken from the hub's stock. A hungry colonist idles and shows a small icon but never leaves or dies. The player feeds them by delivering food as normal. The hub keeps a food store, shown in the HUD, that deliveries top up before converting the surplus to credits. Food priority: the hub keeps enough food for 5 minutes and sells the rest.
- **Habitats:** optional build pads near the hub. Each raises the colonist cap by 4. Build Habitat 1 by default when the first lander arrives.
- Colonists are simple: capsule characters, walk-to-target, no pathfinding beyond Godot NavigationAgent3D on a flat baked mesh.

### 4.2 Hazards
Common hazard framework: `HazardDef` (start %, end %, interval range, duration, telegraph time, effects). The HUD shows an incoming-hazard banner with an icon and countdown. All effects are temporary slow-downs or repairs, never loss of items or credits.

### 4.3 Planet bonuses
When a planet reaches 100%, the player picks 1 of 3 random bonuses from a pool. Bonuses are permanent for the save.

| Bonus | Effect |
|---|---|
| Swift Haulers | Drones +25% speed |
| Deep Pockets | Pack +4 |
| Head Start | Next planet starts with the Drone Bay and 1 drone built |
| Overclock | All machines +15% speed |
| Trade Charter | Hub pays +25% credits |
| Weather Shield | Hazard durations −30% |
| Big Lander | +2 colonists per lander |
| Rich Veins | Resource nodes hold +50% and respawn 30% faster |

### 4.4 Upgrades (carried over, extended)
- **Outfitter:** pack +4 (10 levels), boots +12% speed (6 levels), dig speed +15% (5 levels).
- **Drone Bay:** buy haulers (cost ×1.55 each, max 12 on P1 and 16 on P2–3); hauler capacity +1 (3 levels).
- **Machines:** each machine gets a level-2 upgrade pad (+50% speed, +10 output cap).

### 4.5 Drone routing
Replace the prototype's fixed modulo assignment with a small dispatcher:
- Each tick, idle drones pick the highest-scoring job. The score is urgency (target input queue low, source output nearly full) minus travel distance.
- Jobs: node → machine input, machine output → machine input, machine output → hub.
- Reservations stop two drones chasing the same 3 items.
- A debug overlay (toggle with a key) draws each drone's current job as a line.

---

## 5. Profiles & saves
- **Three save profiles** chosen on the title screen so each family member has their own game. Each has a name and a colour.
- Saves go to `user://profile_N.json`. On web this maps to IndexedDB. Each save has a `version` field and a migration function.
- Autosave every 10 s, on every purchase, and when the page is hidden (use `JavaScriptBridge` to listen for `visibilitychange` on web).
- Settings stored separately: music volume, SFX volume, haptics on/off where supported, and a reduced-effects toggle (fewer particles, no screen shake).
- **Export/import save:** a settings button copies the save as text, and pasting it back restores it. This is the backup against Safari clearing site data.

---

## 6. Controls & UI
- **HUD, top-left:** planet name, terraform % bar, stage name ("Barren regolith" … "Terraformed"), air pressure (kPa) and mean temperature (°C). These are live and derived from terraform %, as in the prototype.
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
  data/            # .tres resources: items, recipes, machines, planets, upgrades, bonuses, hazards, tutorial
  scenes/
    world/         # planet root, terrain, terraform controller
    actors/        # player, drone, colonist
    buildings/     # machine (generic), hub, drone bay, outfitter, habitat, heat tower
    pads/          # in, out, pay, deliver
    ui/            # hud, title, star map, bonus picker, settings
  scripts/
    autoload/      # GameState, SaveManager, EventBus, Balance, Audio
    systems/       # economy, dispatcher, hazards, colonists, tutorial
  shaders/         # ground_terraform.gdshader, water.gdshader, sky_haze.gdshader, frost.gdshader
  assets/          # models, textures, audio (with LICENSES.md)
tests/             # gdUnit4 or GUT tests
tools/balance_sim.gd
reference/greening-tessera-prototype.html
```

### 7.3 Data model (custom Resources)
- `ItemDef`: id, display name, icon mesh, colour, stack height, sell value, terraform value, food value.
- `RecipeDef`: inputs {item: count}, output item, time.
- `MachineDef`: id, name, recipe, build cost, level-2 cost, scene, footprint, pad offsets.
- `PlanetDef`: name, palette (sky stops, ground start/end, fog), resource node layout, machine plots, lake positions, vegetation set, hazard, milestones, tutorial steps, terraform divisor.
- `UpgradeDef`, `BonusDef`, `HazardDef`, `TutorialStep`.

Planet layouts can be authored as scenes with marker nodes (plots, nodes, lakes) that the `PlanetDef` references, which is easier to edit visually in Godot.

### 7.4 Key systems
- **GameState** (autoload): the single source of truth for credits, terraform %, toxicity, stack, queues, built flags, paid amounts, drones, colonists, upgrades and bonuses. Emits signals through EventBus. Everything else reads from it.
- **Economy:** pure functions for costs, payouts and machine throughput, so the balance sim and tests can call them without scenes.
- **TerraformController:** maps terraform % to shader uniforms (ground tint, frost amount, water level, haze density and colour) and to vegetation MultiMesh instance thresholds. The spread pattern radiates out from the hub, with a threshold per instance, as in the prototype.
- **Dispatcher:** drone job scoring (see 4.5).
- **HazardDirector:** schedules, telegraphs and applies hazard effects.

### 7.5 Balance simulator (important)
`tools/balance_sim.gd` runs headless (`godot --headless --script tools/balance_sim.gd`). It simulates each planet with:
- a scripted player who follows a greedy strategy: always do the most valuable affordable action, with walk time derived from distances;
- drones and colonists running the real Economy and Dispatcher code;
- accelerated time.

It prints a table of time to each milestone (first build, drone bay, greenhouse, 25/50/75/100%) and fails if any planet falls outside its target duration by more than 20%. Run it after any balance change.

### 7.6 Testing
- Unit tests for Economy (costs, payouts, recipe consumption), SaveManager (round-trip and migration), and Dispatcher (no double-reservation, no idle drone while a job exists).
- A smoke test that loads each planet scene headless for 60 simulated seconds without errors.

### 7.7 Build & deploy
- `export_presets.cfg` committed with a "Web" preset.
- A script (`tools/deploy.sh`) that exports headless and pushes to itch.io with **butler** (`butler push build/web richard/greening-tessera:web`). The itch.io page is set to private or restricted with a download key.
- Optional: a GitHub Action that runs tests, runs the balance sim and exports the web build on every push to `main`.

---

## 8. Art & audio
- **Style:** low-poly, flat-shaded, with a limited palette per planet. Everything lit by one sun plus hemisphere light, and fog that changes with terraform %.
- **Asset sources (CC0; check each pack's licence and record it in `assets/LICENSES.md`):**
  - Kenney: Space Kit, Mini Characters, Nature Kit, Interface/UI audio, Impact sounds.
  - Quaternius: Ultimate Space Kit, Stylized Nature MegaKit, Ultimate Modular Sci-Fi.
- **Shaders to write:** terraform ground (tints the base colour, blends in a moss texture by a mask that grows from the hub), stylised water, frost overlay (P2), heat shimmer (P3 vents).
- **Audio:** ambient wind loop per planet whose pitch and volume fall as the air thickens; later, soft birdsong on P1 above 70%. Short UI sounds for pick-up, drop, coin, build complete and lander.

---

## 9. Milestones & acceptance criteria

| # | Milestone | Done when |
|---|---|---|
| M0 | Pipeline | Empty Godot project exports to web, deploys to itch.io with butler, and opens full-screen from the iPhone Home Screen with touch input working. **Do this first.** |
| M1 | Prototype parity | Planet 1 with the full prototype loop: dig, stack, 3 machines, hub, pay pads, drone bay, outfitter, basic drones, terraform visuals, tutorial steps. Holds 60 fps on iPhone. |
| M2 | Data + saves + sim | All numbers in data resources; 3 profiles; autosave and export/import; balance sim reports P1 in 25–35 min. |
| M3 | Planet 1 art pass | Real models, terraform shaders, audio, juice. Looks like a finished game on one planet. |
| M4 | Colonists + hazards + dispatcher | Landers, colonists and food; dust storm; dispatcher replaces modulo routing; debug overlay. |
| M5 | Planets 2 & 3 + star map + bonuses | Full 3-planet campaign playable end to end; bonus picker; balance sim passes for all three. |
| M6 | Polish | Settings, reduced-effects mode, onboarding tuned so a young child can get to the first build unaided, performance pass, and a final family playtest. |

---

## 10. Out of scope for v1
Ads, in-app purchases, analytics, accounts, cloud saves, leaderboards, multiplayer, offline earnings, procedural planets, native store builds.

## 11. Open questions (decide during build)
- Should drones need recharging at the bay, as a light extra loop?
- On P3, does toxicity capping terraform feel good, or should toxicity just slow terraform gains?
- Free-play revisit of completed planets: keep or drop?
