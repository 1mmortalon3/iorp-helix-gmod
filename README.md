# Imperial Order Roleplay

Custom Garry's Mod Helix schema with Imperial Order addons. Schema author: **1mmortalon3**.

This github repository was prepared from a supplied September 9, 2026 server archive. The gamemode folder remains `starwarsrp`; its displayed title remains Imperial Order. It contains the supplied patched Helix framework, including its character-column and player-table database recovery code.

## Contents

- `gamemodes/starwarsrp/`: schema, factions, classes, interface and plugins.
- `gamemodes/helix/`: the framework snapshot used by this archive, with its MIT license retained.
- `addons/`: custom addons listed below.
- `lua/autorun/server/workshop.lua`: the original Workshop content references.
- `cfg/server.example.cfg`: clean server configuration template.
- `docs/DEPENDENCIES.md`: separately installed content and excluded components.
- `docs/PACKAGING.md`: scope and validation details.

Included addons:

- `axel_admin`
- `imperial_order_branding`
- `imperial_order_command_posts`
- `imperial_order_comms_jammer`
- `imperial_order_recruitment_terminal`
- `imperial_order_tactical_insertion`
- `imperial_order_wiltos_compat`
- `imperial_order_wiltos_crafting_ui`
- `imperial_order_wiltos_ui_override`

## Install on a server

1. Install a Garry's Mod dedicated server and stop it before copying files. Back up an existing installation and its database first.
2. Copy this package's `gamemodes`, `addons`, and `lua` folders into the server's `garrysmod` directory. Preserve your existing private configuration and data.
3. Install the dependencies listed in `docs/DEPENDENCIES.md`, including the map and model/weapon content you use. Workshop download references alone do not mount content on the server.
4. For a new server, copy `cfg/server.example.cfg` to `garrysmod/cfg/server.cfg` and configure it locally. Do not overwrite an existing server.cfg without reviewing it.
5. Select `starwarsrp` as the gamemode and an installed map in your hosting panel. A launch argument example is `+gamemode starwarsrp +map gm_construct` for an initial smoke test.
6. Start the server, inspect the console, join, create a character, and check the HUD, staff permissions, loadouts and persistence across a restart.

SQLite is the default. No live database or player records are shipped. For an existing server, preserve `sv.db` and `data/`; do not replace or wipe them as part of installing this source package. Optional Axel MySQL configuration is generated under `data/axel/mysql.json` and stays private. MySQL native modules must be installed separately when used.

## Put this on GitHub

Extract the ZIP first. Create an empty GitHub repository, then open a terminal inside the extracted folder containing this README:

```sh
git init
git add .
git diff --cached --stat
git commit -m "Add Imperial Order source package"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
git push -u origin main
```

Replace the repository URL with your own. Upload the extracted project contents, rather than committing this ZIP. Review staged files before publishing. This is a server source repository; GitHub Pages cannot run a Garry's Mod server.

## Credits and permissions

Existing author credits and bundled license notices are retained. No new blanket license is assigned to custom code or artwork. Helix is covered by its included license; other content retains its authors' terms. Separately supplied third-party addons are not included here. See `docs/DEPENDENCIES.md`.
