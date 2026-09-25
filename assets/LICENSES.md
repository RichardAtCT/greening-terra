# Asset licences

Record every third-party asset pack here: name, author, source URL, licence, and which files came from it.

| Pack | Author | Source | Licence | Files |
|---|---|---|---|---|
| Space Kit | Kenney (kenney.nl) | https://kenney.nl/assets/space-kit | CC0 1.0 | `assets/models/space/*.glb`: astronautA, hangar_roundB, hangar_roundGlass, hangar_smallA, machine_generatorLarge, machine_barrelLarge, machine_barrel, chimney_detailed, platform_large, satelliteDish_large, pipe_straight, craft_cargoA, rock_largeA, rock_largeB, rock_crystalsLargeA, meteor_half, crater, rocket_baseA, rocket_fuelA, rocket_topA, hangar_smallB |
| Mini Characters | Kenney (kenney.nl) | https://kenney.nl/assets/mini-characters | CC0 1.0 | `assets/models/characters/`: character-female-b, character-female-e, character-male-a, character-male-b (GLB) and `Textures/colormap.png` |
| Nature Kit | Kenney (kenney.nl) | https://kenney.nl/assets/nature-kit | CC0 1.0 | `assets/models/nature/*.glb`: tree_pineRoundA, tree_default, tree_cone, grass_large, grass_leafs, plant_bushSmall, flower_yellowA, flower_redA, flower_purpleA, lily_large |
| Interface Sounds | Kenney (kenney.nl) | https://kenney.nl/assets/interface-sounds | CC0 1.0 | `assets/audio/sfx/`: pluck_001, pluck_002, drop_002, drop_003, tick_001, tick_002, confirmation_002, confirmation_004, maximize_006, click_002, bong_001, glass_002 |
| Impact Sounds | Kenney (kenney.nl) | https://kenney.nl/assets/impact-sounds | CC0 1.0 | `assets/audio/sfx/`: impactMining_000, impactMining_001, impactMining_002 |
| Sci-fi Sounds | Kenney (kenney.nl) | https://kenney.nl/assets/sci-fi-sounds | CC0 1.0 | `assets/audio/sfx/`: spaceEngineLow_001, impactMetal_002 |

The GLBs are the sources for `tools/dev/bake_models.gd`, which merges them into `assets/meshes/*.res` (the files the game loads). They're excluded from the web export. The wind loop and birdsong are generated in code (`ProceduralAudio`), so they have no asset.

## Code add-ons

| Add-on | Version | Source | Licence |
|---|---|---|---|
| GUT (Godot Unit Test) | 9.7.1 | https://github.com/bitwes/Gut | MIT (`addons/gut/LICENSE.md`) |
