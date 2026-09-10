-- Imperial Order jammer failure effects
-- Disabled jammers emit ongoing electrical sparks.
-- Destroyed jammers emit a spark cascade followed by a controlled explosion.

IMPERIAL_ORDER_CommsJammerFailure = IMPERIAL_ORDER_CommsJammerFailure or {}
local FX = IMPERIAL_ORDER_CommsJammerFailure

local cvStandardDamage = CreateConVar(
    "sv_imperial_order_jammer_explosion_damage",
    "30",
    {FCVAR_ARCHIVE, FCVAR_NOTIFY},
    "Blast damage caused when a standard communications jammer is destroyed. Set to 0 for visual-only explosions.",
    0,
    500
)

local cvArmoredDamage = CreateConVar(
    "sv_imperial_order_armored_jammer_explosion_damage",
    "75",
    {FCVAR_ARCHIVE, FCVAR_NOTIFY},
    "Blast damage caused when an armored communications relay is destroyed. Set to 0 for visual-only explosions.",
    0,
    1000
)

local function FailurePosition(ent, spread)
    if not IsValid(ent) then return vector_origin end

    local pos = ent:LocalToWorld(ent:OBBCenter())
    if spread and spread > 0 then
        pos = pos + VectorRand() * spread
    end

    return pos
end

function FX.EmitSpark(ent, intensity, spread)
    if not IsValid(ent) then return end

    local pos = FailurePosition(ent, spread or 6)
    local spark = EffectData()
    spark:SetOrigin(pos)
    spark:SetNormal(VectorRand():GetNormalized())
    spark:SetMagnitude(math.max(intensity or 1, 0.1))
    spark:SetScale(math.max((intensity or 1) * 0.55, 0.15))
    spark:SetRadius(math.max(intensity or 1, 0.25))
    util.Effect("ElectricSpark", spark, true, true)
end

function FX.EmitSmoke(ent, scale)
    if not IsValid(ent) then return end

    local smoke = EffectData()
    smoke:SetOrigin(FailurePosition(ent, 5) + Vector(0, 0, 8))
    smoke:SetScale(scale or 0.5)
    util.Effect("smoking", smoke, true, true)
end

function FX.SparkBurst(ent, armored, count, interval)
    if not IsValid(ent) then return end

    local amount = count or (armored and 8 or 5)
    local delay = interval or 0.09

    for i = 0, amount - 1 do
        timer.Simple(i * delay, function()
            if not IsValid(ent) or ent.FadingOut then return end

            FX.EmitSpark(ent, armored and 1.7 or 1.1, armored and 15 or 9)
            if i % 2 == 0 then
                sound.Play(
                    "ambient/energy/spark" .. math.random(1, 6) .. ".wav",
                    FailurePosition(ent, 4),
                    armored and 72 or 66,
                    math.random(90, 115),
                    armored and 0.58 or 0.45
                )
            end
        end)
    end
end

function FX.Explode(ent, armored)
    if not IsValid(ent) or ent.FadingOut or ent.IMPERIAL_ORDERExplosionPlayed then return end
    ent.IMPERIAL_ORDERExplosionPlayed = true

    local pos = FailurePosition(ent, 0)
    local scale = armored and 2.25 or 1.25

    local blast = EffectData()
    blast:SetOrigin(pos)
    blast:SetMagnitude(scale)
    blast:SetScale(scale)
    blast:SetRadius(armored and 4 or 2.5)
    util.Effect("cball_explode", blast, true, true)

    local flash = EffectData()
    flash:SetOrigin(pos)
    flash:SetScale(scale)
    util.Effect("Explosion", flash, true, true)

    sound.Play(
        armored and "ambient/explosions/explode_4.wav" or "ambient/explosions/explode_8.wav",
        pos,
        armored and 92 or 84,
        armored and 92 or 105,
        armored and 0.95 or 0.8
    )

    util.ScreenShake(
        pos,
        armored and 8 or 4,
        armored and 135 or 105,
        armored and 1.0 or 0.65,
        armored and 700 or 450
    )

    local damage = armored and cvArmoredDamage:GetFloat() or cvStandardDamage:GetFloat()
    if damage > 0 then
        util.BlastDamage(
            ent,
            ent,
            pos,
            armored and 260 or 160,
            damage
        )
    end
end

function FX.BeginDisabled(ent, armored)
    if not IsValid(ent) then return end

    ent.IMPERIAL_ORDERFailureDestroyed = false
    ent.IMPERIAL_ORDERFailureActive = true
    ent.IMPERIAL_ORDERNextFailureSpark = CurTime() + 0.35
    ent:SetColor(armored and Color(88, 88, 92, 255) or Color(82, 82, 88, 255))

    FX.SparkBurst(ent, armored, armored and 6 or 4, 0.11)
    sound.Play("ambient/machines/thumper_shutdown1.wav", FailurePosition(ent, 0), armored and 72 or 66, 96, 0.5)
end

function FX.RestoreDisabled(ent, armored)
    if not IsValid(ent) then return end

    ent.IMPERIAL_ORDERFailureDestroyed = false
    ent.IMPERIAL_ORDERFailureActive = true
    ent.IMPERIAL_ORDERExplosionPlayed = false
    ent.IMPERIAL_ORDERNextFailureSpark = CurTime() + math.Rand(0.75, 1.5)
    ent:SetColor(armored and Color(88, 88, 92, 255) or Color(82, 82, 88, 255))
end

function FX.BeginDestroyed(ent, armored)
    if not IsValid(ent) then return end

    ent.IMPERIAL_ORDERFailureDestroyed = true
    ent.IMPERIAL_ORDERFailureActive = true
    ent.IMPERIAL_ORDERNextFailureSpark = CurTime() + 0.2
    ent:SetColor(armored and Color(36, 36, 40, 255) or Color(48, 48, 52, 255))

    FX.SparkBurst(ent, armored, armored and 10 or 7, armored and 0.075 or 0.085)

    timer.Simple(armored and 0.55 or 0.42, function()
        if not IsValid(ent) or ent.FadingOut then return end
        FX.Explode(ent, armored)

        if armored then
            ent:Ignite(10, 0)
        else
            ent:Ignite(5, 0)
        end
    end)
end

function FX.Think(ent, armored)
    if not IsValid(ent) or ent.FadingOut or not ent.IMPERIAL_ORDERFailureActive then return end

    local now = CurTime()
    if now < (ent.IMPERIAL_ORDERNextFailureSpark or 0) then return end

    local destroyed = ent.IMPERIAL_ORDERFailureDestroyed == true
    FX.EmitSpark(ent, destroyed and (armored and 1.5 or 1.0) or (armored and 1.0 or 0.7), armored and 14 or 8)

    if destroyed or math.random() < 0.35 then
        FX.EmitSmoke(ent, destroyed and (armored and 0.8 or 0.55) or 0.35)
    end

    if math.random() < (destroyed and 0.7 or 0.35) then
        sound.Play(
            "ambient/energy/spark" .. math.random(1, 6) .. ".wav",
            FailurePosition(ent, 4),
            armored and 65 or 58,
            math.random(88, 118),
            destroyed and 0.42 or 0.28
        )
    end

    if destroyed then
        ent.IMPERIAL_ORDERNextFailureSpark = now + math.Rand(0.55, armored and 1.15 or 1.45)
    else
        ent.IMPERIAL_ORDERNextFailureSpark = now + math.Rand(1.15, armored and 2.1 or 2.75)
    end
end
