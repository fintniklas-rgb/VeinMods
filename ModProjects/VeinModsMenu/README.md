# VEIN Mods Menu 0.5.1

Adds MODS as the last Settings tab with a dark background and regular uppercase text.
The Mods page shows aligned MOD NAME and STATUS columns, alternating row backgrounds and details on hover.
Statuses are limited to loaded (green) and inactive (red), including disabled mods in the manager library.
Status describes loading, not whether every gameplay feature works. CustomStorage and CraftFromContainer report readiness directly; other Lua mods use the loader log, and PAK mods use mount records.
Restart VEIN after installation. Saves are not modified.

Settings discovery runs once at startup. New Settings instances are tracked through UE4SS notifications. Hidden menus are checked twice a second without global object searches. Status files are read only when MODS is selected.

Live settings: open Settings > Mods > Configure. Edit the numeric fields and press Save & Apply. CustomStorage accepts weights in kg or default; loaded inventories update immediately without a world scan. CraftFromContainer accepts a search distance of 1–1000 metres; the next crafting click uses it. Reset to Default fills the default settings; Save & Apply commits them. Failed application or saving restores the previous runtime settings.
