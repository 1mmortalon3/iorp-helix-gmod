--[[
    Imperial Order branding assets.

    Holds the shared crest used by the Helix schema UI. Both paths are
    referenced by gamemodes/starwarsrp/schema/plugins/, which has no materials
    folder of its own, so they live here instead.

    Draw sites tint the crest with surface.SetDrawColor, so the artwork is pure
    white with the shape in the alpha channel. Do not bake a background or a
    colour into these files or the tint will multiply against it.
]]

if (SERVER) then
    resource.AddFile("materials/imperial_order_ui/imperial_order_crest.png")
    resource.AddFile("materials/imperial_order/imperial_order_logo.png")
end
