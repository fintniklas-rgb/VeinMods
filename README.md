# VEIN Mods

VEIN Mod Manager and three optional UE4SS mods for VEIN. The gameplay mods are experimental and developed for singleplayer.

## Download and install

Download this repository using **Code > Download ZIP**, then extract it. Launch **VeinModManager.exe** and select your VEIN installation folder, usually `...\Steam\steamapps\common\Vein`.

Close VEIN before installation. Use **Install UE4SS**, import an individual mod folder from **ModProjects**, and enable it. Restart VEIN after changing active mods. The mods are independent downloads/components; install only the ones you want.

## VeinModManager

A standalone Windows mod manager with automatic Lua, PAK and LogicMod import detection, activation, removal and UE4SS installation. Edited INI settings are retained when disabling and re-enabling Lua mods. UE4SS console/debug windows are disabled during installation. Requires .NET Framework 4.8.

The installer downloads a pinned VEIN runtime from https://github.com/Alustrial/UE4SS-Vein and a proxy DLL package from https://github.com/UE4SS-RE/RE-UE4SS. It requires a game log identifying Unreal Engine 5.6.1 and verifies the proxy archive checksum. UE4SS is not bundled in this repository.

## CraftFromContainer

Craft at supported workbenches using solid materials from nearby unlocked chests and refrigerators. Materials are combined across containers and transferred into the workbench when you click a recipe. The default radius is 100 metres and can be configured between 1 and 1000 metres. There are no periodic world or recipe scans.

Tools must be in the workbench; fluids are supplied by the player. Cooking, automatic food collection and repair integration are not included. Requires UE4SS.

## CustomStorage

Configure capacity in kilograms for Small Crate, Large Crate, Wood Log Storage, Wooden Plank Storage, Scrap Storage, Standard Workbench, Advanced Workbench, Fabrication Workbench and the player inventory.

Set `Weight=default`, an exact value such as `Weight=300`, or a multiplier such as `Weight=3x`. Values start at 1 kg. The distributed config preserves vanilla limits; baseline values are recorded when inventories are recognized. Lowering capacity does not delete existing items. Requires UE4SS.

## VeinModsMenu

Adds a **MODS** tab to Settings with aligned mod names and **loaded** (green) or **inactive** (red) statuses. Loading status is not a verification of every gameplay feature.

Optional live configuration panels for CustomStorage and CraftFromContainer let you edit values and use **Save & Apply** without restarting. **Reset to Default** fills default values; **Save & Apply** commits them. Requires UE4SS.

See each mod's README for details and limitations.

## Build identification

`SHA256SUMS.txt` records the checksums of the published files. The manager is unsigned. Antivirus reports should be reviewed using the exact file hash; contact the detecting vendor if you suspect a false positive.

## Credits

UE4SS-Vein by Alustrial and RE-UE4SS by the UE4SS contributors. This is a community project, not an official VEIN release.
