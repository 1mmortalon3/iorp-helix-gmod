if SERVER then
    AddCSLuaFile("imperial_order_wiltos_ui/cl_core.lua")
    AddCSLuaFile("imperial_order_wiltos_ui/cl_adapter.lua")
    AddCSLuaFile("imperial_order_wiltos_ui/cl_menu.lua")
    AddCSLuaFile("imperial_order_wiltos_ui/cl_hud.lua")
    return
end

include("imperial_order_wiltos_ui/cl_core.lua")
include("imperial_order_wiltos_ui/cl_adapter.lua")
include("imperial_order_wiltos_ui/cl_menu.lua")
include("imperial_order_wiltos_ui/cl_hud.lua")
