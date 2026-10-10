/*
    ArA-LawSystem - Dienstbuch: Fach-Tabs (Vertrag 10.5)
    warrants, bounties, fines, jail, evidence, weapons, escorts, department
*/
(function () {
    'use strict';
    var LAW = window.LAW;
    var el = LAW.el, t = LAW.t, $ = LAW.$, ui = LAW.ui;
    var LG = LAW.Ledger;

    // ------------------------------------------------------------------
    // Liste links / Details rechts (gemeinsames Muster)
    // ------------------------------------------------------------------
    function listDetail(cfg) {
        var st = { filter: cfg.defaultFilter || null, selId: null, items: [] };

        function showDetail(item, tok) {
            st.selId = cfg.idOf ? cfg.idOf(item) : item.id;
            var d = cfg.detail(item, tok);
            if (d) LG.setRight(d.title, d.sub, d.kids);
        }

        function renderList(tok) {
            var box = $('lg-list');
            if (!box) return;
            var sel = null;
            ui.fill(box, [ui.list(st.items, function (it) {
                it = LAW.obj(it);
                var id = cfg.idOf ? cfg.idOf(it) : it.id;
                var r = cfg.row(it);
                r.active = st.selId !== null && String(id) === String(st.selId);
                if (r.active) sel = it;
                r.onClick = function () { showDetail(it, LG.token()); };
                return ui.row(r);
            }, (typeof cfg.emptyKey === 'function' ? cfg.emptyKey() : cfg.emptyKey) || 'ui_empty')]);
            if (sel) showDetail(sel, tok);
            else { st.selId = null; LG.rightEmpty(); }
        }

        return {
            icon: cfg.icon,
            perm: cfg.perm,
            keep: function () { return { status: st.filter, selId: st.selId }; },
            render: function (opts, tok) {
                if (opts.status) st.filter = opts.status;
                st.selId = opts.selId !== undefined ? opts.selId : null;
                var top = cfg.topActions ? cfg.topActions() : [];
                LG.setLeft([
                    ui.h(cfg.title()),
                    cfg.filters ? ui.segmented(cfg.filters(), st.filter, function (id) { st.filter = id; st.selId = null; LG.opts = { status: id }; LG.reload(false); }) : null,
                    top.length ? ui.actions(top) : null,
                    el('div', { cls: 'lg-list', attrs: { id: 'lg-list' } }, [ui.loading()]),
                ]);
                LG.opts = { status: st.filter };
                cfg.load(st.filter).then(function (res) {
                    if (!LG.alive(tok)) return;
                    if (!res.ok) { ui.fill($('lg-list'), [ui.empty('ui_load_failed')]); return; }
                    st.items = LAW.arr(res.data);
                    renderList(tok);
                });
            },
        };
    }

    function filters(ids, prefix) {
        return ids.map(function (id) { return { id: id, label: t((prefix || 'ui_filter_') + id) }; });
    }

    function fileBtn(charId) {
        if (charId === undefined || charId === null || !LG.allowed('people')) return null;
        return LAW.btn(t('ui_open_file'), function () { LG.openFile(charId); }, 'ghost small');
    }

    function docBtn(label, def) {
        return LAW.btn(label, function () { LAW.open('document', def); }, 'ghost small');
    }

    function ask(text, fn) {
        return LAW.confirm(text).then(function (ok) { if (ok) return fn(); });
    }

    function after(res) { if (res && res.ok) LG.reload(true); return res; }

    // ==================================================================
    // warrants
    // ==================================================================
    LG.tabs.warrants = listDetail({
        icon: 'doc',
        perm: 'records_view',
        defaultFilter: 'open',
        title: function () { return t('ui_tab_warrants'); },
        filters: function () { return filters(['open', 'pending', 'active', 'served', 'all']); },
        load: function (f) { return LAW.cb('warrants:list', [f], { quiet: true }); },
        topActions: function () {
            return LG.can('warrant_create') ? [LAW.btn(t('ui_warrant_new'), function () { return LG.openForm('warrant', {}); }, 'small')] : [];
        },
        row: function (w) {
            return {
                icon: 'doc',
                title: LAW.str(w.targetName),
                sub: LAW.str(w.reason, LG.codes(w.codes)),
                meta: LAW.fmt.day(w.createdAt),
                right: [ui.status(w.status, w.statusLabel)],
            };
        },
        detail: function (w) {
            var btns = [];
            if (w.status === 'pending' && LG.can('warrant_approve')) {
                btns.push(LAW.btn(t('ui_approve'), function () { return LAW.cb('warrants:approve', [w.id]).then(after); }, 'primary small'));
            }
            if ((w.status === 'pending' || w.status === 'active') && LG.can('warrant_approve')) {
                btns.push(LAW.btn(t('ui_revoke'), function () {
                    return ask(t('ui_confirm_revoke_warrant', LAW.str(w.targetName)), function () { return LAW.cb('warrants:revoke', [w.id]).then(after); });
                }, 'danger small'));
            }
            btns.push(fileBtn(w.charId));
            btns.push(docBtn(t('ui_view_document'), {
                kind: 'warrant',
                title: t('ui_doc_warrant_title'),
                subtitle: LAW.str(w.targetName),
                fields: [
                    { label: t('ui_f_reason'), value: LAW.str(w.reason) },
                    { label: t('ui_f_codes'), value: LG.codes(w.codes) || '–' },
                    { label: t('ui_f_jail'), value: w.jailMinutes ? LAW.fmt.minutes(w.jailMinutes) : '–' },
                    { label: t('ui_f_dead_or_alive'), value: ui.deadOrAlive(w.deadOrAlive) },
                    { label: t('ui_f_bounty'), value: w.bounty ? LAW.fmt.money(w.bounty) : '–' },
                    { label: t('ui_f_created'), value: LAW.fmt.date(w.createdAt) },
                    { label: t('ui_f_expires'), value: LAW.fmt.date(w.expiresAt) },
                ],
                body: t('ui_doc_warrant_body', LAW.str(w.targetName)),
                footer: LAW.str(w.deptLabel),
                seal: LG.officer.seal || LG.officer.dept,
                sealLabel: LAW.str(w.deptLabel, LG.officer.deptLabel),
                signature: LAW.str(w.approvedByName, LAW.str(w.createdByName)),
            }));
            return {
                title: LAW.str(w.targetName),
                sub: t('ui_warrant_no', LAW.str(w.id)),
                kids: [
                    el('div', 'detail__status', [ui.status(w.status, w.statusLabel)]),
                    LG.kvs([
                        [t('ui_f_reason'), LAW.str(w.reason)],
                        [t('ui_f_codes'), LG.codes(w.codes)],
                        [t('ui_f_jail'), w.jailMinutes ? LAW.fmt.minutes(w.jailMinutes) : null],
                        [t('ui_f_dead_or_alive'), ui.deadOrAlive(w.deadOrAlive)],
                        [t('ui_f_bounty'), w.bounty ? LAW.fmt.money(w.bounty) : null],
                        [t('ui_f_dept'), LAW.str(w.deptLabel)],
                        [t('ui_f_created_by'), LAW.str(w.createdByName)],
                        [t('ui_f_approved_by'), LAW.str(w.approvedByName)],
                        [t('ui_f_created'), LAW.fmt.date(w.createdAt)],
                        [t('ui_f_expires'), w.expiresAt ? LAW.fmt.date(w.expiresAt) : null],
                    ]),
                    ui.actions(btns),
                ],
            };
        },
        emptyKey: 'ui_warrants_none',
    });

    // ==================================================================
    // bounties
    // ==================================================================
    LG.tabs.bounties = listDetail({
        icon: 'skull',
        perm: 'records_view',
        defaultFilter: 'open',
        title: function () { return t('ui_tab_bounties'); },
        filters: function () { return filters(['open', 'pending', 'active', 'claimed', 'all']); },
        load: function (f) { return LAW.cb('bounty:list', [f], { quiet: true }); },
        topActions: function () {
            return LG.can('bounty_manage') ? [LAW.btn(t('ui_bounty_new'), function () { return LG.openForm('bounty_official', {}); }, 'small')] : [];
        },
        row: function (b) {
            return {
                icon: 'skull',
                title: LAW.str(b.targetName),
                sub: LAW.fmt.money(b.amount) + ' · ' + t('ui_bounty_kind_' + LAW.str(b.kind, 'official')),
                meta: LAW.str(b.reason),
                right: [ui.status(b.status, b.statusLabel)],
            };
        },
        detail: function (b) {
            var btns = [];
            if (b.status === 'pending' && LG.can('bounty_manage')) {
                btns.push(LAW.btn(t('ui_approve'), function () { return LAW.cb('bounty:approve', [b.id]).then(after); }, 'primary small'));
            }
            if ((b.status === 'pending' || b.status === 'active') && LG.can('bounty_manage')) {
                btns.push(LAW.btn(t('ui_cancel_entry'), function () {
                    return ask(t('ui_confirm_cancel_bounty', LAW.str(b.targetName), LAW.fmt.money(b.amount)), function () { return LAW.cb('bounty:cancel', [b.id]).then(after); });
                }, 'danger small'));
            }
            btns.push(fileBtn(b.charId));
            btns.push(docBtn(t('ui_view_poster'), {
                kind: 'poster', title: LAW.str(b.targetName), subtitle: LAW.str(b.reason),
                reward: LAW.num(b.amount), deadOrAlive: !!b.deadOrAlive,
                footer: LG.officer.deptLabel, seal: LG.officer.seal || LG.officer.dept,
            }));
            return {
                title: LAW.str(b.targetName),
                sub: t('ui_bounty_no', LAW.str(b.id)),
                kids: [
                    el('div', 'detail__status', [ui.status(b.status, b.statusLabel)]),
                    el('div', 'bigmoney', [LAW.fmt.money(b.amount)]),
                    LG.kvs([
                        [t('ui_f_kind'), t('ui_bounty_kind_' + LAW.str(b.kind, 'official'))],
                        [t('ui_f_reason'), LAW.str(b.reason)],
                        [t('ui_f_dead_or_alive'), ui.deadOrAlive(b.deadOrAlive)],
                        [t('ui_f_placed_by'), LAW.str(b.placedByName)],
                        [t('ui_f_created'), LAW.fmt.date(b.createdAt)],
                        [t('ui_f_expires'), b.expiresAt ? LAW.fmt.date(b.expiresAt) : null],
                    ]),
                    ui.actions(btns),
                ],
            };
        },
        emptyKey: 'ui_bounties_none',
    });

    // ==================================================================
    // fines
    // ==================================================================
    LG.tabs.fines = listDetail({
        icon: 'money',
        perm: 'records_view',
        defaultFilter: 'unpaid',
        title: function () { return t('ui_tab_fines'); },
        filters: function () { return filters(['unpaid', 'overdue', 'paid', 'cancelled', 'all']); },
        load: function (f) { return LAW.cb('fines:list', [f], { quiet: true }); },
        row: function (x) {
            return {
                icon: 'money',
                title: LAW.str(x.targetName),
                sub: LAW.fmt.money(x.amount) + ' · ' + LAW.str(x.reason, LG.codes(x.codes)),
                meta: LAW.fmt.day(x.createdAt),
                right: [ui.status(x.status, x.statusLabel)],
            };
        },
        detail: function (x) {
            var btns = [];
            if ((x.status === 'open' || x.status === 'overdue') && LG.can('fine_cancel')) {
                btns.push(LAW.btn(t('ui_cancel_entry'), function () {
                    return ask(t('ui_confirm_cancel_fine', LAW.str(x.targetName), LAW.fmt.money(x.amount)), function () { return LAW.cb('fines:cancel', [x.id]).then(after); });
                }, 'danger small'));
            }
            btns.push(fileBtn(x.charId));
            btns.push(docBtn(t('ui_view_document'), LG.fineDocument(x)));
            return {
                title: LAW.str(x.targetName),
                sub: t('ui_fine_no', LAW.str(x.id)),
                kids: [
                    el('div', 'detail__status', [ui.status(x.status, x.statusLabel)]),
                    el('div', 'bigmoney', [LAW.fmt.money(x.amount)]),
                    LG.kvs([
                        [t('ui_f_reason'), LAW.str(x.reason)],
                        [t('ui_f_codes'), LG.codes(x.codes)],
                        [t('ui_f_officer'), LAW.str(x.officerName)],
                        [t('ui_f_dept'), LAW.str(x.deptLabel)],
                        [t('ui_f_created'), LAW.fmt.date(x.createdAt)],
                        [t('ui_f_due'), LAW.fmt.date(x.dueAt)],
                        [t('ui_f_paid'), x.paidAt ? LAW.fmt.date(x.paidAt) : null],
                    ]),
                    ui.actions(btns),
                ],
            };
        },
        emptyKey: 'ui_fines_none',
    });

    /** Bussgeldbescheid als Dokument (auch vom Schalter benutzt) */
    LG.fineDocument = function (x) {
        return {
            kind: 'ticket',
            title: t('ui_doc_ticket_title'),
            subtitle: t('ui_fine_no', LAW.str(x.id)) + ' · ' + LAW.str(x.targetName),
            fields: [
                { label: t('ui_f_reason'), value: LAW.str(x.reason, '–') },
                { label: t('ui_f_codes'), value: LG.codes(x.codes) || '–' },
                { label: t('ui_f_amount'), value: LAW.fmt.money(x.amount) },
                { label: t('ui_f_created'), value: LAW.fmt.date(x.createdAt) },
                { label: t('ui_f_due'), value: LAW.fmt.date(x.dueAt) },
                { label: t('ui_f_status'), value: LAW.str(x.statusLabel, x.status) },
            ],
            body: t('ui_doc_ticket_body'),
            footer: LAW.str(x.deptLabel),
            seal: LG.officer && (LG.officer.seal || LG.officer.dept) ? (LG.officer.seal || LG.officer.dept) : 'sheriff',
            sealLabel: LAW.str(x.deptLabel),
            signature: LAW.str(x.officerName),
        };
    };

    // ==================================================================
    // jail
    // ==================================================================
    LG.tabs.jail = listDetail({
        icon: 'jail',
        perm: 'records_view',
        title: function () { return t('ui_tab_jail'); },
        idOf: function (x) { return x.charId; },
        load: function () { return LAW.cb('jail:list', [], { quiet: true }); },
        row: function (x) {
            return {
                icon: 'jail',
                title: LAW.str(x.name),
                sub: LAW.str(x.locationLabel, x.location) + ' · ' + t('ui_jail_left', LAW.fmt.duration(x.remaining)),
                right: [ui.chip(x.online ? t('ui_online') : t('ui_offline'), x.online ? 'good' : 'mute')],
            };
        },
        detail: function (x) {
            var btns = [];
            if (LG.can('jail_release')) {
                btns.push(LAW.btn(t('ui_jail_set_bail'), function () {
                    return LAW.dialog({
                        title: t('ui_jail_set_bail'),
                        text: LAW.str(x.name),
                        fields: [{ name: 'amount', type: 'money', label: t('ui_f_bail'), required: true, min: 0, default: x.bail || '' , help: t('ui_jail_bail_help') }],
                        okLabel: t('ui_save'),
                    }).then(function (v) { if (v) return LAW.cb('jail:setBail', [x.charId, v.amount]).then(after); });
                }, 'small'));
                btns.push(LAW.btn(t('ui_jail_adjust'), function () {
                    return LAW.dialog({
                        title: t('ui_jail_adjust'),
                        text: LAW.str(x.name),
                        fields: [{ name: 'minutes', type: 'number', label: t('ui_jail_adjust_minutes'), required: true, min: -600, max: 600, help: t('ui_jail_adjust_help') }],
                        okLabel: t('ui_save'),
                    }).then(function (v) {
                        if (!v || !v.minutes) return;
                        return LAW.cb('jail:adjust', [x.charId, Math.round(v.minutes)]).then(after);
                    });
                }, 'small'));
                btns.push(LAW.btn(t('ui_jail_release'), function () {
                    return ask(t('ui_confirm_release', LAW.str(x.name)), function () { return LAW.cb('jail:release', [x.charId]).then(after); });
                }, 'danger small'));
            }
            btns.push(fileBtn(x.charId));
            var total = LAW.num(x.sentence), served = LAW.num(x.served);
            var pct = total > 0 ? Math.max(0, Math.min(100, (served / total) * 100)) : 0;
            return {
                title: LAW.str(x.name),
                sub: LAW.str(x.locationLabel, x.location),
                kids: [
                    el('div', 'meter', [el('div', { cls: 'meter__bar', style: { width: pct.toFixed(1) + '%' } })]),
                    LG.kvs([
                        [t('ui_f_sentence'), LAW.fmt.duration(x.sentence)],
                        [t('ui_f_served'), LAW.fmt.duration(x.served)],
                        [t('ui_f_remaining'), LAW.fmt.duration(x.remaining)],
                        [t('ui_f_reason'), LAW.str(x.reason)],
                        [t('ui_f_officer'), LAW.str(x.officerName)],
                        [t('ui_f_bail'), x.bail ? LAW.fmt.money(x.bail) : t('ui_none')],
                        [t('ui_f_status'), x.online ? t('ui_online') : t('ui_offline')],
                    ]),
                    ui.actions(btns),
                ],
            };
        },
        emptyKey: 'ui_jail_none',
    });

    // ==================================================================
    // evidence
    // ==================================================================
    var EV_ICON = { casing: 'gun', blood: 'warning', cloth: 'flag', scent: 'dog' };
    var evSeq = 0;

    function evidenceDoc(e) {
        var a = LAW.obj(e.analysis);
        var fields = [
            { label: t('ui_f_kind'), value: LAW.str(e.typeLabel, e.type) },
            { label: t('ui_f_zone'), value: LAW.str(e.zone, '–') },
            { label: t('ui_f_collected_by'), value: LAW.str(e.collectedByName, '–') },
            { label: t('ui_f_collected_at'), value: LAW.fmt.date(e.collectedAt) },
        ];
        if (e.weaponLabel) fields.push({ label: t('ui_f_weapon'), value: String(e.weaponLabel) });
        if (e.serial) fields.push({ label: t('ui_serial'), value: String(e.serial) });
        if (e.bloodType) fields.push({ label: t('ui_file_blood'), value: String(e.bloodType) });
        var lines = [];
        if (a.summary) lines.push(String(a.summary));
        LAW.arr(a.lines).forEach(function (l) { lines.push('– ' + String(l)); });
        if (a.match && a.match.name) lines.push(t('ui_ev_match', String(a.match.name)));
        return {
            kind: 'evidence',
            title: t('ui_doc_evidence_title'),
            subtitle: t('ui_evidence_no', LAW.str(e.id)),
            fields: fields,
            body: lines.length ? lines.join('\n') : t('ui_ev_not_analyzed'),
            footer: LAW.str(e.statusLabel, e.status),
            seal: LG.officer.seal || LG.officer.dept,
            sealLabel: LG.officer.deptLabel,
            signature: LAW.str(a.analyzedByName, LAW.str(e.analyzedByName, LAW.str(e.collectedByName))),
        };
    }

    function evidenceDetail(e) {
        e = LAW.obj(e);
        var a = e.analysis ? LAW.obj(e.analysis) : null;
        var btns = [];
        if ((e.status === 'collected' || e.status === 'analyzed') && LG.can('evidence_analyze')) {
            btns.push(LAW.btn(t('ui_ev_destroy'), function () {
                return ask(t('ui_confirm_destroy_evidence', LAW.str(e.id)), function () { return LAW.cb('evidence:destroy', [e.id]).then(after); });
            }, 'danger small'));
        }
        if (e.serial && LG.allowed('weapons')) btns.push(LAW.btn(t('ui_ev_lookup_serial'), function () { LG.go('weapons', { serial: e.serial }); }, 'ghost small'));
        btns.push(docBtn(t('ui_view_document'), evidenceDoc(e)));
        var match = a && a.match ? LAW.obj(a.match) : null;
        return [
            el('div', 'detail__status', [ui.status(e.status, e.statusLabel)]),
            LG.kvs([
                [t('ui_f_kind'), LAW.str(e.typeLabel, e.type)],
                [t('ui_f_zone'), LAW.str(e.zone)],
                [t('ui_f_created'), e.createdAt ? LAW.fmt.date(e.createdAt) : null],
                [t('ui_f_collected_by'), LAW.str(e.collectedByName)],
                [t('ui_f_collected_at'), e.collectedAt ? LAW.fmt.date(e.collectedAt) : null],
                [t('ui_f_weapon'), LAW.str(e.weaponLabel)],
                [t('ui_serial'), LAW.str(e.serial)],
                [t('ui_file_blood'), LAW.str(e.bloodType)],
                [t('ui_f_subject'), LAW.str(e.subjectName)],
                [t('ui_f_analyzed_by'), LAW.str(e.analyzedByName)],
            ]),
            a ? el('div', 'analysis', [
                el('div', { cls: 'analysis__h', text: t('ui_ev_analysis') }),
                a.summary ? el('div', { cls: 'analysis__sum', text: String(a.summary) }) : null,
                el('ul', 'analysis__lines', LAW.arr(a.lines).map(function (l) { return el('li', { text: String(l) }); })),
                match ? el('div', 'analysis__match', [
                    ui.icon('person'),
                    el('span', { text: t('ui_ev_match', LAW.str(match.name)) }),
                    LG.allowed('people') && match.charId !== undefined ? LAW.btn(t('ui_open_file'), function () { LG.openFile(match.charId); }, 'ghost small') : null,
                ]) : null,
            ]) : el('div', { cls: 'hint', text: t('ui_ev_not_analyzed') }),
            ui.actions(btns),
        ];
    }

    LG.tabs.evidence = listDetail({
        icon: 'search',
        perm: 'evidence',
        defaultFilter: 'current',
        title: function () { return t('ui_tab_evidence'); },
        filters: function () { return filters(['current', 'collected', 'analyzed', 'destroyed', 'all']); },
        // 'current' = Standard des Servers (alles ausser vernichtet) -> kein Filter senden
        load: function (f) { return LAW.cb('evidence:list', [f === 'current' ? null : f], { quiet: true }); },
        row: function (e) {
            return {
                icon: EV_ICON[e.type] || 'search',
                title: '#' + LAW.str(e.id) + ' · ' + LAW.str(e.typeLabel, e.type),
                sub: [LAW.str(e.zone), LAW.str(e.weaponLabel), LAW.str(e.serial)].filter(Boolean).join(' · '),
                meta: LAW.fmt.date(e.collectedAt || e.createdAt),
                right: [ui.status(e.status, e.statusLabel)],
            };
        },
        detail: function (e, tok) {
            // Liste liefert Kurzform -> volle Daten nachladen (nur die zuletzt angeklickte Zeile zeigen)
            var my = ++evSeq;
            LAW.cb('evidence:get', [e.id], { quiet: true }).then(function (res) {
                if (!LG.alive(tok) || my !== evSeq) return;
                if (!res.ok) { LG.setRight(t('ui_evidence_no', LAW.str(e.id)), '', [ui.empty('ui_load_failed')]); return; }
                LG.setRight(t('ui_evidence_no', LAW.str(e.id)), LAW.str(res.data && res.data.typeLabel, e.typeLabel), evidenceDetail(res.data));
            });
            return { title: t('ui_evidence_no', LAW.str(e.id)), sub: LAW.str(e.typeLabel), kids: [ui.loading()] };
        },
        emptyKey: 'ui_evidence_none',
    });

    // ==================================================================
    // weapons (Seriennummer-Suche)
    // ==================================================================
    var weapons = { serial: '', recent: [] };
    var WEAPON_STATUS = ['registered', 'stolen', 'confiscated', 'issued', 'destroyed'];

    function renderWeapon(w, tok) {
        w = LAW.obj(w);
        var btns = [];
        if (LG.can('weapons_registry')) {
            btns.push(LAW.btn(t('ui_weapons_set_status'), function () {
                return LAW.dialog({
                    title: t('ui_weapons_set_status'),
                    text: LAW.str(w.weaponLabel, w.weapon) + ' · ' + LAW.str(w.serial),
                    fields: [
                        { name: 'status', type: 'select', label: t('ui_f_status'), required: true, default: w.status,
                          options: WEAPON_STATUS.map(function (s) { return { value: s, label: t('ui_status_' + s) }; }) },
                        { name: 'note', type: 'text', label: t('ui_f_note'), maxLength: 200 },
                    ],
                    okLabel: t('ui_save'),
                }).then(function (v) {
                    if (!v) return;
                    return LAW.cb('weapons:setStatus', [w.serial, v.status, v.note || '']).then(function (res) { if (res.ok) lookup(w.serial, LG.token()); });
                });
            }, 'small'));
        }
        if (w.ownerCharId !== undefined && w.ownerCharId !== null) btns.push(fileBtn(w.ownerCharId));
        var holder = w.currentHolder ? LAW.obj(w.currentHolder) : null;
        LG.setRight(LAW.str(w.weaponLabel, w.weapon), t('ui_serial') + ' ' + LAW.str(w.serial), [
            el('div', 'detail__status', [ui.status(w.status, w.statusLabel)]),
            LG.kvs([
                [t('ui_f_weapon'), LAW.str(w.weaponLabel, w.weapon)],
                [t('ui_serial'), LAW.str(w.serial)],
                [t('ui_f_owner'), LAW.str(w.ownerName, t('ui_unknown'))],
                [t('ui_f_registered'), w.registeredAt ? LAW.fmt.date(w.registeredAt) : null],
                [t('ui_f_holder'), holder ? LAW.str(holder.name) : null],
                [t('ui_f_note'), LAW.str(w.notes)],
            ]),
            ui.h(t('ui_weapons_evidence'), 'h--small'),
            ui.list(w.evidence, function (e) {
                e = LAW.obj(e);
                return ui.row({
                    icon: EV_ICON[e.type] || 'search',
                    title: '#' + LAW.str(e.id) + ' · ' + LAW.str(e.typeLabel, e.type),
                    sub: [LAW.str(e.zone), LAW.fmt.date(e.createdAt)].filter(Boolean).join(' · '),
                    onClick: LG.allowed('evidence') ? function () { LG.go('evidence', { status: 'all', selId: e.id }); } : null,
                });
            }, 'ui_weapons_no_evidence'),
            ui.actions(btns),
        ]);
    }

    function renderRecent() {
        var box = $('lg-weapons-recent');
        if (!box) return;
        ui.fill(box, [ui.list(weapons.recent, function (r) {
            return ui.row({
                icon: 'gun',
                title: LAW.str(r.serial),
                sub: LAW.str(r.label),
                right: [ui.status(r.status, r.statusLabel)],
                active: r.serial === weapons.serial,
                onClick: function () { lookup(r.serial, LG.token()); },
            });
        }, 'ui_weapons_hint')]);
    }

    function lookup(serial, tok) {
        serial = String(serial || '').trim();
        if (serial.length < 2) { LAW.hint(t('ui_search_min'), 'error'); return Promise.resolve(); }
        weapons.serial = serial;
        LG.opts = { serial: serial };
        var my = weapons.seq = (weapons.seq || 0) + 1;
        LG.setRight(t('ui_tab_weapons'), serial, [ui.loading()]);
        return LAW.cb('weapons:lookup', [serial], { quiet: true }).then(function (res) {
            if (!LG.alive(tok) || my !== weapons.seq) return;
            if (!res.ok || !res.data) {
                LG.setRight(t('ui_tab_weapons'), serial, [ui.empty(res.err === 'not_found' || res.ok ? 'ui_weapons_not_found' : 'ui_load_failed'), res.msg ? el('div', { cls: 'hint', text: String(res.msg) }) : null]);
                return;
            }
            var w = LAW.obj(res.data);
            weapons.recent = weapons.recent.filter(function (r) { return r.serial !== LAW.str(w.serial, serial); });
            weapons.recent.unshift({ serial: LAW.str(w.serial, serial), label: LAW.str(w.weaponLabel, w.weapon), status: w.status, statusLabel: w.statusLabel });
            weapons.recent = weapons.recent.slice(0, 12);
            renderRecent();
            renderWeapon(w, tok);
        });
    }

    LG.tabs.weapons = {
        icon: 'gun',
        perm: 'weapons_registry',
        keep: function () { return { serial: weapons.serial }; },
        render: function (opts, tok) {
            var input = el('input', { cls: 'inp inp--mono', type: 'text', attrs: { maxlength: '50', placeholder: t('ui_weapons_ph') }, value: opts.serial || weapons.serial });
            input.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); lookup(input.value, LG.token()); } });
            LG.setLeft([
                ui.h(t('ui_weapons_search')),
                el('div', 'searchbar', [input, LAW.btn(t('ui_search'), function () { return lookup(input.value, LG.token()); }, 'small')]),
                ui.h(t('ui_weapons_recent'), 'h--small'),
                el('div', { cls: 'lg-list', attrs: { id: 'lg-weapons-recent' } }),
            ]);
            renderRecent();
            if (opts.serial) lookup(opts.serial, tok);
            else { LG.rightEmpty(t('ui_tab_weapons')); setTimeout(function () { input.focus(); }, 50); }
        },
    };

    // ==================================================================
    // escorts
    // ==================================================================
    var ESC_ICON = { bodyguard: 'shield', transport: 'wagon', cargo: 'box' };

    LG.escortKvs = function (x) {
        var names = LAW.arr(x.escorts);
        return LG.kvs([
            [t('ui_f_kind'), LAW.str(x.typeLabel, x.type)],
            [t('ui_f_client'), LAW.str(x.clientName)],
            [t('ui_f_recipient'), LAW.str(x.recipientName)],
            [t('ui_f_pickup'), LAW.str(x.pickupLabel, x.pickup)],
            [t('ui_f_destination'), LAW.str(x.destinationLabel, x.destination)],
            [t('ui_f_duration'), x.durationMin ? LAW.fmt.minutes(x.durationMin) : null],
            [t('ui_f_escorts'), names.length + ' / ' + LAW.num(x.escortsRequired, names.length)],
            [t('ui_f_leader'), LAW.str(x.leaderName)],
            [t('ui_f_price'), x.price !== undefined ? LAW.fmt.money(x.price) : null],
            [t('ui_f_payout'), x.payoutEstimate !== undefined && x.payoutEstimate !== null ? LAW.fmt.money(x.payoutEstimate) : null],
            [t('ui_f_insurance'), x.insurance ? t('ui_yes') : t('ui_no')],
            [t('ui_f_cargo'), LAW.str(x.cargoSummary)],
            [t('ui_f_created'), LAW.fmt.date(x.createdAt)],
            [t('ui_f_deadline'), x.deadlineAt ? LAW.fmt.date(x.deadlineAt) : null],
            [t('ui_f_claim_office'), LAW.str(x.claimOfficeLabel)],
            [t('ui_f_fail_reason'), LAW.str(x.reasonLabel)],
        ]);
    };

    // Versicherungsfaelle (Kasse zahlt nach Ueberfall) - nur mit boss_funds
    var INS_KIND = { pending: 'warn', paid: 'good', denied: 'bad', expired: 'mute' };
    function insState(x) {
        var s = LAW.str(x.state, 'pending');
        return ui.chip(LAW.str(x.stateLabel, LAW.has('ui_ins_state_' + s) ? t('ui_ins_state_' + s) : s), INS_KIND[s] || 'info');
    }
    function escortMode() { return LG.tabs.escorts.keep().status; }

    function insuranceDetail(x) {
        var btns = [];
        if (x.state === 'pending' && LG.can('boss_funds')) {
            btns.push(LAW.btn(t('ui_ins_pay'), function () {
                return LAW.confirm(t('ui_confirm_ins_pay', LAW.str(x.id), LAW.fmt.money(x.amount)), { okLabel: t('ui_ins_pay') }).then(function (ok) {
                    if (ok) return LAW.cb('escort:insuranceDecide', [x.id, true]).then(after);
                });
            }, 'primary small'));
            btns.push(LAW.btn(t('ui_ins_deny'), function () {
                return LAW.confirm(t('ui_confirm_ins_deny', LAW.str(x.id), LAW.fmt.money(x.amount)), { okLabel: t('ui_ins_deny') }).then(function (ok) {
                    if (ok) return LAW.cb('escort:insuranceDecide', [x.id, false]).then(after);
                });
            }, 'danger small'));
        }
        return {
            title: t('ui_ins_no', LAW.str(x.id)),
            sub: LAW.str(x.clientName),
            kids: [
                el('div', 'detail__status', [insState(x)]),
                el('div', 'bigmoney', [LAW.fmt.money(x.amount)]),
                LG.kvs([
                    [t('ui_f_client'), LAW.str(x.clientName)],
                    [t('ui_f_robbed_by'), LAW.str(x.robbedByName, t('ui_unknown'))],
                    [t('ui_f_pickup'), LAW.str(x.pickupLabel)],
                    [t('ui_f_destination'), LAW.str(x.destinationLabel)],
                    [t('ui_f_cargo'), LAW.str(x.cargoSummary)],
                    [t('ui_f_insured_value'), x.insuredValue !== undefined ? LAW.fmt.money(x.insuredValue) : null],
                    [t('ui_f_ins_amount'), LAW.fmt.money(x.amount)],
                    [t('ui_f_robbed_at'), x.robbedAt ? LAW.fmt.date(x.robbedAt) : null],
                ]),
                btns.length ? ui.actions(btns) : null,
            ],
        };
    }

    LG.tabs.escorts = listDetail({
        icon: 'wagon',
        perm: 'escort_contracts',
        defaultFilter: 'open',
        title: function () { return t('ui_tab_escorts'); },
        filters: function () {
            var f = [{ id: 'open', label: t('ui_escort_open') }, { id: 'mine', label: t('ui_escort_mine') }];
            if (LG.can('boss_funds')) f.push({ id: 'insurance', label: t('ui_escort_insurance') });
            return f;
        },
        load: function (f) {
            if (f === 'insurance') {
                if (!LG.can('boss_funds')) return Promise.resolve({ ok: true, data: [] });
                return LAW.cb('escort:insuranceList', [], { quiet: true });
            }
            return LAW.cb(f === 'mine' ? 'escort:listMine' : 'escort:listOpen', [], { quiet: true });
        },
        row: function (x) {
            if (escortMode() === 'insurance') {
                return {
                    icon: 'shield',
                    title: '#' + LAW.str(x.id) + ' · ' + LAW.str(x.clientName),
                    sub: LAW.str(x.pickupLabel) + (x.destinationLabel ? ' → ' + x.destinationLabel : '') + ' · ' + LAW.fmt.money(x.amount),
                    meta: x.robbedAt ? LAW.fmt.date(x.robbedAt) : null,
                    right: [insState(x)],
                };
            }
            return {
                icon: ESC_ICON[x.type] || 'wagon',
                title: '#' + LAW.str(x.id) + ' · ' + LAW.str(x.typeLabel, x.type),
                sub: LAW.str(x.pickupLabel, x.pickup) + (x.destinationLabel || x.destination ? ' → ' + LAW.str(x.destinationLabel, x.destination) : ''),
                meta: LAW.str(x.clientName),
                right: [ui.status(x.status, x.statusLabel)],
            };
        },
        detail: function (x) {
            var mode = escortMode();
            if (mode === 'insurance') return insuranceDetail(x);
            var btns = [];
            if (mode !== 'mine' && LG.can('escort_contracts') && !x.joined && !x.full) {
                btns.push(LAW.btn(t('ui_escort_accept'), function () {
                    return LAW.cb('escort:accept', [x.id]).then(function (res) {
                        if (res.ok) { LG.opts = { status: 'mine', selId: x.id }; LG.reload(false); }
                    });
                }, 'primary small'));
            }
            if (mode === 'mine') {
                btns.push(LAW.btn(t('ui_escort_leave'), function () {
                    return LAW.confirm(t('ui_confirm_escort_leave', LAW.str(x.id)), { danger: false }).then(function (ok) {
                        if (ok) return LAW.cb('escort:leave', [x.id]).then(after);
                    });
                }, 'ghost small'));
            }
            return {
                title: LAW.str(x.typeLabel, x.type) + ' #' + LAW.str(x.id),
                sub: LAW.str(x.pickupLabel, x.pickup) + (x.destinationLabel ? ' → ' + x.destinationLabel : ''),
                kids: [
                    el('div', 'detail__status', [ui.status(x.status, x.statusLabel)]),
                    LG.escortKvs(x),
                    LAW.arr(x.escorts).length ? el('div', { cls: 'hint', text: t('ui_escort_members', LAW.arr(x.escorts).join(', ')) }) : null,
                    ui.actions(btns),
                ],
            };
        },
        emptyKey: function () { return escortMode() === 'insurance' ? 'ui_ins_none' : 'ui_escorts_none'; },
    });

    // ==================================================================
    // department (Chef)
    // ==================================================================
    function reasonText(r) {
        r = LAW.str(r);
        return LAW.has('ui_reason_' + r) ? t('ui_reason_' + r) : r;
    }

    function renderDepartment(d, tok) {
        d = LAW.obj(d);
        var can = LAW.obj(d.can);
        var grades = LAW.arr(d.grades);
        var myGrade = d.myGrade === undefined || d.myGrade === null ? null : LAW.num(d.myGrade);
        var members = LAW.arr(d.members);

        var top = [];
        if (can.hire) top.push(LAW.btn(t('ui_dept_hire'), function () { return LG.openForm('hire', {}); }, 'primary small'));

        LG.setLeft([
            ui.h(t('ui_dept_members', members.length)),
            top.length ? ui.actions(top) : null,
            ui.list(members, function (m) {
                m = LAW.obj(m);
                var locked = myGrade !== null && LAW.num(m.grade) >= myGrade;
                var right = [];
                if (m.onDuty) right.push(ui.chip(t('ui_on_duty'), 'good'));
                else right.push(ui.chip(m.online ? t('ui_online') : t('ui_offline'), m.online ? 'info' : 'mute'));
                var btns = [];
                if (can.promote) {
                    btns.push(LAW.btn(t('ui_dept_grade'), function () {
                        var opts = grades.filter(function (g) { return myGrade === null || LAW.num(g.grade) < myGrade; })
                            .map(function (g) { return { value: LAW.num(g.grade), label: LAW.str(g.label, String(g.grade)) }; });
                        return LAW.dialog({
                            title: t('ui_dept_grade_title'),
                            text: LAW.str(m.name) + ' · ' + LAW.str(m.gradeLabel),
                            fields: [{ name: 'grade', type: 'select', label: t('ui_dept_new_grade'), required: true, default: LAW.num(m.grade), options: opts }],
                            okLabel: t('ui_save'),
                        }).then(function (v) {
                            if (!v || v.grade === undefined || LAW.num(v.grade) === LAW.num(m.grade)) return;
                            return LAW.cb('boss:setGrade', [m.charId, v.grade]).then(after);
                        });
                    }, 'ghost tiny', { disabled: locked }));
                }
                if (can.fire) {
                    btns.push(LAW.btn(t('ui_dept_fire'), function () {
                        return ask(t('ui_confirm_fire', LAW.str(m.name)), function () { return LAW.cb('boss:fire', [m.charId]).then(after); });
                    }, 'danger tiny', { disabled: locked }));
                }
                var row = ui.row({
                    icon: 'person',
                    title: LAW.str(m.name),
                    sub: LAW.str(m.gradeLabel) + ' · ' + t('ui_dept_hours', LAW.num(m.dutyHours7d).toFixed(1)),
                    right: right,
                });
                if (btns.length) row.appendChild(el('div', 'row__btns', btns));
                return row;
            }, 'ui_dept_no_members'),
        ]);

        var fundBtns = [];
        if (can.funds) {
            var money = function (cbName, titleKey, max) {
                return function () {
                    return LAW.dialog({
                        title: t(titleKey),
                        fields: [{ name: 'amount', type: 'money', label: t('ui_f_amount'), required: true, min: 0.01, max: max }],
                        okLabel: t(titleKey),
                    }).then(function (v) {
                        if (!v) return;
                        return LAW.cb(cbName, [v.amount]).then(function (res) {
                            if (res.ok && res.data && res.data.balance !== undefined) $('lg-balance').textContent = LAW.fmt.money(res.data.balance);
                            return after(res);
                        });
                    });
                };
            };
            fundBtns.push(LAW.btn(t('ui_dept_deposit'), money('boss:deposit', 'ui_dept_deposit'), 'small'));
            fundBtns.push(LAW.btn(t('ui_dept_withdraw'), money('boss:withdraw', 'ui_dept_withdraw'), 'small'));
        }
        var log = LAW.arr(d.log);
        LG.setRight(LAW.str(d.deptLabel, LG.officer.deptLabel), t('ui_dept_treasury'), [
            el('div', 'treasury', [
                el('div', { cls: 'treasury__l', text: t('ui_dept_balance') }),
                el('div', { cls: 'treasury__v', text: LAW.fmt.money(d.balance), attrs: { id: 'lg-balance' } }),
            ]),
            fundBtns.length ? ui.actions(fundBtns) : null,
            (can.logs || can.funds) ? ui.h(t('ui_dept_log'), 'h--small') : null,
            (can.logs || can.funds) ? el('div', 'cashbook', [
                el('div', 'cashbook__row cashbook__row--head', [
                    el('span', { text: t('ui_f_date') }), el('span', { text: t('ui_f_reason') }),
                    el('span', { text: t('ui_f_amount') }), el('span', { text: t('ui_dept_after') }),
                ]),
                log.length ? log.map(function (l) {
                    l = LAW.obj(l);
                    var amt = LAW.num(l.amount);
                    return el('div', 'cashbook__row', [
                        el('span', { cls: 'cashbook__date', text: LAW.fmt.date(l.createdAt) }),
                        el('span', { cls: 'cashbook__reason', text: reasonText(l.reason) + (l.actorName ? ' · ' + l.actorName : '') }),
                        el('span', { cls: 'cashbook__amt ' + (amt < 0 ? 'is-neg' : 'is-pos'), text: LAW.fmt.signedMoney(amt) }),
                        el('span', { cls: 'cashbook__bal', text: LAW.fmt.money(l.balanceAfter) }),
                    ]);
                }) : ui.empty('ui_dept_no_log'),
            ]) : null,
        ]);
    }

    LG.tabs.department = {
        icon: 'people',
        perm: function () { return LG.canBoss(); },
        keep: function () { return {}; },
        render: function (opts, tok) {
            LG.setRight(t('ui_tab_department'), '', [ui.loading()]);
            LAW.cb('boss:overview', [], { quiet: true }).then(function (res) {
                if (!LG.alive(tok)) return;
                if (!res.ok) { LG.setLeft([ui.empty('ui_load_failed')]); LG.setRight(t('ui_tab_department'), '', [el('div', { cls: 'hint', text: LAW.errText(res) })]); return; }
                renderDepartment(res.data, tok);
            });
        },
    };
})();
