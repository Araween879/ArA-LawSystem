-- ArA-LawSystem - Tabellen
--
-- NICHT noetig: Das Script legt alle Tabellen beim Start selbst an und
-- ergaenzt fehlende Spalten automatisch (server/core/01_db.lua).
-- Diese Datei ist nur zur Ansicht / fuer manuelle Installationen.
-- Massgeblich ist immer server/core/01_db.lua.

CREATE TABLE IF NOT EXISTS `ara_law_society` (
  `department` VARCHAR(32) NOT NULL,
  `balance` DECIMAL(14,2) NOT NULL DEFAULT 0,
  `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Weitere Tabellen: ara_law_society_log, ara_law_duty_log, ara_law_audit,
-- ara_law_citizens, ara_law_records, ara_law_fines, ara_law_warrants,
-- ara_law_bounties, ara_law_licenses, ara_law_jail, ara_law_evidence,
-- ara_law_weapons, ara_law_escorts - siehe docs/01_CONTRACT.md Abschnitt 7.
