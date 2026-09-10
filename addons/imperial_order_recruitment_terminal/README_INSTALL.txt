IMPERIAL ORDER RECRUITMENT TERMINAL
==================================

This is a separate add-on. It is not map-bound and does not control the
communications jammer system.

Entity class:
  imperial_order_recruitment_terminal

Console model:
  models/lordtrilobite/starwars/isd/imp_console_medium03.mdl

Required model content:
  The server and clients must have the Lord Trilobite ISD content that supplies
  the model above. The model itself is not redistributed in this add-on.

Logo material:
  materials/imperial_order/imperial_recruitment_logo.png

Helix recruitment settings (server console):
  imperial_order_recruitment_faction imperial_troopers
  imperial_order_recruitment_class ""
  imperial_order_recruitment_auto_transfer 0

Passing the assessment grants the matching Helix faction whitelist. The
default does not forcibly transfer the currently active character. Set
imperial_order_recruitment_auto_transfer to 1 only when that behavior is desired.

A schema can override the assignment with the server hook:
  IMPERIAL_ORDERRecruitmentApply(player, terminal)
Return true when the schema handled recruitment, or false to deny it.


V8 MEDIUM CONSOLE / SQUARE DISPLAY FIX
======================================
- Uses models/lordtrilobite/starwars/isd/imp_console_medium03.mdl.
- Physical console defaults to its native 1.00x size.
- Collision, interaction distance, 3D2D screen, and locked camera scale together.
- Menu and click surface now use a square 1000 x 1000 canvas.
- Screen position, size, and locked camera are aligned to the square front panel.
- Existing clients are automatically migrated away from the cantina-console view.

Server setting (affects newly spawned terminals):
  imperial_order_recruitment_terminal_scale 1.00

Client reset command if a saved view still looks wrong:
  imperial_order_recruit_reset_view
