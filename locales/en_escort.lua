--[[
    ArA-LawSystem - Escort texts (bodyguard, transport, valuables) - English

    Owner: Agent B. Same keys as locales/de_escort.lua. %s = placeholder.
]]

Law.LocaleAdd('en', {
    ----------------------------------------------------------------------
    -- Error codes
    ----------------------------------------------------------------------
    err_escort_busy                = 'The contract is being processed - try again in a moment.',
    err_escort_bad_type            = 'Unknown escort type.',
    err_escort_bad_escorts         = 'Invalid number of escorts.',
    err_escort_bad_duration        = 'Invalid duration.',
    err_escort_bad_destination     = 'Invalid destination.',
    err_escort_bad_cargo           = 'These goods are not transported.',
    err_escort_empty_cargo         = 'A valuables transport needs goods, money or gold.',
    err_escort_too_valuable        = 'The value is too high for one transport.',
    err_escort_recipient_unknown   = 'There is no recipient with that name.',
    err_escort_recipient_ambiguous = 'Several people share that name - be more precise.',
    err_escort_no_gold             = 'You do not carry enough gold.',
    err_escort_missing_item        = 'You are missing: %s (%sx).',
    err_escort_not_open            = 'Only open contracts can be cancelled.',
    err_escort_wrong_office        = 'This is only possible at the %s escort office.',
    err_escort_dept                = 'Your department does not take escort contracts.',
    err_escort_own                 = 'You may not escort your own contract.',
    err_escort_member              = 'You are already escorting this contract.',
    err_escort_full                = 'The contract has enough escorts.',
    err_escort_not_member          = 'You are not escorting this contract.',
    err_escort_not_leader          = 'Only the escort leader may do that.',
    err_escort_no_spawn            = 'This office has no wagon spot.',
    err_escort_client_far          = 'The protected person is not nearby.',
    err_escort_wagon_far           = 'The armored wagon is not in the destination zone.',
    err_escort_not_robbable        = 'Nothing to take here.',
    err_escort_rob_denied          = 'You belong to this transport.',
    err_escort_rob_item            = 'You need a crowbar.',
    err_escort_rob_active          = 'Someone else is already breaking the strongbox.',
    err_escort_rob_time            = 'The strongbox is not open yet.',
    err_escort_ins_self            = 'You may not decide on a claim you are involved in.',

    ----------------------------------------------------------------------
    -- Types, states, reasons
    ----------------------------------------------------------------------
    escort_type_bodyguard          = 'Bodyguard',
    escort_type_transport          = 'Personal transport',
    escort_type_cargo              = 'Valuables transport',
    escort_type_desc_bodyguard     = 'Escorts protect you for a fixed time.',
    escort_type_desc_transport     = 'Escorts take you safely to another town.',
    escort_type_desc_cargo         = 'Gold, money and valuables in the armored wagon - goods insurable.',
    escort_status_open             = 'Open',
    escort_status_accepted         = 'Accepted',
    escort_status_active           = 'En route',
    escort_status_delivered        = 'Ready for pickup',
    escort_status_claimed          = 'Picked up',
    escort_status_completed        = 'Completed',
    escort_status_failed           = 'Failed',
    escort_status_robbed           = 'Robbed',
    escort_status_cancelled        = 'Cancelled',
    escort_status_expired          = 'Expired',
    escort_reason_wagon_lost       = 'Armored wagon lost',
    escort_reason_leader_lost      = 'Leader left the transport',
    escort_reason_deadline         = 'Deadline exceeded',
    escort_reason_vip_dead         = 'Protected person died',
    escort_reason_vip_lost         = 'Person could not be found',

    ----------------------------------------------------------------------
    -- Price
    ----------------------------------------------------------------------
    escort_bd_base                 = 'Base price',
    escort_bd_duration             = 'Duration (%s min.)',
    escort_bd_distance             = 'Distance (%s km)',
    escort_bd_value                = 'Value surcharge',
    escort_bd_escorts              = 'Additional escorts (%s)',
    escort_bd_premium              = 'Insurance premium',
    escort_bd_money                = 'Cash held in trust',
    escort_summary_money           = '$%s',
    escort_summary_gold            = '%s gold',

    ----------------------------------------------------------------------
    -- Insurance (goods value only, reviewed by the department)
    ----------------------------------------------------------------------
    escort_insurance_note          = 'Only the value of the goods is insured. Cash and gold are NOT insured. Claims are reviewed by the department before payment.',
    escort_ins_state_none          = 'Not insured',
    escort_ins_state_pending       = 'Under review',
    escort_ins_state_paid          = 'Paid',
    escort_ins_state_denied        = 'Denied',
    escort_ins_state_expired       = 'Expired',
    escort_ins_no_escort           = 'No escort was at the wagon',
    escort_ins_same_player         = 'Robber is one of the parties involved',
    escort_ins_limit               = 'Too many claims in a short time',
    escort_ins_rejected            = 'Rejected by the department',
    escort_ins_new                 = 'New insurance claim: transport #%s ($%s) - review in the ledger.',
    escort_ins_paid_ok             = 'Claim #%s approved: $%s paid out.',
    escort_ins_denied_ok           = 'Claim #%s rejected.',
    escort_ins_client_paid         = 'Insurance for transport #%s: $%s paid out.',
    escort_ins_client_denied       = 'The insurance claim for transport #%s was rejected.',
    escort_ins_client_expired      = 'The insurance claim for transport #%s has expired.',

    ----------------------------------------------------------------------
    -- Booking, acceptance, progress
    ----------------------------------------------------------------------
    escort_booked                  = 'Contract #%s booked. It starts as soon as escorts are ready.',
    escort_cancelled               = 'Contract #%s cancelled - $%s refunded.',
    escort_dispatch_title          = 'Escort booked: %s',
    escort_dispatch_text           = 'Contract #%s in %s (destination: %s) - accept in the ledger.',
    escort_alert_closed            = 'Contract taken',
    escort_client_accepted         = 'Your contract #%s was accepted by %s.',
    escort_accepted                = 'Contract #%s accepted.',
    escort_accepted_leader         = 'Contract #%s accepted - you lead the escort.',
    escort_member_left             = '%s left escort #%s.',
    escort_left                    = 'You left escort #%s.',
    escort_started                 = 'Escort #%s is on its way.',
    escort_client_started          = 'Your escort #%s has started.',
    escort_paid                    = 'Escort pay: $%s (contract #%s)',
    escort_delivered_ok            = 'Contract #%s delivered.',
    escort_ended_delivered         = 'Escort #%s delivered.',
    escort_ended_completed         = 'Escort #%s completed successfully.',
    escort_ended_failed            = 'Escort #%s failed: %s',
    escort_ended_robbed            = 'Escort #%s was robbed!',
    escort_recipient_ready         = 'Delivery #%s is ready for pickup in %s.',
    escort_client_delivered        = 'Your delivery #%s arrived in %s.',
    escort_client_completed        = 'Your contract #%s is completed.',
    escort_client_failed           = 'Contract #%s failed. Refund: $%s.',
    escort_client_failed_goods     = 'Contract #%s failed. Refund: $%s. Your goods wait in the pickup box in %s.',
    escort_client_expired          = 'Contract #%s expired - fully refunded.',
    escort_client_expired_goods    = 'Contract #%s expired - fully refunded. Your goods wait in the pickup box in %s.',
    escort_client_claimed          = 'Delivery #%s was picked up by %s.',
    escort_claimed                 = 'Delivery #%s picked up.',
    escort_fach_name               = 'Pickup box contract #%s',
    escort_fach_opened             = 'Pickup box #%s opened.',

    ----------------------------------------------------------------------
    -- Escort office, wagon
    ----------------------------------------------------------------------
    escort_prompt_office           = 'Escort office',
    escort_office_title            = 'Escort office',
    escort_here_nothing            = 'Nothing for you to do here right now.',
    escort_action_start            = 'Start escort #%s (%s)',
    escort_action_to               = 'Destination: %s',
    escort_action_deliver          = 'Deliver escort #%s (%s)',
    escort_action_claim            = 'Open pickup box #%s',
    escort_interact_start          = 'Begin escort',
    escort_interact_start_desc     = 'Start bodyguard or transport - the person must be present',
    escort_interact_client         = 'Client: %s',
    escort_wagon_ready             = 'The armored wagon is ready.',
    escort_wagon_failed            = 'The armored wagon could not be provided.',
    escort_wagon_rejected          = 'The armored wagon was not accepted - please start again.',
    escort_wagon_blip              = 'Armored wagon #%s',

    ----------------------------------------------------------------------
    -- Robbery, ambush
    ----------------------------------------------------------------------
    escort_rob_group               = 'Armored wagon',
    escort_rob_prompt              = 'Break open strongbox',
    escort_loot_prompt             = 'Take loot',
    escort_rob_progress            = 'Breaking the strongbox ...',
    escort_rob_aborted             = 'Break-in aborted.',
    escort_rob_success             = 'The strongbox of transport #%s is open!',
    escort_rob_dispatch_title      = 'Valuables transport robbery',
    escort_rob_dispatch_text       = 'The armored wagon of contract #%s is being robbed!',
    escort_rob_members             = 'ALARM: Someone is breaking the strongbox of transport #%s!',
    escort_client_robbed           = 'Transport #%s was robbed. No insurance.',
    escort_client_robbed_pending   = 'Transport #%s was robbed. An insurance claim of $%s is under review.',
    escort_client_robbed_denied    = 'Transport #%s was robbed. No insurance payment: %s.',
    escort_recipient_robbed        = 'Delivery #%s for you was robbed.',
    escort_loot_name               = 'Loot from transport #%s',
    escort_loot_opened             = 'Loot box #%s opened.',
    escort_interact_loot           = 'Open loot box',
    escort_ambush_warning          = 'Ambush! Bandits ahead!',

    ----------------------------------------------------------------------
    -- Payouts to offline players
    ----------------------------------------------------------------------
    payout_reason_escort_pay       = 'Escort pay',
    payout_reason_escort_insurance = 'Valuables insurance',
    payout_reason_escort_refund    = 'Escort refund',
    payout_reason_escort_claim     = 'Valuables delivery',
    payout_reason_escort_loot      = 'Loot',
})
