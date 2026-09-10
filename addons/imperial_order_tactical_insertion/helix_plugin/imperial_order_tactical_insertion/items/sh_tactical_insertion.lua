ITEM.name = "Tactical Insertion"
ITEM.description = "A deployable beacon that redirects your next respawn to its location."
ITEM.model = "models/lt_c/sci_fi/holo_tablet.mdl"
ITEM.category = "Tactical Equipment"
ITEM.width = 2
ITEM.height = 2

ITEM.functions.Equip = {
    name = "Equip",
    tip = "useTip",
    icon = "icon16/gun.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end

        if not client:HasWeapon("weapon_imperial_order_tactical_insertion") then
            client:Give("weapon_imperial_order_tactical_insertion")
        end

        client:SelectWeapon("weapon_imperial_order_tactical_insertion")
        return false
    end,
    OnCanRun = function(item)
        local client = item.player
        return IsValid(client) and not IsValid(item.entity)
    end
}

ITEM.functions.Holster = {
    name = "Unequip",
    tip = "useTip",
    icon = "icon16/delete.png",
    OnRun = function(item)
        local client = item.player
        if IsValid(client) then
            client:StripWeapon("weapon_imperial_order_tactical_insertion")
        end

        return false
    end,
    OnCanRun = function(item)
        local client = item.player
        return IsValid(client) and client:HasWeapon("weapon_imperial_order_tactical_insertion") and not IsValid(item.entity)
    end
}
