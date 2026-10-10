--[[
    ArA-LawSystem - Texte Eskorte (Personenschutz, Transport, Werttransport) - Deutsch

    Besitzer: Agent B. Spiel-Texte ohne Umlaute (ae/oe/ue/ss). %s = Platzhalter.
]]

Law.LocaleAdd('de', {
    ----------------------------------------------------------------------
    -- Fehlercodes
    ----------------------------------------------------------------------
    err_escort_busy                = 'Der Auftrag wird gerade bearbeitet - gleich noch einmal.',
    err_escort_bad_type            = 'Unbekannte Art der Eskorte.',
    err_escort_bad_escorts         = 'Ungueltige Anzahl Begleiter.',
    err_escort_bad_duration        = 'Ungueltige Dauer.',
    err_escort_bad_destination     = 'Ungueltiges Ziel.',
    err_escort_bad_cargo           = 'Diese Ware wird nicht transportiert.',
    err_escort_empty_cargo         = 'Ein Werttransport braucht Ware, Geld oder Gold.',
    err_escort_too_valuable        = 'Der Wert ist zu hoch fuer einen Transport.',
    err_escort_recipient_unknown   = 'Einen Empfaenger mit diesem Namen gibt es nicht.',
    err_escort_recipient_ambiguous = 'Mehrere Personen heissen so - bitte genauer.',
    err_escort_no_gold             = 'Du hast nicht genug Gold dabei.',
    err_escort_missing_item        = 'Dir fehlt: %s (%sx).',
    err_escort_not_open            = 'Nur offene Auftraege koennen storniert werden.',
    err_escort_wrong_office        = 'Das geht nur im Eskort-Buero %s.',
    err_escort_dept                = 'Deine Behoerde uebernimmt keine Eskorten.',
    err_escort_own                 = 'Eigene Auftraege darfst du nicht begleiten.',
    err_escort_member              = 'Du begleitest diesen Auftrag bereits.',
    err_escort_full                = 'Der Auftrag hat genug Begleiter.',
    err_escort_not_member          = 'Du begleitest diesen Auftrag nicht.',
    err_escort_not_leader          = 'Das darf nur der Leiter der Eskorte.',
    err_escort_no_spawn            = 'An diesem Buero steht kein Wagenplatz bereit.',
    err_escort_client_far          = 'Die zu schuetzende Person ist nicht in der Naehe.',
    err_escort_wagon_far           = 'Der Panzerwagen steht nicht in der Zielzone.',
    err_escort_not_robbable        = 'Hier gibt es nichts zu holen.',
    err_escort_rob_denied          = 'Du gehoerst zu diesem Transport.',
    err_escort_rob_item            = 'Du brauchst ein Brecheisen.',
    err_escort_rob_active          = 'Jemand anderes bricht die Kassette schon auf.',
    err_escort_rob_time            = 'Die Kassette ist noch nicht offen.',
    err_escort_ins_self            = 'Ueber einen eigenen Fall darfst du nicht entscheiden.',

    ----------------------------------------------------------------------
    -- Arten, Status, Gruende
    ----------------------------------------------------------------------
    escort_type_bodyguard          = 'Personenschutz',
    escort_type_transport          = 'Personentransport',
    escort_type_cargo              = 'Werttransport',
    escort_type_desc_bodyguard     = 'Begleiter schuetzen dich fuer eine feste Zeit.',
    escort_type_desc_transport     = 'Begleiter bringen dich sicher in eine andere Stadt.',
    escort_type_desc_cargo         = 'Gold, Geld und Wertsachen im Panzerwagen - Ware versicherbar.',
    escort_status_open             = 'Offen',
    escort_status_accepted         = 'Angenommen',
    escort_status_active           = 'Unterwegs',
    escort_status_delivered        = 'Abholbereit',
    escort_status_claimed          = 'Abgeholt',
    escort_status_completed        = 'Abgeschlossen',
    escort_status_failed           = 'Gescheitert',
    escort_status_robbed           = 'Ueberfallen',
    escort_status_cancelled        = 'Storniert',
    escort_status_expired          = 'Verfallen',
    escort_reason_wagon_lost       = 'Panzerwagen verloren',
    escort_reason_leader_lost      = 'Leiter nicht mehr beim Transport',
    escort_reason_deadline         = 'Frist ueberschritten',
    escort_reason_vip_dead         = 'Schutzperson verstorben',
    escort_reason_vip_lost         = 'Person nicht mehr auffindbar',

    ----------------------------------------------------------------------
    -- Preis
    ----------------------------------------------------------------------
    escort_bd_base                 = 'Grundpreis',
    escort_bd_duration             = 'Dauer (%s Min.)',
    escort_bd_distance             = 'Strecke (%s km)',
    escort_bd_value                = 'Wertzuschlag',
    escort_bd_escorts              = 'Weitere Begleiter (%s)',
    escort_bd_premium              = 'Versicherungspraemie',
    escort_bd_money                = 'Bargeld zur Verwahrung',
    escort_summary_money           = '$%s',
    escort_summary_gold            = '%s Gold',

    ----------------------------------------------------------------------
    -- Versicherung (nur Warenwert, Pruefung durch die Behoerde)
    ----------------------------------------------------------------------
    escort_insurance_note          = 'Versichert ist nur der Warenwert. Bargeld und Gold sind NICHT versichert. Im Schadensfall prueft die Behoerde, bevor gezahlt wird.',
    escort_ins_state_none          = 'Nicht versichert',
    escort_ins_state_pending       = 'In Pruefung',
    escort_ins_state_paid          = 'Ausgezahlt',
    escort_ins_state_denied        = 'Abgelehnt',
    escort_ins_state_expired       = 'Verfallen',
    escort_ins_no_escort           = 'Kein Begleiter war beim Wagen',
    escort_ins_same_player         = 'Raeuber gehoert zu den Beteiligten',
    escort_ins_limit               = 'Zu viele Faelle in kurzer Zeit',
    escort_ins_rejected            = 'Von der Behoerde abgelehnt',
    escort_ins_new                 = 'Neuer Versicherungsfall: Transport #%s ($%s) - im Dienstbuch pruefen.',
    escort_ins_paid_ok             = 'Versicherungsfall #%s freigegeben: $%s ausgezahlt.',
    escort_ins_denied_ok           = 'Versicherungsfall #%s abgelehnt.',
    escort_ins_client_paid         = 'Versicherung fuer Transport #%s: $%s ausgezahlt.',
    escort_ins_client_denied       = 'Die Versicherung fuer Transport #%s wurde abgelehnt.',
    escort_ins_client_expired      = 'Der Versicherungsfall zu Transport #%s ist verfallen.',

    ----------------------------------------------------------------------
    -- Buchung, Annahme, Ablauf
    ----------------------------------------------------------------------
    escort_booked                  = 'Auftrag #%s gebucht. Sobald Begleiter bereitstehen, geht es los.',
    escort_cancelled               = 'Auftrag #%s storniert - $%s erstattet.',
    escort_dispatch_title          = 'Eskorte gebucht: %s',
    escort_dispatch_text           = 'Auftrag #%s in %s (Ziel: %s) - im Dienstbuch annehmen.',
    escort_alert_closed            = 'Auftrag vergeben',
    escort_client_accepted         = 'Dein Auftrag #%s wurde von %s angenommen.',
    escort_accepted                = 'Auftrag #%s angenommen.',
    escort_accepted_leader         = 'Auftrag #%s angenommen - du leitest die Eskorte.',
    escort_member_left             = '%s hat die Eskorte #%s verlassen.',
    escort_left                    = 'Du hast die Eskorte #%s verlassen.',
    escort_started                 = 'Eskorte #%s ist unterwegs.',
    escort_client_started          = 'Deine Eskorte #%s ist gestartet.',
    escort_paid                    = 'Eskort-Lohn: $%s (Auftrag #%s)',
    escort_delivered_ok            = 'Auftrag #%s abgeliefert.',
    escort_ended_delivered         = 'Eskorte #%s abgeliefert.',
    escort_ended_completed         = 'Eskorte #%s erfolgreich beendet.',
    escort_ended_failed            = 'Eskorte #%s gescheitert: %s',
    escort_ended_robbed            = 'Eskorte #%s wurde ueberfallen!',
    escort_recipient_ready         = 'Lieferung #%s liegt in %s zur Abholung bereit.',
    escort_client_delivered        = 'Deine Lieferung #%s ist in %s angekommen.',
    escort_client_completed        = 'Dein Auftrag #%s ist abgeschlossen.',
    escort_client_failed           = 'Auftrag #%s gescheitert. Erstattung: $%s.',
    escort_client_failed_goods     = 'Auftrag #%s gescheitert. Erstattung: $%s. Deine Ware liegt im Abholfach in %s.',
    escort_client_expired          = 'Auftrag #%s ist verfallen - voll erstattet.',
    escort_client_expired_goods    = 'Auftrag #%s ist verfallen - voll erstattet. Deine Ware liegt im Abholfach in %s.',
    escort_client_claimed          = 'Lieferung #%s wurde von %s abgeholt.',
    escort_claimed                 = 'Lieferung #%s abgeholt.',
    escort_fach_name               = 'Abholfach Auftrag #%s',
    escort_fach_opened             = 'Abholfach #%s geoeffnet.',

    ----------------------------------------------------------------------
    -- Eskort-Buero, Wagen
    ----------------------------------------------------------------------
    escort_prompt_office           = 'Eskort-Buero',
    escort_office_title            = 'Eskort-Buero',
    escort_here_nothing            = 'Hier gibt es fuer dich gerade nichts zu tun.',
    escort_action_start            = 'Eskorte #%s starten (%s)',
    escort_action_to               = 'Ziel: %s',
    escort_action_deliver          = 'Eskorte #%s abliefern (%s)',
    escort_action_claim            = 'Abholfach #%s oeffnen',
    escort_interact_start          = 'Eskorte beginnen',
    escort_interact_start_desc     = 'Personenschutz oder Transport starten - die Person muss dabei sein',
    escort_interact_client         = 'Kunde: %s',
    escort_wagon_ready             = 'Der Panzerwagen steht bereit.',
    escort_wagon_failed            = 'Der Panzerwagen konnte nicht bereitgestellt werden.',
    escort_wagon_rejected          = 'Der Panzerwagen wurde nicht angenommen - bitte erneut starten.',
    escort_wagon_blip              = 'Panzerwagen #%s',

    ----------------------------------------------------------------------
    -- Ueberfall, Hinterhalt
    ----------------------------------------------------------------------
    escort_rob_group               = 'Panzerwagen',
    escort_rob_prompt              = 'Geldkassette aufbrechen',
    escort_loot_prompt             = 'Beute nehmen',
    escort_rob_progress            = 'Kassette wird aufgebrochen ...',
    escort_rob_aborted             = 'Aufbruch abgebrochen.',
    escort_rob_success             = 'Die Kassette von Transport #%s ist offen!',
    escort_rob_dispatch_title      = 'Ueberfall auf Werttransport',
    escort_rob_dispatch_text       = 'Der Panzerwagen von Auftrag #%s wird ausgeraubt!',
    escort_rob_members             = 'ALARM: Jemand bricht die Geldkassette von Transport #%s auf!',
    escort_client_robbed           = 'Transport #%s wurde ueberfallen. Keine Versicherung.',
    escort_client_robbed_pending   = 'Transport #%s wurde ueberfallen. Versicherungsfall ueber $%s wird geprueft.',
    escort_client_robbed_denied    = 'Transport #%s wurde ueberfallen. Keine Versicherungsleistung: %s.',
    escort_recipient_robbed        = 'Die Lieferung #%s fuer dich wurde ueberfallen.',
    escort_loot_name               = 'Beute aus Transport #%s',
    escort_loot_opened             = 'Beutefach #%s geoeffnet.',
    escort_interact_loot           = 'Beutefach oeffnen',
    escort_ambush_warning          = 'Hinterhalt! Banditen voraus!',

    ----------------------------------------------------------------------
    -- Nachzahlungen an Offline-Spieler (Kern: payout_reason_<grund>)
    ----------------------------------------------------------------------
    payout_reason_escort_pay       = 'Eskort-Lohn',
    payout_reason_escort_insurance = 'Versicherung Werttransport',
    payout_reason_escort_refund    = 'Erstattung Eskorte',
    payout_reason_escort_claim     = 'Lieferung Werttransport',
    payout_reason_escort_loot      = 'Beute',
})
