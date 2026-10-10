--[[
    ArA-LawSystem - Schuesse und Verletzungen melden (Client)

    Der Client meldet NUR "ich habe geschossen" (mit dem Waffen-Hash) bzw.
    "ich wurde getroffen (Faust/Schuss/Messer/Tier/sonst)". Position,
    Seriennummer und Blutgruppe bestimmt der Server selbst - ein manipulierter
    Client kann damit hoechstens sich selbst belasten. Der Server drosselt
    zusaetzlich (ShotRateMs / BleedRateMs / ClothRateMs).
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

--------------------------------------------------------------------------
-- Verletzungen: Spiel-Ereignis EVENT_ENTITY_DAMAGED (Gruppe 0, 9 Felder)
--   0 getroffenes Entity, 1 Angreifer, 2 Waffen-Hash, 3 Munition, 4 Schaden (float)
-- Der Client sagt nur WELCHE Art Treffer (fist/shot/sharp/animal/other).
-- Ob Blut/Kleidung faellt, wuerfelt der Server (Config.Evidence.Wounds).
--------------------------------------------------------------------------
local EVENT_ENTITY_DAMAGED = 402722103   -- 0x18010D37
local EVENT_SIZE = 9

local function u32(h)
    h = math.tointeger(tonumber(h) or 0) or 0
    if h < 0 then h = h + 4294967296 end
    return h
end

local SHARP = {}
for _, name in ipairs(Cfg.SharpWeapons or {}) do SHARP[u32(joaat(name))] = true end

local UNARMED = u32(joaat('WEAPON_UNARMED'))
local SHOT_GROUPS = {}
for _, g in ipairs({ 'GROUP_REVOLVER', 'GROUP_PISTOL', 'GROUP_REPEATER', 'GROUP_RIFLE', 'GROUP_SNIPER', 'GROUP_SHOTGUN', 'GROUP_BOW' }) do
    SHOT_GROUPS[u32(joaat(g))] = true
end
local BLUNT_GROUPS = { [u32(joaat('GROUP_MELEE'))] = true, [u32(joaat('GROUP_HELD'))] = true, [u32(joaat('GROUP_UNARMED'))] = true }

--- Art des Treffers aus Waffe und Angreifer
local function woundKind(weapon, attacker)
    if attacker and attacker ~= 0 and DoesEntityExist(attacker) and IsEntityAPed(attacker) and not IsPedHuman(attacker) then
        return 'animal'
    end
    weapon = u32(weapon)
    if SHARP[weapon] then return 'sharp' end
    if weapon == UNARMED then return 'fist' end
    local group = u32(GetWeapontypeGroup(weapon))
    if SHOT_GROUPS[group] then return 'shot' end
    if BLUNT_GROUPS[group] then return 'fist' end
    return 'other'
end

-- Puffer fuer GET_EVENT_DATA: 8 Byte je Feld, nicht internierter String
-- (string.blob in CfxLua, sonst ein langer String > 40 Byte)
local function newBuffer()
    local n = EVENT_SIZE * 8
    return string.blob and string.blob(n) or string.rep('\0', math.max(41, n))
end

local function readDamage(index)
    local buf = newBuffer()
    if not Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 0, index, buf, EVENT_SIZE) then return nil end  -- GET_EVENT_DATA
    local victim   = string.unpack('<i4', buf, 1)
    local attacker = string.unpack('<i4', buf, 9)
    local weapon   = string.unpack('<i4', buf, 17)
    local damage   = string.unpack('<f', buf, 33)
    return victim, attacker, weapon, damage
end

-- schwerste Art zuerst (ein Frame kann mehrere Treffer haben)
local RANK = { sharp = 5, shot = 4, animal = 3, fist = 2, other = 1 }
local SEND_MS = 400   -- hoechstens so oft eine Meldung (Server drosselt zusaetzlich)

CreateThread(function()
    local lastSent = 0
    local pending = nil
    while true do
        local sleep = 0
        if Law.Ready and Cfg.Enabled then
            local ped = PlayerPedId()
            local n = GetNumberOfEvents(0)
            for i = 0, n - 1 do
                if GetEventAtIndex(0, i) == EVENT_ENTITY_DAMAGED then
                    local victim, attacker, weapon, damage = readDamage(i)
                    if victim == ped and attacker ~= ped and (damage or 0) > 0 then
                        local kind = woundKind(weapon, attacker)
                        if not pending or RANK[kind] > RANK[pending] then pending = kind end
                    end
                end
            end
            if pending and GetGameTimer() - lastSent >= SEND_MS then
                lastSent = GetGameTimer()
                Law.Net.Send('evidence:wound', pending)
                pending = nil
            end
        else
            pending = nil
            sleep = 500
        end
        Wait(sleep)
    end
end)
