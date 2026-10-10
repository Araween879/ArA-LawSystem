--[[
    ArA-LawSystem - Schuesse und Verletzungen melden (Client)

    Der Client meldet NUR "ich habe geschossen" (mit dem Waffen-Hash) bzw.
    "ich blute". Position, Seriennummer und Blutgruppe bestimmt der Server
    selbst - ein manipulierter Client kann damit hoechstens sich selbst
    belasten. Der Server drosselt zusaetzlich (ShotRateMs / BleedRateMs).
]]

local Cfg = Config.Evidence

-- Nur Feuerwaffen hinterlassen Huelsen (keine Boegen, Wurfwaffen, Nahkampf, Lasso)
local FIREARM_GROUPS = {
    [`GROUP_REVOLVER`] = true,
    [`GROUP_PISTOL`]   = true,
    [`GROUP_REPEATER`] = true,
    [`GROUP_RIFLE`]    = true,
    [`GROUP_SNIPER`]   = true,
    [`GROUP_SHOTGUN`]  = true,
}

local function isFirearm(hash)
    if not hash or hash == 0 or hash == `WEAPON_UNARMED` then return false end
    return FIREARM_GROUPS[GetWeapontypeGroup(hash)] == true
end

local function asBool(v)
    return v == true or v == 1
end

-- Schuesse: enge Schleife nur, solange eine Feuerwaffe in der Hand ist
CreateThread(function()
    local lastShot = 0
    while true do
        local sleep = 750
        if Law.Ready and Cfg.Enabled and not Law.State.jailed then
            local ped = PlayerPedId()
            local _, hash = GetCurrentPedWeapon(ped, true, 0, true)
            if isFirearm(hash) then
                sleep = 0  -- IsPedShooting ist nur im Schuss-Frame wahr
                if IsPedShooting(ped) then
                    local now = GetGameTimer()
                    if now - lastShot >= (Cfg.ShotRateMs or 1500) then
                        lastShot = now
                        Law.Net.Send('evidence:shot', hash)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Verletzungen: Lebenspunkte einmal pro Sekunde vergleichen
CreateThread(function()
    local lastHealth = nil
    local lastBleed = 0
    while true do
        Wait(1000)
        if Law.Ready and Cfg.Enabled then
            local ped = PlayerPedId()
            local hp = GetEntityHealth(ped)
            if lastHealth and not IsEntityDead(ped) and lastHealth - hp >= (Cfg.BleedMinDamage or 10) then
                local now = GetGameTimer()
                if now - lastBleed >= (Cfg.BleedRateMs or 10000) then
                    lastBleed = now
                    Law.Net.Send('evidence:bleed', asBool(IsPedInMeleeCombat(ped)))
                end
            end
            lastHealth = hp
        else
            lastHealth = nil
        end
    end
end)
