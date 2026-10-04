# CraftFromContainer 0.10.0 experimental

Singleplayer crafting from nearby unlocked chests and refrigerators.

Set [Storage] RadiusMetres=100 in config.ini to change the storage radius.
The mod combines solid materials and ingredient-tag requirements, moves the required units to the workbench, and lets VEIN handle crafting.
Tools must be available in the workbench. Fluids are managed by the player.

Cooking Stove support, automatic food collection and repairs are paused and are not included in this version.

The Scripts folder includes the current implementation and its planning, transfer and recipe-interface tests. Older experiments and diagnostic projects have been removed.

Performance: there are no periodic world, storage or recipe scans, even while a station menu is open. Clicking a recipe resolves that station and checks only the selected recipe's live materials.

Recipe buttons permit on-demand checks for ingredients in nearby storage. An enabled button does not guarantee that remote materials exist; VEIN still validates materials, tools, water, skills and schematics when clicked. Vanilla ingredient tooltips continue to reflect station contents.

The recipe-construction listener unregisters after the first workbench recipe menu is created. One initial UI-only setup enables its buttons; no periodic UI or material scans follow. Hidden recipe buttons are left unchanged.

[Diagnostics] VerboseLogging=false disables routine discovery and per-item log output. Errors remain logged.

Live settings: open Settings > Mods > Configure. Edit the numeric fields and press Save & Apply. CustomStorage accepts weights in kg or default; loaded inventories update immediately without a world scan. CraftFromContainer accepts a search distance of 1–1000 metres; the next crafting click uses it. Reset to Default fills the default settings; Save & Apply commits them. Failed application or saving restores the previous runtime settings.
