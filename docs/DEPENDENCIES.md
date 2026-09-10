# Dependencies and excluded content

The following addon folders were present in the source archive and are intentionally external to this repository. Install the versions you are entitled to use separately when their features are required:

- `arccw-empire-essentials-v2-5-4`
- `arccw-krakens-explosives-v1-7-4`
- `arccw-special-forces-v3-6-0`
- `hats_hook`
- `imperial_order_communications`
- `pixel-ui-master`
- `wos-alcs-blades-anzati`
- `wos-alcs-forms-initiate`
- `wos-alcs-items-anzati`
- `wos-alcs-items-zhrom`
- `wos-alcs-powers-darkasc`
- `wos-alcs-powers-icefuse`
- `wos-inv`
- `wos-sentinel-immo`

The Imperial Order wiltOS compatibility, crafting and interface addons integrate with a separately installed wiltOS/Sentinel system; they do not supply its combat backend. ArcCW weapon packs require their weapon base. The excluded `imperial_order_communications` folder contains RDV communications code despite its renamed folder; the custom schema chat/comms plugin remains included.

Models, materials, weapons, maps and frameworks referenced by the schema may come from Workshop content. The original Workshop file is retained as a content reference; availability and completeness were not verified online. Install and mount the content server-side as well as arranging client downloads.

Garry's Mod supplies `base`, `sandbox` and `terrortown`, its standard Lua files and engine binaries. Those copies are excluded. Hosting-provider `crashphys.lua` and `physgun_shared_misc.lua` are not part of this project. Native MySQL modules are excluded; install a suitable module separately only if selecting MySQL.

Old nested ZIP/TAR backups are excluded, including archived admin menu versions. The active `axel_admin` directory from the supplied snapshot is included. Server settings, staff lists, live configuration and `sv.db` are omitted.
