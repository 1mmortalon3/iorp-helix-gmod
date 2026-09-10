local function RegisterIMPERIAL_ORDERRecruitmentPermaProps()
    if not PermaProps or not PermaProps.SpecialENTSSave or not PermaProps.SpecialENTSSpawn then return false end

    PermaProps.SpecialENTSSave["imperial_order_recruitment_terminal"] = function()
        return {}
    end

    PermaProps.SpecialENTSSpawn["imperial_order_recruitment_terminal"] = function(ent)
        ent:Spawn()
        ent:Activate()
        ent.PermaProps = true
        return true
    end

    return true
end

RegisterIMPERIAL_ORDERRecruitmentPermaProps()
hook.Add("InitPostEntity", "IMPERIAL_ORDERRecruitment_PermaProps", RegisterIMPERIAL_ORDERRecruitmentPermaProps)
timer.Simple(3, RegisterIMPERIAL_ORDERRecruitmentPermaProps)
