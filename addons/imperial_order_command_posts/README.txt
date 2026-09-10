IMPERIAL ORDER COMMAND POSTS
=============================

Install this folder in garrysmod/addons.

This is a standalone addon. It does not require files from the Imperial Order
server package. On Helix it reads character factions; on other gamemodes it
uses the player's team name.

Admin setup:
1. Open the Q menu.
2. Go to Tools > Imperial Order > Command Post.
3. Choose the post name, capture radius, capture time, and starting owner.
4. Left-click the map to place a post.
5. Right-click a post to remove it.
6. Reload while aiming at a post to reset it to neutral.

Posts automatically save per map in:
data/imperial_order/command_posts/<map>.json

Server commands:
- imperial_order_commandposts_save
- imperial_order_commandposts_reload
- imperial_order_commandposts_clear

Default capture sides:
- Galactic Empire: all Imperial Order military, command, Inquisitorius,
  Purge Trooper, 501st, Inferno Squad, and related factions.
- Rebel Alliance: factions or teams with IDs or names containing rebel,
  alliance, insurgent, or resistance.
- All other factions are ignored and cannot capture or contest command posts.

Ownership models:
- Galactic Empire: models/capturepoint/red/imperial/imperial_r.mdl
- Rebel Alliance: models/capturepoint/blue/rebels/rebels_b.mdl
- Neutral: models/capturepoint/white_none/base.mdl

If the capture-point content is not mounted, a post falls back to the stock
Combine interface model so it still spawns instead of erroring.

The post automatically changes to the capturing faction's model when capture
progress reaches 100%. The capture-point model content must be mounted on the
server and clients.

Edit SideDefinitions or FactionOverrides in:
lua/autorun/imperial_order_command_posts.lua
to customize event alliances.
