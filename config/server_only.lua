--[[
    ArA-LawSystem - NUR SERVER

    Diese Datei steht ausschliesslich unter server_scripts im fxmanifest und
    wird nie an Clients geschickt. Webhook-URLs gehoeren NUR hierher.
    Leer lassen ('') = Kanal aus.
]]

ServerConfig = {
    Webhooks = {
        -- Kanal-Name = URL
        default  = '',   -- alles, was keinem Kanal zugeordnet ist
        duty     = '',   -- Dienst an/aus
        boss     = '',   -- einstellen, entlassen, befoerdern, Kasse
        arrest   = '',   -- fesseln, durchsuchen
        fines    = '',
        jail     = '',
        warrants = '',
        records  = '',
        bounty   = '',
        evidence = '',
        weapons  = '',
        k9       = '',
        escort   = '',
        dispatch = '',
        admin    = '',
    },

    -- Welche Audit-Aktion in welchen Kanal geht: Praefix vor dem ersten Punkt.
    -- 'jail.sentence' -> Kanal 'jail'. Unbekannte Praefixe -> 'default'.
    WebhookName   = 'ArA-LawSystem',
    WebhookAvatar = '',
    WebhookColor  = 9127187,
}
