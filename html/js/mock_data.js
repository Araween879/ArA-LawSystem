/*
    ArA-LawSystem - Testdaten fuer den Browser-Testmodus (NUR ausserhalb von RedM benutzt)
    Die Texte sind eine Kopie von locales/de_ui.lua (Quelle der Wahrheit ist die Lua-Datei).
*/
(function () {
    'use strict';
    if (typeof GetParentResourceName !== 'undefined') return;   // im Spiel: nichts tun

    var now = Math.floor(Date.now() / 1000);
    var H = 3600, D = 86400;

    var S = {
        ui_close: 'Schließen', ui_cancel: 'Abbrechen', ui_ok: 'OK', ui_submit: 'Absenden', ui_save: 'Speichern',
        ui_search: 'Suchen', ui_yes: 'Ja', ui_no: 'Nein', ui_none: 'keine', ui_unknown: 'unbekannt', ui_remove: 'Entfernen',
        ui_empty: 'Keine Einträge.', ui_loading: 'Wird geladen', ui_load_failed: 'Konnte nicht geladen werden.',
        ui_select_choose: '– bitte wählen –', ui_select_entry: 'Links einen Eintrag wählen.',
        ui_search_min: 'Bitte mindestens 2 Zeichen eingeben.', ui_confirm_title: 'Bitte bestätigen', ui_confirm_ok: 'Ja, ausführen',
        ui_online: 'online', ui_offline: 'offline', ui_on_duty: 'Im Dienst', ui_off_duty: 'Außer Dienst',
        ui_badge_number: 'Dienstnummer', ui_serial: 'Seriennr.', ui_age: '%s Jahre', ui_valid_until: 'gültig bis %s',
        ui_dead_or_alive: 'Tot oder lebendig', ui_alive_only: 'Nur lebend', ui_gold_amount: '%s Gold',
        ui_open_file: 'Akte öffnen', ui_view_document: 'Dokument ansehen', ui_view_poster: 'Steckbrief ansehen',
        ui_approve: 'Freigeben', ui_revoke: 'Widerrufen', ui_cancel_entry: 'Stornieren', ui_waypoint_set: 'Wegpunkt gesetzt.',
        ui_menu_hint: '↑ ↓ wählen · Enter bestätigen · Esc zurück', ui_menu_empty: 'Keine Auswahl verfügbar.',

        ui_err_generic: 'Das hat nicht geklappt.', ui_err_no_response: 'Keine Antwort vom Server.',
        ui_err_bad_response: 'Ungültige Antwort erhalten.', ui_err_invalid: 'Ungültige Eingabe.',
        ui_err_no_handler: 'Diese Aktion ist nicht verfügbar.', ui_err_no_form: 'Formular nicht gefunden.',

        ui_form_required: '„%s“ ist ein Pflichtfeld.', ui_form_number: '„%s“ muss eine Zahl sein.',
        ui_form_min: '„%s“ muss mindestens %s sein.', ui_form_max: '„%s“ darf höchstens %s sein.',
        ui_form_minlen: '„%s“ braucht mindestens %s Zeichen.', ui_form_maxlen: '„%s“ darf höchstens %s Zeichen haben.',
        ui_form_min_items: 'Bei „%s“ mindestens %s auswählen.', ui_form_max_items: 'Bei „%s“ höchstens %s auswählen.',

        ui_penal_search: 'Delikt suchen …', ui_penal_all: 'Alle', ui_penal_other: 'Sonstiges', ui_penal_none: 'Kein Delikt gefunden.',
        ui_penal_nothing: 'Noch nichts ausgewählt.', ui_penal_selected: 'Ausgewählte Delikte', ui_penal_sum_fine: 'Bußgeld:',
        ui_penal_sum_jail: 'Haft:', ui_penal_sum_count: 'Delikte:', ui_penal_less: 'weniger', ui_penal_more: 'mehr',

        ui_flag_warrant: 'Haftbefehl', ui_flag_bounty: 'Kopfgeld', ui_flag_jailed: 'In Haft', ui_flag_dangerous: 'Gefährlich',

        ui_status_open: 'Offen', ui_status_overdue: 'Überfällig', ui_status_paid: 'Bezahlt', ui_status_cancelled: 'Storniert',
        ui_status_pending: 'Wartet auf Freigabe', ui_status_active: 'Aktiv', ui_status_served: 'Vollstreckt', ui_status_revoked: 'Widerrufen',
        ui_status_expired: 'Abgelaufen', ui_status_claimed: 'Eingelöst', ui_status_collected: 'Gesichert', ui_status_analyzing: 'Im Labor',
        ui_status_analyzed: 'Ausgewertet', ui_status_destroyed: 'Vernichtet', ui_status_registered: 'Registriert', ui_status_stolen: 'Gestohlen',
        ui_status_confiscated: 'Beschlagnahmt', ui_status_issued: 'Dienstwaffe', ui_status_accepted: 'Angenommen', ui_status_delivered: 'Zugestellt',
        ui_status_completed: 'Abgeschlossen', ui_status_failed: 'Gescheitert', ui_status_robbed: 'Überfallen', ui_status_unregistered: 'Nicht registriert',

        ui_filter_open: 'Offen', ui_filter_pending: 'Zur Freigabe', ui_filter_active: 'Aktiv', ui_filter_served: 'Vollstreckt',
        ui_filter_claimed: 'Eingelöst', ui_filter_unpaid: 'Unbezahlt', ui_filter_overdue: 'Überfällig', ui_filter_paid: 'Bezahlt',
        ui_filter_cancelled: 'Storniert', ui_filter_current: 'Aktuell', ui_filter_collected: 'Gesichert', ui_filter_analyzed: 'Ausgewertet',
        ui_filter_destroyed: 'Vernichtet', ui_filter_all: 'Alle',

        ui_tab_overview: 'Übersicht', ui_tab_people: 'Personen', ui_tab_warrants: 'Haftbefehle', ui_tab_bounties: 'Kopfgelder',
        ui_tab_fines: 'Bußgelder', ui_tab_jail: 'Gefängnis', ui_tab_evidence: 'Beweise', ui_tab_weapons: 'Waffen',
        ui_tab_escorts: 'Eskorten', ui_tab_department: 'Behörde',

        ui_ov_figures: 'Kennzahlen', ui_ov_stat_warrants: 'offene Haftbefehle', ui_ov_stat_bounties: 'aktive Kopfgelder',
        ui_ov_stat_inmates: 'Häftlinge', ui_ov_stat_escorts: 'laufende Eskorten', ui_ov_stat_balance: 'Kasse',
        ui_ov_on_duty: 'Im Dienst (%s)', ui_ov_since: 'seit %s', ui_ov_nobody: 'Gerade ist niemand im Dienst.',
        ui_ov_alerts: 'Einsätze', ui_ov_alerts_count: '%s offen', ui_ov_no_alerts: 'Keine offenen Einsätze.',
        ui_ov_alerts_offduty: 'Einsätze siehst du nur im Dienst.', ui_ov_expires_in: 'verfällt in %s', ui_ov_responders: 'Unterwegs: %s',
        ui_ov_no_responders: 'Noch niemand unterwegs.', ui_ov_accept: 'Annehmen', ui_ov_accepted: 'Einsatz #%s angenommen.',
        ui_ov_route: 'Route', ui_ov_close: 'Abschließen', ui_ov_closed: 'Einsatz #%s abgeschlossen.',
        ui_prio_1: 'Niedrig', ui_prio_2: 'Dringend', ui_prio_3: 'Notfall',

        ui_people_search: 'Person suchen', ui_people_search_ph: 'Vor- oder Nachname …', ui_people_hint: 'Namen eingeben und suchen.',
        ui_people_none: 'Niemand gefunden.', ui_file_title: 'Akte', ui_file_no: 'Akte Nr. %s', ui_file_age: 'Alter',
        ui_file_gender: 'Geschlecht', ui_file_blood: 'Blutgruppe', ui_file_no_sample: 'keine Probe', ui_file_notes: 'Notizen',
        ui_file_in_jail: 'In Haft (%s) – noch %s', ui_file_dangerous_stamp: 'Gefährlich', ui_file_fine: 'Bußgeld',
        ui_file_warrant: 'Haftbefehl', ui_file_bounty: 'Kopfgeld', ui_file_note: 'Notiz', ui_file_danger: 'Als gefährlich markieren',
        ui_file_undanger: 'Markierung entfernen', ui_file_revoke_license: 'Lizenz entziehen', ui_file_sec_records: 'Einträge',
        ui_file_sec_fines: 'Bußgelder', ui_file_sec_warrants: 'Haftbefehle', ui_file_sec_bounties: 'Kopfgelder',
        ui_file_sec_weapons: 'Waffen', ui_file_sec_licenses: 'Lizenzen', ui_file_no_records: 'Keine Einträge.',
        ui_file_no_fines: 'Keine Bußgelder.', ui_file_no_warrants: 'Keine Haftbefehle.', ui_file_no_bounties: 'Keine Kopfgelder.',
        ui_file_no_weapons: 'Keine registrierten Waffen.', ui_file_no_licenses: 'Keine Lizenzen.',
        ui_license_bounty: 'Kopfgeldjäger-Lizenz', ui_license_weapon: 'Waffenschein',
        ui_bounty_kind_official: 'Offiziell', ui_bounty_kind_private: 'Privat',

        ui_warrant_new: 'Neuer Haftbefehl', ui_warrant_no: 'Haftbefehl Nr. %s', ui_warrants_none: 'Keine Haftbefehle.',
        ui_bounty_new: 'Neues Kopfgeld', ui_bounty_no: 'Kopfgeld Nr. %s', ui_bounties_none: 'Keine Kopfgelder.',
        ui_fine_no: 'Bescheid Nr. %s', ui_fines_none: 'Keine Bußgelder.', ui_jail_none: 'Niemand in Haft.', ui_jail_left: 'noch %s',
        ui_jail_set_bail: 'Kaution festsetzen', ui_jail_bail_help: '0 = keine Kaution.', ui_jail_adjust: 'Haftzeit ändern',
        ui_jail_adjust_minutes: 'Minuten (+ länger / − kürzer)', ui_jail_adjust_help: 'Negative Werte verkürzen die Haft.',
        ui_jail_release: 'Freilassen',

        ui_evidence_no: 'Beweis Nr. %s', ui_evidence_none: 'Keine Beweismittel.', ui_ev_analysis: 'Laborbefund',
        ui_ev_not_analyzed: 'Noch nicht im Labor ausgewertet.', ui_ev_match: 'Treffer: %s', ui_ev_destroy: 'Vernichten',
        ui_ev_lookup_serial: 'Seriennummer prüfen', ui_weapons_search: 'Seriennummer prüfen', ui_weapons_ph: 'z. B. SN-4F2A91',
        ui_weapons_recent: 'Zuletzt geprüft', ui_weapons_hint: 'Noch keine Abfrage.', ui_weapons_not_found: 'Diese Seriennummer ist nicht im Register.',
        ui_weapons_set_status: 'Status ändern', ui_weapons_evidence: 'Beweise mit dieser Nummer', ui_weapons_no_evidence: 'Keine Beweise.',
        ui_escort_open: 'Offene Aufträge', ui_escort_mine: 'Meine Aufträge', ui_escort_accept: 'Auftrag annehmen',
        ui_escort_leave: 'Auftrag verlassen', ui_escort_members: 'Begleiter: %s', ui_escorts_none: 'Keine Aufträge.',
        ui_escort_insurance: 'Versicherungsfälle', ui_ins_none: 'Keine Versicherungsfälle.', ui_ins_no: 'Versicherungsfall #%s',
        ui_ins_pay: 'Auszahlen', ui_ins_deny: 'Ablehnen', ui_ins_state_pending: 'in Prüfung', ui_ins_state_paid: 'ausgezahlt',
        ui_ins_state_denied: 'abgelehnt', ui_ins_state_expired: 'verfallen',
        ui_confirm_ins_pay: 'Versicherung für Auftrag #%s über %s aus der Kasse auszahlen?',
        ui_confirm_ins_deny: 'Versicherungsfall #%s (%s) wirklich ablehnen?',
        ui_f_robbed_by: 'Überfallen von', ui_f_robbed_at: 'Überfallen am', ui_f_insured_value: 'Versicherter Warenwert', ui_f_ins_amount: 'Auszahlung',

        ui_dept_members: 'Mitglieder (%s)', ui_dept_hire: 'Einstellen', ui_dept_grade: 'Rang', ui_dept_grade_title: 'Rang ändern',
        ui_dept_new_grade: 'Neuer Rang', ui_dept_fire: 'Entlassen', ui_dept_hours: '%s Std. / 7 Tage', ui_dept_no_members: 'Keine Mitglieder.',
        ui_dept_treasury: 'Kasse & Kassenbuch', ui_dept_balance: 'Kassenstand', ui_dept_deposit: 'Einzahlen', ui_dept_withdraw: 'Auszahlen',
        ui_dept_log: 'Kassenbuch', ui_dept_after: 'Stand', ui_dept_no_log: 'Noch keine Buchungen.',

        ui_reason_deposit: 'Einzahlung', ui_reason_withdraw: 'Auszahlung', ui_reason_withdraw_refund: 'Rückbuchung', ui_reason_salary: 'Lohn',
        ui_reason_payroll: 'Lohn', ui_reason_fine: 'Bußgeld', ui_reason_fine_payment: 'Bußgeld', ui_reason_bail: 'Kaution',
        ui_reason_armory: 'Waffenkammer', ui_reason_bounty_official: 'Kopfgeld (offiziell)', ui_reason_bounty_refund: 'Kopfgeld-Erstattung',
        ui_reason_license: 'Lizenzverkauf', ui_reason_bounty_license: 'Lizenzverkauf', ui_reason_weapon_register: 'Waffenregistrierung',
        ui_reason_escort: 'Eskorte', ui_reason_escort_cut: 'Eskorte (Anteil)', ui_reason_escort_insurance: 'Versicherungsfall',
        ui_reason_start: 'Startguthaben',

        ui_f_reason: 'Grund', ui_f_codes: 'Delikte', ui_f_jail: 'Haftzeit', ui_f_dead_or_alive: 'Tot oder lebendig', ui_f_bounty: 'Kopfgeld',
        ui_f_created: 'Ausgestellt', ui_f_expires: 'Gültig bis', ui_f_dept: 'Behörde', ui_f_created_by: 'Ausgestellt von',
        ui_f_approved_by: 'Freigegeben von', ui_f_kind: 'Art', ui_f_placed_by: 'Auftraggeber', ui_f_officer: 'Beamter', ui_f_due: 'Fällig',
        ui_f_paid: 'Bezahlt am', ui_f_amount: 'Betrag', ui_f_status: 'Status', ui_f_bail: 'Kaution', ui_f_sentence: 'Strafmaß',
        ui_f_served: 'Verbüßt', ui_f_remaining: 'Verbleibend', ui_f_zone: 'Fundort', ui_f_collected_by: 'Gesichert von',
        ui_f_collected_at: 'Gesichert am', ui_f_weapon: 'Waffe', ui_f_subject: 'Probe von', ui_f_analyzed_by: 'Ausgewertet von',
        ui_f_note: 'Notiz', ui_f_owner: 'Besitzer', ui_f_registered: 'Registriert am', ui_f_holder: 'Derzeit bei', ui_f_client: 'Kunde',
        ui_f_recipient: 'Empfänger', ui_f_pickup: 'Abholung', ui_f_destination: 'Ziel', ui_f_duration: 'Dauer', ui_f_escorts: 'Begleiter',
        ui_f_leader: 'Leiter', ui_f_price: 'Preis', ui_f_payout: 'Lohn je Begleiter', ui_f_insurance: 'Versichert', ui_f_cargo: 'Fracht',
        ui_f_deadline: 'Frist', ui_f_claim_office: 'Abholbüro', ui_f_fail_reason: 'Grund des Scheiterns', ui_f_date: 'Datum',

        ui_confirm_revoke_warrant: 'Haftbefehl gegen %s wirklich widerrufen?',
        ui_confirm_cancel_bounty: 'Kopfgeld auf %s (%s) wirklich stornieren? Der Betrag wird erstattet.',
        ui_confirm_cancel_fine: 'Bußgeld von %s (%s) wirklich stornieren?', ui_confirm_release: '%s wirklich freilassen?',
        ui_confirm_destroy_evidence: 'Beweis Nr. %s endgültig vernichten?', ui_confirm_fire: '%s wirklich entlassen?',
        ui_confirm_revoke_license: 'Kopfgeldjäger-Lizenz von %s wirklich entziehen?', ui_confirm_escort_leave: 'Auftrag #%s wirklich verlassen?',
        ui_confirm_pay_fine: '%s jetzt bezahlen?', ui_confirm_pay_bail: 'Kaution für %s in Höhe von %s jetzt bezahlen? Sie wird nicht erstattet.',
        ui_confirm_buy_license: 'Lizenz für %s kaufen? Gültig %s Tage.',
        ui_confirm_cancel_private: 'Kopfgeld auf %s stornieren? Die Gebühr wird nicht erstattet.',
        ui_confirm_place_bounty: 'Kopfgeld auf %s über %s aussetzen? Betrag und Gebühr werden sofort abgebucht.',
        ui_confirm_report_stolen: '%s (%s) als gestohlen melden?', ui_confirm_cancel_escort: 'Auftrag #%s stornieren? Geld und Ware gehen zurück.',
        ui_confirm_book_escort: 'Auftrag verbindlich buchen? Gesamt: %s', ui_confirm_npc_accept: 'Auftrag „%s“ annehmen?',

        ui_doc_kicker: 'Amtliches Schriftstück', ui_doc_kind_ticket: 'Bußgeldbescheid', ui_doc_kind_warrant: 'Haftbefehl',
        ui_doc_kind_poster: 'Steckbrief', ui_doc_kind_license: 'Lizenz', ui_doc_kind_permit: 'Waffenschein', ui_doc_kind_report: 'Bericht',
        ui_doc_kind_evidence: 'Beweismittel', ui_doc_signature: 'Unterschrift', ui_doc_ticket_title: 'Bußgeldbescheid',
        ui_doc_ticket_body: 'Der Betrag ist bis zum Fälligkeitstag an einem Schalter der Behörde zu entrichten. Bei Versäumnis kann ein Haftbefehl ergehen.',
        ui_doc_warrant_title: 'Haftbefehl',
        ui_doc_warrant_body: 'Alle Gesetzeshüter werden angewiesen, %s festzunehmen und der nächsten Dienststelle zu überstellen.',
        ui_doc_evidence_title: 'Laborbericht', ui_poster_wanted: 'WANTED', ui_poster_dead_or_alive: 'DEAD OR ALIVE',
        ui_poster_alive: 'ALIVE ONLY', ui_poster_reward: 'REWARD', ui_poster_crimes: 'Gesucht wegen',

        ui_board_title: 'Steckbriefe', ui_board_side_title: 'Aushang', ui_board_bounties: 'Kopfgelder', ui_board_contracts: 'Aufträge',
        ui_board_no_posters: 'Zur Zeit wird niemand gesucht.', ui_board_no_bounties: 'Keine Kopfgelder ausgeschrieben.',
        ui_board_no_contracts: 'Keine Aufträge verfügbar.', ui_board_need_license: 'Aufträge annehmen nur mit gültiger Kopfgeldjäger-Lizenz.',
        ui_npc_accept: 'Annehmen', ui_npc_area: 'Gebiet: %s', ui_npc_gang: 'Bande: %s', ui_npc_difficulty: 'Gefahr: %s',
        ui_npc_alive_bonus: 'Lebend-Bonus: %s', ui_npc_expires: 'noch %s', ui_npc_diff_easy: 'gering', ui_npc_diff_medium: 'mittel',
        ui_npc_diff_hard: 'hoch', ui_npc_diff_deadly: 'tödlich',

        ui_ct_title: 'Schalter', ui_ct_citizen: 'Vorsprache: %s', ui_ct_tab_fines: 'Bußgelder', ui_ct_tab_bail: 'Kaution',
        ui_ct_tab_license: 'Lizenz', ui_ct_tab_bounty: 'Kopfgeld', ui_ct_tab_weapons: 'Waffenregister', ui_ct_tab_escort: 'Eskorte',
        ui_ct_tab_property: 'Habseligkeiten', ui_ct_tab_report: 'Anzeige', ui_ct_pay: 'Bezahlen', ui_ct_fines_title: 'Deine Bußgelder',
        ui_ct_fines_none: 'Du hast keine Bußgelder.', ui_ct_fines_open_sum: 'Offen gesamt',
        ui_ct_fines_info: 'Offene Bußgelder kannst du hier bezahlen. Überfällige Bescheide können zu einem Haftbefehl führen.',
        ui_ct_bail_title: 'Kaution hinterlegen', ui_ct_bail_none: 'Zur Zeit ist für niemanden eine Kaution festgesetzt.',
        ui_ct_pay_bail: 'Kaution zahlen', ui_ct_bail_info: 'Mit der Kaution kommt die Person sofort frei. Die Kaution wird nicht erstattet.',
        ui_ct_license_title: 'Kopfgeldjäger-Lizenz', ui_ct_license_active: 'Lizenz gültig', ui_ct_license_none: 'Keine gültige Lizenz',
        ui_ct_license_buy: 'Lizenz kaufen (%s, %s Tage)', ui_ct_license_renew: 'Verlängern (%s, %s Tage)', ui_ct_license_confirm: 'Kaufen',
        ui_ct_license_info: 'Mit Lizenz darfst du gesuchte Personen stellen, fesseln und an einer Abgabestelle abliefern. Tot nur, wenn der Steckbrief es erlaubt.',
        ui_ct_bounty_title: 'Kopfgeld aussetzen',
        ui_ct_bounty_info: 'Das Kopfgeld wird treuhänderisch verwahrt und erst nach Freigabe durch das Gesetz ausgeschrieben. Es fällt eine Gebühr an.',
        ui_ct_bounty_pick: 'Person suchen und auswählen.', ui_ct_bounty_place: 'Kopfgeld aussetzen', ui_ct_bounty_mine: 'Deine Kopfgelder',
        ui_ct_bounty_mine_none: 'Du hast keine Kopfgelder ausgesetzt.', ui_ct_weapons_title: 'Deine Waffen',
        ui_ct_weapons_none: 'Du trägst keine Schusswaffen bei dir.',
        ui_ct_weapons_info: 'Registrierte Waffen bekommen einen Waffenschein. Gestohlene Waffen werden im Register markiert – so findet das Gesetz sie wieder.',
        ui_ct_weapon_register: 'Registrieren', ui_ct_weapon_stolen: 'Als gestohlen melden', ui_ct_weapon_unregistered: 'Nicht registriert',
        ui_ct_weapon_transfer: 'Verkaufen / umschreiben',
        ui_ct_weapon_foreign: 'Auf andere Person eingetragen', ui_ct_weapon_filed: 'Seriennummer abgefeilt', ui_ct_weapon_no_serial: 'ohne Seriennummer',
        ui_ct_escort_title: 'Eskorte buchen', ui_ct_escort_type: 'Art des Auftrags', ui_ct_escort_duration: 'Dauer',
        ui_ct_escort_destination: 'Ziel', ui_ct_escort_escorts: 'Anzahl Begleiter', ui_ct_escort_escorts_help: 'zwischen %s und %s',
        ui_ct_escort_cargo: 'Fracht aus deinem Gepäck', ui_ct_escort_no_cargo: 'Keine transportfähige Ware.', ui_ct_escort_unit: 'je %s',
        ui_ct_escort_have: 'dabei: %s', ui_ct_escort_money: 'Bargeld', ui_ct_escort_gold: 'Gold', ui_ct_escort_recipient: 'Empfänger',
        ui_ct_escort_recipient_ph: 'Vor- und Nachname', ui_ct_escort_recipient_help: 'Leer lassen, wenn du selbst abholst.',
        ui_ct_escort_insurance: 'Versicherung', ui_ct_escort_insure: 'Fracht versichern', ui_ct_escort_ins_premium: 'Prämie %s %% des Werts',
        ui_ct_escort_ins_coverage: 'Deckung %s %%',
        ui_ct_escort_ins_note: 'Versichert wird nur der Warenwert – kein Bargeld und kein Gold.',
        ui_ct_escort_ins_state: 'Versicherungsfall: %s – %s',
        ui_ct_escort_book: 'Verbindlich buchen', ui_ct_escort_quote: 'Kostenvoranschlag',
        ui_ct_escort_quote_hint: 'Wähle Art und Ziel – der Preis wird sofort berechnet.', ui_ct_escort_price: 'Preis',
        ui_ct_escort_premium: 'Versicherungsprämie', ui_ct_escort_total: 'Gesamt', ui_ct_escort_mine: 'Deine Aufträge',
        ui_ct_escort_mine_none: 'Keine Aufträge.', ui_ct_escort_claim: 'Abholen', ui_esc_type_bodyguard: 'Personenschutz',
        ui_esc_type_transport: 'Personentransport', ui_esc_type_cargo: 'Werttransport', ui_ct_property_title: 'Habseligkeiten',
        ui_ct_property_yes: 'Im Schließfach liegen noch Sachen von dir.', ui_ct_property_no: 'Dein Schließfach ist leer.',
        ui_ct_property_claim: 'Abholen', ui_ct_property_info: 'Bei einer Verhaftung beschlagnahmte Gegenstände kannst du nach der Entlassung hier abholen.',
        ui_ct_report_title: 'Anzeige erstatten', ui_ct_report_info: 'Schildere kurz, was passiert ist. Die Anzeige geht an alle Gesetzeshüter im Dienst.',
        ui_ct_report_ph: 'Was ist passiert? Wo? Wer war beteiligt?', ui_ct_report_send: 'Anzeige abgeben',
        ui_ct_report_short: 'Bitte beschreibe den Vorfall etwas genauer.', ui_ct_report_side: 'Falsche Anzeigen sind strafbar.',

        ui_hud_jail: 'Haftzeit', ui_hud_jail_total: 'Strafe %s', ui_hud_jail_reduced: 'erlassen %s', ui_hud_jail_work: 'Arbeit %s/%s',
        ui_hud_cuffed: 'Gefesselt', ui_hud_cuffed_by: 'von %s', ui_hud_k9: 'Bluthund', ui_hud_k9_scent: 'Witterung',
        ui_k9_state_idle: 'bei Fuß', ui_k9_state_following: 'folgt dir', ui_k9_state_staying: 'bleibt', ui_k9_state_sniffing: 'nimmt Witterung auf',
        ui_k9_state_tracking: 'verfolgt die Spur', ui_k9_state_waiting: 'wartet auf dich', ui_k9_state_lost: 'Spur verloren',
        ui_k9_state_found: 'Gefunden!', ui_k9_state_searching: 'sucht die Umgebung ab', ui_k9_strength_fresh: 'frisch',
        ui_k9_strength_medium: 'mittel', ui_k9_strength_weak: 'schwach', ui_hud_escort: 'Eskorte', ui_hud_escort_dest: 'Ziel',
        ui_hud_escort_time: 'Restzeit', ui_hud_escort_near: 'Begleiter in der Nähe', ui_hud_evidence: 'Spurensuche',
        ui_hud_evidence_count: '%s Spuren in der Nähe', ui_hud_robbery: 'Kiste wird aufgebrochen',
        ui_layout_title: 'Oberfläche anpassen',
        ui_layout_hint: 'Ziehen: verschieben\nMausrad: Größe ändern\nDoppelklick: auf Standard zurück\nPfeiltasten: fein verschieben (Shift = schneller)\nEsc: abbrechen ohne Speichern',
        ui_layout_save: 'Speichern', ui_layout_reset_all: 'Alles zurücksetzen',
        ui_layout_duty: 'Dienst-Abzeichen (Job)', ui_layout_notify: 'Benachrichtigungen', ui_layout_jail: 'Haftzeit',
        ui_layout_cuffed: 'Handschellen', ui_layout_robbery: 'Überfall', ui_layout_k9: 'Bluthund', ui_layout_escort: 'Eskorte',
        ui_layout_evidence: 'Spurensuche', ui_layout_badge: 'Marke',
        ui_layout_demo_alert_title: '#12 Schüsse gemeldet', ui_layout_demo_alert_text: 'Valentine, Hauptstraße – /einsatz 12',
        ui_layout_demo_toast_title: 'Beispiel-Meldung', ui_layout_demo_toast_text: 'So sehen Benachrichtigungen aus.',
    };

    // ------------------------------------------------------------------
    // Testdaten (Formen nach Vertrag 10.6 und den Berichten von A/B)
    // ------------------------------------------------------------------
    var PENAL = [
        { value: 'theft', label: 'Diebstahl', category: 'Eigentum', fine: 40, jail: 5 },
        { value: 'horse_theft', label: 'Pferdediebstahl', category: 'Eigentum', fine: 120, jail: 15 },
        { value: 'cattle', label: 'Viehdiebstahl', category: 'Eigentum', fine: 90, jail: 10 },
        { value: 'burglary', label: 'Einbruch', category: 'Eigentum', fine: 80, jail: 10 },
        { value: 'bank_robbery', label: 'Bankraub', category: 'Raub', fine: 600, jail: 60 },
        { value: 'stagecoach', label: 'Postkutschenüberfall', category: 'Raub', fine: 350, jail: 40 },
        { value: 'train', label: 'Zugüberfall', category: 'Raub', fine: 500, jail: 50 },
        { value: 'assault', label: 'Körperverletzung', category: 'Gewalt', fine: 60, jail: 10 },
        { value: 'manslaughter', label: 'Totschlag', category: 'Gewalt', fine: 400, jail: 60 },
        { value: 'murder', label: 'Mord', category: 'Gewalt', fine: 800, jail: 120 },
        { value: 'weapon_town', label: 'Waffengebrauch in der Stadt', category: 'Waffen', fine: 30, jail: 0 },
        { value: 'filed_serial', label: 'Abgefeilte Seriennummer', category: 'Waffen', fine: 100, jail: 10 },
        { value: 'drunk', label: 'Trunkenheit in der Öffentlichkeit', category: 'Ordnung', fine: 10, jail: 0 },
        { value: 'disturbance', label: 'Ruhestörung', category: 'Ordnung', fine: 15, jail: 0 },
        { value: 'insult', label: 'Beamtenbeleidigung', category: 'Justiz', fine: 25, jail: 0 },
        { value: 'resist', label: 'Widerstand gegen die Staatsgewalt', category: 'Justiz', fine: 75, jail: 10 },
        { value: 'escape', label: 'Flucht aus der Haft', category: 'Justiz', fine: 150, jail: 30 },
        { value: 'moonshine', label: 'Schwarzbrennerei', category: 'Handel', fine: 70, jail: 5 },
    ];

    var M = {
        now: now,
        strings: S,
        penal: PENAL,
        officer: {
            name: 'Arthur Callahan', dept: 'sheriff', deptLabel: 'County Sheriff', gradeLabel: 'Sheriff', badgeNumber: 'SO-0042',
            seal: 'sheriff', onDuty: true, perms: ['all'],
        },
        officerLimited: {
            name: 'Jim Hawkins', dept: 'sheriff', deptLabel: 'County Sheriff', gradeLabel: 'Deputy', badgeNumber: 'SO-0117',
            seal: 'sheriff', onDuty: true,
            perms: ['duty', 'badge', 'dispatch', 'cuff', 'escort', 'search', 'idcheck', 'records_view', 'fine', 'jail', 'records_edit', 'warrant_create', 'evidence', 'weapons_registry', 'escort_contracts'],
        },
        overview: {
            onDuty: [
                { name: 'Arthur Callahan', dept: 'sheriff', deptLabel: 'County Sheriff', gradeLabel: 'Sheriff', since: now - 2 * H - 600 },
                { name: 'Jim Hawkins', dept: 'sheriff', deptLabel: 'County Sheriff', gradeLabel: 'Deputy', since: now - 45 * 60 },
                { name: 'Leigh Gray', dept: 'police', deptLabel: 'Saint Denis Police', gradeLabel: 'Sergeant', since: now - 20 * 60 },
            ],
            alerts: [
                { id: 14, kind: 'panic', title: 'PANIK - Kollege in Not', text: 'Deputy Hawkins braucht sofort Hilfe!', coords: { x: -281, y: 790, z: 119 }, zone: 'Valentine', priority: 3, createdAt: now - 60, expiresAt: now + 840, responders: [], mine: false },
                { id: 13, kind: 'shots', title: 'Schüsse gemeldet', text: 'Ein Zeuge meldet Schüsse in Rhodes (Cattleman-Revolver).', coords: { x: 1300, y: -1280, z: 76 }, zone: 'Rhodes', priority: 2, createdAt: now - 300, expiresAt: now + 600, responders: ['Leigh Gray'], mine: false },
                { id: 12, kind: 'citizen', title: 'Notruf', text: 'Sadie Adler: Pferdedieb am Stall, Richtung Norden geflohen. <b>kein HTML</b>', coords: { x: -365, y: 790, z: 116 }, zone: 'Valentine', priority: 1, createdAt: now - 900, expiresAt: now + 300, responders: ['Arthur Callahan'], mine: true },
            ],
            stats: { openWarrants: 3, activeBounties: 2, inmates: 2, openEscorts: 1, balance: 4820.5 },
        },
        people: [
            { charId: 101, name: 'Micah Bell', age: 38, gender: 'männlich', flags: { warrant: true, bounty: true, jailed: false, dangerous: true } },
            { charId: 102, name: 'Bill Williamson', age: 41, gender: 'männlich', flags: { warrant: false, bounty: false, jailed: true, dangerous: false } },
            { charId: 103, name: 'Mary-Beth Gaskill', age: 24, gender: 'weiblich', flags: { warrant: false, bounty: false, jailed: false, dangerous: false } },
            { charId: 104, name: '<img src=x onerror=alert(1)> Evil Name', age: 30, gender: 'männlich', flags: { warrant: true } },
        ],
        fines: [
            { id: 51, charId: 101, targetName: 'Micah Bell', officerName: 'Arthur Callahan', deptLabel: 'County Sheriff', reason: 'Waffengebrauch in der Stadt', codes: [{ id: 'weapon_town', label: 'Waffengebrauch in der Stadt', count: 2 }], amount: 60, status: 'overdue', statusLabel: 'Überfällig', createdAt: now - 5 * D, dueAt: now - 2 * D },
            { id: 52, charId: 103, targetName: 'Mary-Beth Gaskill', officerName: 'Jim Hawkins', deptLabel: 'County Sheriff', reason: 'Ruhestörung', codes: [{ id: 'disturbance', label: 'Ruhestörung', count: 1 }], amount: 15, status: 'open', statusLabel: 'Offen', createdAt: now - D, dueAt: now + 2 * D },
            { id: 49, charId: 102, targetName: 'Bill Williamson', officerName: 'Leigh Gray', deptLabel: 'Saint Denis Police', reason: 'Trunkenheit', codes: [{ id: 'drunk', label: 'Trunkenheit in der Öffentlichkeit', count: 1 }], amount: 10, status: 'paid', statusLabel: 'Bezahlt', createdAt: now - 9 * D, dueAt: now - 6 * D, paidAt: now - 8 * D },
        ],
        warrants: [
            { id: 31, charId: 101, targetName: 'Micah Bell', reason: 'Bankraub, Mord', codes: [{ id: 'bank_robbery', label: 'Bankraub', count: 1 }, { id: 'murder', label: 'Mord', count: 1 }], jailMinutes: 180, deadOrAlive: true, deptLabel: 'County Sheriff', createdByName: 'Arthur Callahan', approvedByName: 'Richter Hale', status: 'active', statusLabel: 'Aktiv', createdAt: now - 3 * D, expiresAt: now + 4 * D, bounty: 500 },
            { id: 32, charId: 104, targetName: '<img src=x onerror=alert(1)> Evil Name', reason: 'Pferdediebstahl', codes: [{ id: 'horse_theft', label: 'Pferdediebstahl', count: 1 }], jailMinutes: 15, deadOrAlive: false, deptLabel: 'County Sheriff', createdByName: 'Jim Hawkins', status: 'pending', statusLabel: 'Wartet auf Freigabe', createdAt: now - H, expiresAt: now + 7 * D },
        ],
        bounties: [
            { id: 71, charId: 101, targetName: 'Micah Bell', kind: 'official', amount: 500, reason: 'Bankraub in Valentine, Mord an einem Kassierer', deadOrAlive: true, status: 'active', statusLabel: 'Aktiv', placedByName: 'County Sheriff', createdAt: now - 3 * D, expiresAt: now + 4 * D },
            { id: 72, charId: 104, targetName: '<img src=x onerror=alert(1)> Evil Name', kind: 'private', amount: 120, reason: 'Hat mein Pferd gestohlen', deadOrAlive: false, status: 'pending', statusLabel: 'Wartet auf Freigabe', placedByName: 'Sadie Adler', createdAt: now - 2 * H, expiresAt: now + 7 * D },
        ],
        inmates: [
            { charId: 102, name: 'Bill Williamson', location: 'sisika', locationLabel: 'Sisika-Gefängnis', sentence: 40 * 60, served: 25 * 60, remaining: 15 * 60, reason: 'Körperverletzung, Widerstand', officerName: 'Leigh Gray', bail: 150, online: true },
            { charId: 105, name: 'Javier Escuella', location: 'sisika', locationLabel: 'Sisika-Gefängnis', sentence: 120 * 60, served: 10 * 60, remaining: 110 * 60, reason: 'Postkutschenüberfall', officerName: 'Arthur Callahan', online: false },
        ],
        evidence: [
            { id: 201, type: 'casing', typeLabel: 'Patronenhülse', zone: 'Valentine', createdAt: now - 3 * H, collectedByName: 'Jim Hawkins', collectedAt: now - 2 * H, status: 'analyzed', statusLabel: 'Ausgewertet', weaponLabel: 'Cattleman-Revolver', serial: 'SN-4F2A91', analyzedByName: 'Arthur Callahan',
              analysis: { summary: 'Hülse Kaliber .45 aus einem Cattleman-Revolver.', lines: ['Seriennummer SN-4F2A91 lesbar', 'Im Register: Micah Bell', 'Status: registriert'], match: { charId: 101, name: 'Micah Bell' } } },
            { id: 202, type: 'blood', typeLabel: 'Blutprobe', zone: 'Rhodes', createdAt: now - 5 * H, collectedByName: 'Leigh Gray', collectedAt: now - 4 * H, status: 'collected', statusLabel: 'Gesichert' },
            { id: 203, type: 'scent', typeLabel: 'Geruchsprobe', zone: 'Valentine', createdAt: now - D, collectedByName: 'Arthur Callahan', collectedAt: now - D, status: 'collected', statusLabel: 'Gesichert', subjectName: 'Bill Williamson' },
        ],
        weapons: {
            'SN-4F2A91': { serial: 'SN-4F2A91', weapon: 'WEAPON_REVOLVER_CATTLEMAN', weaponLabel: 'Cattleman-Revolver', status: 'registered', statusLabel: 'Registriert', ownerName: 'Micah Bell', ownerCharId: 101, registeredAt: now - 30 * D, notes: '', currentHolder: { name: 'Micah Bell' },
                evidence: [{ id: 201, type: 'casing', typeLabel: 'Patronenhülse', zone: 'Valentine', createdAt: now - 3 * H }] },
            'SN-77B310': { serial: 'SN-77B310', weapon: 'WEAPON_REPEATER_CARBINE', weaponLabel: 'Karabiner-Repetierer', status: 'stolen', statusLabel: 'Gestohlen', ownerName: 'Mary-Beth Gaskill', ownerCharId: 103, registeredAt: now - 12 * D, notes: 'Am Bahnhof entwendet', evidence: [] },
        },
        escortsOpen: [
            { id: 9, type: 'cargo', typeLabel: 'Werttransport', clientName: 'Leopold Strauss', recipientName: 'Hosea Matthews', pickup: 'valentine', pickupLabel: 'Valentine', destination: 'saintdenis', destinationLabel: 'Saint Denis', escortsRequired: 3, escorts: ['Arthur Callahan'], leaderName: 'Arthur Callahan', price: 420, payoutEstimate: 105, insurance: true, status: 'open', statusLabel: 'Offen', createdAt: now - H, deadlineAt: now + 3 * H, cargoSummary: '2× Goldbarren, $800', joined: false, full: false },
            { id: 10, type: 'bodyguard', typeLabel: 'Personenschutz', clientName: 'Catherine Braithwaite', pickup: 'rhodes', pickupLabel: 'Rhodes', durationMin: 60, escortsRequired: 2, escorts: [], price: 140, payoutEstimate: 52.5, insurance: false, status: 'open', statusLabel: 'Offen', createdAt: now - 20 * 60, joined: false, full: false },
        ],
        escortsMine: [
            { id: 8, type: 'transport', typeLabel: 'Personentransport', clientName: 'Josiah Trelawny', pickup: 'blackwater', pickupLabel: 'Blackwater', destination: 'strawberry', destinationLabel: 'Strawberry', escortsRequired: 1, escorts: ['Arthur Callahan'], leaderName: 'Arthur Callahan', price: 95, payoutEstimate: 71.25, insurance: false, status: 'accepted', statusLabel: 'Angenommen', createdAt: now - 3 * H, deadlineAt: now + H, joined: true, isLeader: true },
        ],
        boss: {
            dept: 'sheriff', deptLabel: 'County Sheriff', balance: 4820.5, myGrade: 4,
            grades: [{ grade: 0, label: 'Anwärter' }, { grade: 1, label: 'Deputy' }, { grade: 2, label: 'Senior Deputy' }, { grade: 3, label: 'Undersheriff' }, { grade: 4, label: 'Sheriff' }],
            members: [
                { charId: 1, name: 'Arthur Callahan', grade: 4, gradeLabel: 'Sheriff', online: true, onDuty: true, dutyHours7d: 21.5 },
                { charId: 2, name: 'Jim Hawkins', grade: 1, gradeLabel: 'Deputy', online: true, onDuty: true, dutyHours7d: 9.2 },
                { charId: 3, name: 'Charles Smith', grade: 2, gradeLabel: 'Senior Deputy', online: false, onDuty: false, dutyHours7d: 14 },
                { charId: 4, name: 'Lenny Summers', grade: 0, gradeLabel: 'Anwärter', online: true, onDuty: false, dutyHours7d: 2.5 },
            ],
            log: [
                { id: 9, amount: 60, balanceAfter: 4820.5, reason: 'fine', actorName: 'System', createdAt: now - H },
                { id: 8, amount: -150, balanceAfter: 4760.5, reason: 'withdraw', actorName: 'Arthur Callahan', createdAt: now - 5 * H },
                { id: 7, amount: -25, balanceAfter: 4910.5, reason: 'armory', actorName: 'Jim Hawkins', createdAt: now - D },
                { id: 6, amount: 150, balanceAfter: 4935.5, reason: 'bail', actorName: 'System', createdAt: now - 2 * D },
            ],
            can: { hire: true, fire: true, promote: true, funds: true, logs: true },
        },
        counter: { station: 'valentine', stationLabel: 'Valentine', citizen: { name: 'Sadie Adler', charId: 300 }, tabs: ['fines', 'bail', 'license', 'bounty', 'weapons', 'escort', 'property', 'report'], seal: 'sheriff' },
        myFines: [
            { id: 60, charId: 300, targetName: 'Sadie Adler', officerName: 'Jim Hawkins', deptLabel: 'County Sheriff', reason: 'Waffengebrauch in der Stadt', codes: [{ id: 'weapon_town', label: 'Waffengebrauch in der Stadt', count: 1 }], amount: 30, status: 'open', statusLabel: 'Offen', createdAt: now - D, dueAt: now + 2 * D },
            { id: 58, charId: 300, targetName: 'Sadie Adler', officerName: 'Arthur Callahan', deptLabel: 'County Sheriff', reason: 'Ruhestörung', codes: [], amount: 15, status: 'paid', statusLabel: 'Bezahlt', createdAt: now - 6 * D, dueAt: now - 3 * D, paidAt: now - 5 * D },
        ],
        bailList: [{ charId: 102, name: 'Bill Williamson', bail: 150 }],
        license: { active: false, expiresAt: null, price: 150, days: 14 },
        myBounties: [
            { id: 72, charId: 104, targetName: 'Evil Name', kind: 'private', amount: 120, reason: 'Hat mein Pferd gestohlen', deadOrAlive: false, status: 'pending', statusLabel: 'Wartet auf Freigabe', createdAt: now - 2 * H },
        ],
        myWeapons: [
            { id: 1, serial: 'SN-99C001', weapon: 'WEAPON_REVOLVER_SCHOFIELD', weaponLabel: 'Schofield-Revolver', registered: false, status: null, statusLabel: 'Nicht registriert', filed: false },
            { id: 2, serial: 'SN-77B312', weapon: 'WEAPON_RIFLE_VARMINT', weaponLabel: 'Varmint-Gewehr', registered: true, status: 'registered', statusLabel: 'Registriert', filed: false },
            { id: 3, serial: 'ABGEFEILT', weapon: 'WEAPON_SHOTGUN_SAWEDOFF', weaponLabel: 'Abgesägte Schrotflinte', registered: false, status: null, statusLabel: 'Nicht registriert', filed: true },
        ],
        escortOptions: {
            station: 'valentine', stationLabel: 'Valentine',
            types: [
                { value: 'bodyguard', key: 'bodyguard', label: 'Personenschutz', desc: 'Begleitschutz für eine feste Dauer.', durations: [30, 60, 90, 120], minEscorts: 1, maxEscorts: 4, needsDestination: false, needsDuration: true, allowsCargo: false, allowsInsurance: false },
                { value: 'transport', key: 'transport', label: 'Personentransport', desc: 'Sichere Fahrt von Büro zu Büro.', minEscorts: 1, maxEscorts: 3, needsDestination: true, needsDuration: false, allowsCargo: false, allowsInsurance: false },
                { value: 'cargo', key: 'cargo', label: 'Werttransport', desc: 'Gold, Geld und Waren im Panzerwagen.', minEscorts: 2, maxEscorts: 4, needsDestination: true, needsDuration: false, allowsCargo: true, allowsInsurance: true },
            ],
            destinations: [
                { value: 'saintdenis', label: 'Saint Denis', km: 3.1 }, { value: 'rhodes', label: 'Rhodes', km: 2.2 },
                { value: 'strawberry', label: 'Strawberry', km: 1.9 }, { value: 'blackwater', label: 'Blackwater', km: 2.4 },
            ],
            cargoItems: [
                { value: 'goldbar', name: 'goldbar', label: 'Goldbarren', unitValue: 500, owned: 2 },
                { value: 'gold_nugget', name: 'gold_nugget', label: 'Goldnugget', unitValue: 15, owned: 14 },
            ],
            insurance: { available: true, premiumPercent: 0.08, coverage: 0.8 },
        },
        myEscorts: [
            { id: 7, type: 'cargo', typeLabel: 'Werttransport', clientName: 'Sadie Adler', recipientName: 'Sadie Adler', pickup: 'valentine', pickupLabel: 'Valentine', destination: 'rhodes', destinationLabel: 'Rhodes', escortsRequired: 2, escorts: ['Arthur Callahan', 'Jim Hawkins'], price: 180, status: 'delivered', statusLabel: 'Zugestellt', createdAt: now - D, canClaim: true, claimOfficeLabel: 'Rhodes' },
            { id: 11, type: 'bodyguard', typeLabel: 'Personenschutz', clientName: 'Sadie Adler', pickup: 'valentine', pickupLabel: 'Valentine', durationMin: 30, escortsRequired: 1, escorts: [], price: 95, status: 'open', statusLabel: 'Offen', createdAt: now - 600 },
            { id: 5, type: 'cargo', typeLabel: 'Werttransport', clientName: 'Sadie Adler', pickup: 'valentine', pickupLabel: 'Valentine', destination: 'saintdenis', destinationLabel: 'Saint Denis', escortsRequired: 2, escorts: ['Jim Hawkins'], price: 260, insurance: true, status: 'robbed', statusLabel: 'Überfallen', createdAt: now - 2 * D, insuranceState: 'pending', insuranceAmount: 1200 },
        ],
        insurance: [
            { id: 5, clientName: 'Sadie Adler', robbedByName: 'Unbekannt (maskiert)', pickupLabel: 'Valentine', destinationLabel: 'Saint Denis', cargoSummary: '3× Goldbarren', insuredValue: 1500, amount: 1200, robbedAt: now - 2 * D + 3000, state: 'pending', stateLabel: 'in Prüfung' },
            { id: 3, clientName: 'Leopold Strauss', robbedByName: 'Micah Bell', pickupLabel: 'Rhodes', destinationLabel: 'Blackwater', cargoSummary: '40× Goldnugget', insuredValue: 600, amount: 480, robbedAt: now - 6 * D, state: 'paid', stateLabel: 'ausgezahlt' },
        ],
        property: { hasProperty: true },
        board: {
            posters: [
                { charId: 101, name: 'Micah Bell', reason: 'Bankraub in Valentine', amount: 500, deadOrAlive: true, crimes: ['Bankraub', 'Mord', 'Pferdediebstahl'], deptLabel: 'County Sheriff', createdAt: now - 3 * D },
                { charId: 105, name: 'Javier Escuella', reason: 'Postkutschenüberfall', amount: 250, deadOrAlive: false, crimes: ['Postkutschenüberfall'], deptLabel: 'US Marshals', createdAt: now - 2 * D },
                { charId: 106, name: 'Dutch van der Linde', reason: 'Zugüberfall, Bandenführer', amount: 2000, deadOrAlive: true, crimes: ['Zugüberfall', 'Bankraub', 'Mord'], deptLabel: 'Pinkerton-Detektei', createdAt: now - 6 * D },
                { charId: 104, name: '<b>Evil</b> Name', reason: 'Pferdediebstahl', amount: 120, deadOrAlive: false, crimes: ['Pferdediebstahl'], deptLabel: 'County Sheriff', createdAt: now - 2 * H },
            ],
            bounties: [],
            contracts: [
                { id: 'npc_1', name: 'Die Lemoyne-Raiders', description: 'Eine Bande überfällt Farmen bei Scarlett Meadows. Anführer lebend bevorzugt.', areaLabel: 'Scarlett Meadows', reward: 180, aliveBonus: 60, gangSize: 4, difficulty: 2, expiresAt: now + 50 * 60 },
                { id: 'npc_2', name: 'Der Schwarzbrenner vom Bayou', description: 'Verdächtiger Brenner in den Sümpfen bei Lagras.', areaLabel: 'Bayou Nwa', reward: 90, aliveBonus: 30, gangSize: 1, difficulty: 'easy', expiresAt: now + 25 * 60 },
            ],
        },
    };
    // Kopfgelder am Brett = aktive Kopfgelder
    M.board.bounties = M.bounties.filter(function (b) { return b.status === 'active'; }).concat([
        { id: 80, charId: 105, targetName: 'Javier Escuella', kind: 'official', amount: 250, reason: 'Postkutschenüberfall', deadOrAlive: false, status: 'active', createdAt: now - 2 * D },
    ]);

    window.LAW_MOCK = M;
})();
