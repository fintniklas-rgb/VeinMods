# CustomStorage 0.2.0 experimental

Singleplayer weight limits for Small Crate, Large Crate, Wood Log Storage, Wooden Plank Storage, Scrap Storage, Standard Workbench, Advanced Workbench, Fabrication Workbench and the local player's main inventory.

Edit the installed mod's config.ini while VEIN is closed, then restart the game. All configured weights are kilograms. If the game displays pounds, 1 kg is approximately 2.20462 lb.

Each section has an informational BaseWeight and a Weight setting. Weight=default keeps the game limit; Weight=1 sets a 1 kg limit; Weight=3x triples the unmodified limit. Larger finite values are supported. BaseWeight=auto is filled when the corresponding inventory is first recognized. The player's baseline depends on their character and is captured before changing their carry limit.

The player setting compensates for character bonuses when the inventory is initialized, so the requested weight represents the final capacity at that point. Later changes to character bonuses can affect it until the next world load.

Existing items are never removed when lowering capacity. An overweight inventory must be emptied below its new limit before adding more items. Item filters, recipe tools and fluids remain controlled by the game.

Only the listed buildable container classes are changed. Similarly named world loot containers are excluded. Renaming a container does not change its matching. New and streamed inventories are updated in small batches after construction; there is no periodic world scan. The log records applied limits or verification errors. Failed changes restore their previous properties.

Live settings: open Settings > Mods > Configure. Edit the numeric fields and press Save & Apply. CustomStorage accepts weights in kg or default; loaded inventories update immediately without a world scan. CraftFromContainer accepts a search distance of 1–1000 metres; the next crafting click uses it. Reset to Default fills the default settings; Save & Apply commits them. Failed application or saving restores the previous runtime settings.
