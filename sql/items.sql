-- ArA-LawSystem - Items
-- Einmal in die Datenbank einspielen, danach Server KOMPLETT neu starten
-- (vorp_inventory liest die Items nur beim Start).
--
-- Vorhandene Items (handcuffs, handcuffkey, lockpick, bountylicns) werden
-- wiederverwendet; hier werden nur ihre deutschen Beschriftungen gesetzt.
-- INSERT IGNORE: laesst bestehende Eintraege unangetastet (item ist PRIMARY KEY).

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `groupId`, `metadata`, `desc`, `weight`) VALUES
('law_badge',          'Dienstmarke',          1,  1, 'item_standard', 1, 1, '{}', 'Marke eines Gesetzeshueters. Benutzen zum Vorzeigen.', 0.10),
('law_fineticket',     'Bussgeldbescheid',     20, 1, 'item_standard', 1, 1, '{}', 'Ein amtlicher Bussgeldbescheid. Benutzen zum Lesen.', 0.05),
('law_evidence_bag',   'Beweismittelbeutel',   20, 1, 'item_standard', 0, 1, '{}', 'Sauberer Beutel zum Sichern von Spuren.', 0.05),
('law_casing',         'Patronenhuelse',       20, 1, 'item_standard', 0, 1, '{}', 'Gesicherte Patronenhuelse - Beweismittel.', 0.05),
('law_bloodsample',    'Blutprobe',            20, 1, 'item_standard', 0, 1, '{}', 'Gesicherte Blutprobe - Beweismittel.', 0.05),
('law_clothscrap',     'Stofffetzen',          20, 1, 'item_standard', 0, 1, '{}', 'Gesicherter Stofffetzen - Beweismittel und Geruchstraeger.', 0.05),
('law_scentcloth',     'Geruchstuch',          10, 1, 'item_standard', 0, 1, '{}', 'Tuch mit dem Geruch einer Person - fuer den Bluthund.', 0.05),
('law_whistle',        'Hundepfeife',          1,  1, 'item_standard', 1, 1, '{}', 'Ruft den Bluthund oder schickt ihn heim.', 0.10),
('law_gunfile',        'Waffenfeile',          5,  1, 'item_standard', 1, 1, '{}', 'Damit laesst sich eine Seriennummer abfeilen. Verboten.', 0.20),
('law_weaponpermit',   'Waffenschein',         10, 1, 'item_standard', 1, 1, '{}', 'Amtliche Registrierung einer Waffe. Benutzen zum Vorzeigen.', 0.05),
('law_strongbox_tool', 'Brecheisen',           3,  1, 'item_standard', 0, 1, '{}', 'Schweres Brecheisen - knackt Geldkassetten.', 1.00);

-- Vorhandene Items: nur sicherstellen, dass sie existieren (fehlen sie, werden sie angelegt)
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `groupId`, `metadata`, `desc`, `weight`) VALUES
('handcuffs',   'Handschellen',             10, 1, 'item_standard', 1, 1, '{}', 'Metallfesseln. Benutzen, um die naechste Person zu fesseln.', 0.25),
('handcuffkey', 'Handschellenschluessel',   1,  1, 'item_standard', 1, 1, '{}', 'Oeffnet Handschellen.', 0.05),
('lockpick',    'Dietrich',                 5,  1, 'item_standard', 1, 1, '{}', 'Werkzeug zum Knacken von Schloessern.', 0.05),
('bountylicns', 'Kopfgeldjaeger-Lizenz',    10, 1, 'item_standard', 1, 1, '{}', 'Nachweis einer Kopfgeldjaeger-Lizenz. Gueltig nur mit Eintrag beim Sheriff.', 0.25);
