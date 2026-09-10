# Imperial Order Tactical Insertion

A Helix-compatible Garry's Mod tactical insertion addon. Players place a beacon with the included SWEP. When they die, they automatically respawn at the beacon if it is still valid and unobstructed.

## Main features

- Automatic respawn after death
- Respawn at the player's own insertion beacon
- Safe-position checking to reduce players spawning inside props or walls
- Compatible with Helix character loading and character switching
- One active beacon per player
- Beacon can be damaged and destroyed
- Optional one-use mode
- Optional spawn protection
- Optional faction restrictions
- Optional Helix inventory item
- Falls back to ordinary GMod behavior outside Helix

## Installation

1. Upload the `imperial_order_tactical_insertion` folder to:
   `garrysmod/addons/imperial_order_tactical_insertion`
2. Restart the server or change maps.
3. Give the weapon with:
   `weapon_imperial_order_tactical_insertion`

Example server console command:

```text
ulx give <player> weapon_imperial_order_tactical_insertion
```

The weapon also appears under the **Imperial Order** weapons category when spawnmenu access is allowed.

## Optional Helix inventory item

Copy:

```text
helix_plugin/imperial_order_tactical_insertion
```

into:

```text
gamemodes/YOUR_SCHEMA/schema/plugins/imperial_order_tactical_insertion
```

Restart the server. The item unique ID will be `tactical_insertion`.

Example command:

```text
ix item give <player> tactical_insertion
```

## Controls

- Primary attack: place or replace your insertion beacon
- Secondary attack: remove your active beacon
- Use key on beacon: owner or admin removes it

## Configuration

Edit `lua/autorun/imperial_order_tactical_insertion.lua`.

```lua
IMPERIAL_ORDER_TACTICAL_INSERTION.RespawnDelay = 5
IMPERIAL_ORDER_TACTICAL_INSERTION.RespawnProtection = 3
IMPERIAL_ORDER_TACTICAL_INSERTION.ConsumeOnRespawn = false
IMPERIAL_ORDER_TACTICAL_INSERTION.RemoveOnCharacterSwitch = true
IMPERIAL_ORDER_TACTICAL_INSERTION.AdminOnly = false
IMPERIAL_ORDER_TACTICAL_INSERTION.MaxPlacementDistance = 140
IMPERIAL_ORDER_TACTICAL_INSERTION.MinimumSurfaceNormal = 0.55
IMPERIAL_ORDER_TACTICAL_INSERTION.BeaconHealth = 125
IMPERIAL_ORDER_TACTICAL_INSERTION.AllowedFactions = {}
```

`ConsumeOnRespawn = false` keeps the beacon active for repeated deaths. Set it to `true` to consume it after one successful respawn.

Faction restriction examples:

```lua
IMPERIAL_ORDER_TACTICAL_INSERTION.AllowedFactions = {
    "imperial_army",
    "imperial_guard"
}
```

You may also use numeric Helix faction indexes, although unique IDs are recommended.

## Notes

- No beacon means the normal Helix spawn system is used.
- If the beacon is blocked or destroyed, the player uses the normal spawn.
- Beacons are removed when their owner disconnects.
- By default, switching Helix characters removes the old character's beacon.
- The addon uses only stock Garry's Mod models and sounds.
