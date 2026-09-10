IMPERIAL wiltOS UI OVERRIDE v1.2.2
==================================

Purpose
-------
A client-side presentation override made specifically for the supplied
wos-sentinel-immo package. It uses wiltOS Sentinel's native progression,
network messages, character data, skill trees, whitelists, forms and prestige.
It does not create a second progression database.

Install
-------
1. Place the folder `imperial_order_wiltos_ui_override` in:
   garrysmod/addons/
2. Keep your existing wos-sentinel-immo addon installed.
3. Fully restart the server and reconnect.
4. Do not merge this folder into the wiltOS addon.

Overrides
---------
- wOS.ALCS.Skills:OpenSkillsMenu()
- wOS.ALCS.Skills:CloseSkillsMenu()
- wOS.ALCS.Skills:OpenClassicTreeMenu()
- wOS.ALCS:OpenFormMenu()
- wOS.ALCS.DrawLightsaberHUD hook
- Default mounted wiltOS XP HUD

Native wiltOS interfaces used
------------------------------
- NW2 fields: wOS.SkillLevel, wOS.SkillExperience, wOS.SkillPoints
- Tables: wOS.SkillTrees, wOS.EquippedSkills, wOS.SkillTreeWhitelists
- Skill purchase: wOS.SkillTree.ChooseSkill
- Skill reset: wOS.SkillTree.ResetAllSkills
- Prestige: wOS.ALCS.Prestige.Ascend
- Mastery purchase: wOS.ALCS.Prestige.GetMasteryBate
- Forms: wOS.ALCS.SendFormSelect / wOS.ALCS.SendStanceSelect

Commands
--------
imperial_order_wiltos_ui      - Open overview
imperial_order_wiltos_skills  - Open skill trees
imperial_order_wiltos_forms   - Open compact form selector
imperial_order_wiltos_admin   - Open the native wiltOS admin menu (admin only)
imperial_order_wiltos_levelhud - Toggle the WiltOS level HUD; accepts on/off

Client convars
--------------
imperial_order_wiltos_ui_enabled 1
imperial_order_wiltos_ui_f2 0
imperial_order_wiltos_ui_hud 1
imperial_order_wiltos_ui_progress_hud 1

Key ownership
-------------
This addon does not claim F2, F4, F7, or any other physical key.
Open wiltOS through the dedicated skill station or the commands listed above.

Notes
-----
- The server remains authoritative for purchases and validation.
- Prestige behavior and refunds follow your existing wiltOS configuration.
- User-group, job, whitelist and custom CanViewTree restrictions are respected.
- This addon does not modify or redistribute the supplied wiltOS package.

V1.0.1 FIXES
- The custom level/XP bar now respects wOS.ALCS.Config.Skills.MountLevelToHUD.
- When Sentinel disables the progression HUD, both the stock and Imperial progress bars remain hidden.

V1.1.0 FIXES
- Removed the F2 / gm_showteam key hook.
- Kept station-driven and command-driven wiltOS access intact.
- Prevented wiltOS from competing with the Imperial F2 skill menu.


V263 ADMIN COMMAND
------------------
Use this from the client console while logged in as an administrator:

imperial_order_wiltos_admin

Aliases:
imperial_order_wos_admin
imperial_order_open_wiltos_admin

The wrapper calls the official wiltOS command `wos_openadminmenu`. Final access is
still controlled by `wOS.ALCS.Config.CanAccessAdminMenu`; this addon does not
bypass or replace wiltOS permissions. An ADMIN TOOLS button is also displayed in
the custom wiltOS navigation panel for administrators.


V264 ADMIN BRIDGE
-----------------
The admin aliases now use a server-authorized bridge that synchronizes the
caller's Garry's Mod admin group with wOS.ALCS.Config.CanAccessAdminMenu.
Use `imperial_order_wiltos_admin_status` for detailed load/permission diagnostics.


V1.2.2 LEVEL HUD TOGGLE
-----------------------
Use this from the client console:

imperial_order_wiltos_levelhud

Optional explicit states:

imperial_order_wiltos_levelhud off
imperial_order_wiltos_levelhud on

The setting saves per client. Disabling the Imperial level HUD also keeps the
stock WiltOS level bar suppressed. XP gain, skill points, skill menus, forms,
and the lightsaber force/stamina HUD remain active.
