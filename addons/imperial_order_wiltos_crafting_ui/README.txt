IMPERIAL ORDER - WILTOS LIGHTSABER CRAFTING UI v1.0.0
======================================================

WHAT THIS DOES
- Replaces the stock wiltOS saber crafting presentation with a Imperial Order/Imperial styled VGUI interface.
- Keeps the existing wiltOS crafting backend and net messages.
- Supports:
  * Primary and off-hand saber selection
  * Hilt selection
  * Crystal selection
  * Igniter selection
  * Idle regulator selection
  * Power vortex selection
  * Proficiency mod slots
  * Blueprint forging with live material requirements
  * Salvaging/smelting eligible items
  * Final saber fabrication
- Uses the existing ImperialUI or IORP_WILTOS_UI theme colors/fonts when those addons are loaded.
- Falls back to the same dark / red / steel visual style if neither theme table exists.
- Does not use the stock wiltOS 3D-world crafting camera, avoiding the old crafting overlay style.

INSTALL
1. Put the folder "imperial_order_wiltos_crafting_ui" inside garrysmod/addons/
2. Restart the server or change map.
3. Use the normal wiltOS crafting station. The new interface opens when wiltOS sends the crafting data.

CLIENT COMMANDS
imperial_order_saber_crafting       - Reopen the UI if the server has already sent crafting inventory data.
imperial_order_crafting_ui_reload   - Rebuild fonts and refresh the override.

CLIENT CVARS
imperial_order_crafting_ui_enabled 1/0
imperial_order_crafting_ui_brand "IMPERIAL ORDER"

COMPATIBILITY
- Designed for the wiltOS Advanced Lightsaber Combat System crafting implementation present in the supplied archive.
- Gamemode-independent: works with DarkRP or Helix as long as the same wiltOS crafting backend is present.
- The addon does not edit encrypted/server .wos files.
