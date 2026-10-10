--[[
    ArA-LawSystem - Uebersetzung (geteilt)

    Texte stehen in locales/<sprache>_<modul>.lua und werden per
    Law.LocaleAdd(lang, { ... }) eingetragen - so kann jedes Modul seine
    eigene Datei haben, ohne fremde Dateien anzufassen.

    Reihenfolge beim Nachschlagen: eingestellte Sprache -> Deutsch -> Schluessel
    selbst (ein Tippfehler faellt so sofort auf).
]]

Law = Law or {}
Locales = Locales or {}

local FALLBACK = 'de'

function Law.LocaleAdd(lang, tbl)
    Locales[lang] = Locales[lang] or {}
    local target = Locales[lang]
    for key, text in pairs(tbl or {}) do
        if target[key] ~= nil and target[key] ~= text then
            print(('^3[ArA-Law] Locale-Schluessel doppelt: %s/%s^7'):format(lang, key))
        end
        target[key] = text
    end
end

function Law.T(key, ...)
    local lang = (Config.General and Config.General.Locale) or FALLBACK
    local text = (Locales[lang] or {})[key] or (Locales[FALLBACK] or {})[key]
    if not text then return key end
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, text, ...)
        if ok then return out end
        return text
    end
    return text
end

--- Alle NUI-Texte (Schluessel mit "ui_"), Fallback Deutsch.
function Law.LocaleUi()
    local lang = (Config.General and Config.General.Locale) or FALLBACK
    local out = {}
    for k, v in pairs(Locales[FALLBACK] or {}) do
        if k:sub(1, 3) == 'ui_' then out[k] = v end
    end
    if lang ~= FALLBACK then
        for k, v in pairs(Locales[lang] or {}) do
            if k:sub(1, 3) == 'ui_' then out[k] = v end
        end
    end
    return out
end

-- Kurzform, die ueberall benutzt wird.
L = Law.T
