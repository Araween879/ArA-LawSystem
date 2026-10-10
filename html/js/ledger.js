/*
    ArA-LawSystem - Dienstbuch `ledger` (Vertrag 10.5)
    Rahmen (Reiter, Seiten, Kopfzeile) + Tabs "overview" und "people".
    Die uebrigen Tabs stehen in ledger_tabs.js und haengen sich an LAW.Ledger.tabs.
*/
(function () {
    'use strict';
    var LAW = window.LAW;
    var el = LAW.el, t = LAW.t, $ = LAW.$, ui = LAW.ui;

    var ORDER = ['overview', 'people', 'warrants', 'bounties', 'fines', 'jail', 'evidence', 'weapons', 'escorts', 'department'];
    var BOSS = ['boss_hire', 'boss_fire', 'boss_promote', 'boss_funds', 'boss_logs'];

    var LG = LAW.Ledger = {
        officer: {},
        perms: [],
        tab: 'overview',
        opts: {},
        seq: 0,
        tabs: {},
    };

    // ------------------------------------------------------------------
    // Hilfen fuer die Tabs
    // ------------------------------------------------------------------
    LG.can = function (perm) { return LAW.hasPerm(LG.perms, perm); };
    LG.canBoss = function () { return LAW.hasAnyPerm(LG.perms, BOSS); };

    LG.allowed = function (tab) {
        var def = LG.tabs[tab];
        if (!def) return false;
        if (!def.perm) return true;
        if (typeof def.perm === 'function') return !!def.perm();
        return LG.can(def.perm);
    };

    /** Token gegen veraltete Antworten (Tab gewechselt, waehrend der Server antwortet) */
    LG.token = function () { return LG.seq; };
    LG.alive = function (tok) { return tok === LG.seq && LAW.isOpen('ledger'); };

    LG.setLeft = function (kids) { ui.fill($('lg-left'), kids); $('lg-left').scrollTop = 0; };
    LG.setRight = function (title, sub, kids) {
        ui.fill($('lg-right-title'), [LAW.str(title)]);
        ui.fill($('lg-right-sub'), [LAW.str(sub)]);
        ui.fill($('lg-right'), kids);
        $('lg-right').scrollTop = 0;
    };
    LG.rightEmpty = function (title) {
        LG.setRight(title || t('ui_tab_' + LG.tab), '', [el('div', 'page-empty', [ui.icon('pen', 'page-empty__icon'), el('div', { text: t('ui_select_entry') })])]);
    };

    /** Formular ueber Lua oeffnen (Vertrag 10.5: action ledger:openForm) und danach neu laden */
    LG.openForm = function (form, extra) {
        var payload = Object.assign({ form: form }, extra || {});
        return LAW.action('ledger', 'openForm', payload).then(function (res) {
            if (LAW.isOpen('ledger')) LG.reload(true);
            return res;
        });
    };

    LG.waypoint = function (coords) {
        coords = LAW.obj(coords);
        if (coords.x === undefined || coords.y === undefined) return Promise.resolve({ ok: false });
        return LAW.action('ledger', 'setWaypoint', { x: LAW.num(coords.x), y: LAW.num(coords.y), z: LAW.num(coords.z) }, { quiet: true }).then(function (res) {
            if (res.ok) LAW.hint(t('ui_waypoint_set'), 'success');
            return res;
        });
    };

    LG.openFile = function (charId) {
        if (!LG.allowed('people')) return;
        LG.go('people', { charId: charId });
    };

    /** Codes (Bussgeld/Haftbefehl) lesbar machen: [{id,label,count}] | [string] | string */
    LG.codes = function (codes) {
        if (typeof codes === 'string') return codes;
        var list = LAW.arr(codes);
        return list.map(function (c) {
            if (c && typeof c === 'object') return (LAW.num(c.count, 1) > 1 ? c.count + '× ' : '') + LAW.str(c.label, LAW.str(c.id));
            return String(c);
        }).join(', ');
    };

    LG.kvs = function (pairs) {
        return el('div', 'kvs', pairs.filter(function (p) { return p && p[1] !== undefined && p[1] !== null && p[1] !== ''; }).map(function (p) { return ui.kv(p[0], p[1]); }));
    };

    // ------------------------------------------------------------------
    // Rahmen
    // ------------------------------------------------------------------
    function renderHead() {
        var o = LG.officer;
        ui.fill($('lg-head'), [
            el('div', 'lg-head__badge', [ui.badgeImg(o.seal || o.dept)]),
            el('div', 'lg-head__txt', [
                el('div', { cls: 'lg-head__name', text: LAW.str(o.name) }),
                el('div', { cls: 'lg-head__rank', text: [LAW.str(o.gradeLabel), LAW.str(o.deptLabel)].filter(Boolean).join(' · ') }),
                el('div', 'lg-head__meta', [
                    o.badgeNumber ? el('span', { cls: 'lg-head__no', text: t('ui_badge_number') + ' ' + o.badgeNumber }) : null,
                    o.onDuty === undefined ? null : ui.chip(o.onDuty ? t('ui_on_duty') : t('ui_off_duty'), o.onDuty ? 'good' : 'mute'),
                ]),
            ]),
        ]);
    }

    function renderTabs() {
        var bar = LAW.clear($('lg-tabs'));
        ORDER.forEach(function (name) {
            if (!LG.allowed(name)) return;
            var def = LG.tabs[name];
            var b = el('button', { cls: 'lg-tab' + (name === LG.tab ? ' is-active' : ''), type: 'button', title: t('ui_tab_' + name) });
            var ic = ui.icon(def.icon || 'doc', 'lg-tab__icon');
            if (ic) b.appendChild(ic);
            b.appendChild(el('span', { cls: 'lg-tab__label', text: t('ui_tab_' + name) }));
            b.addEventListener('click', function () { if (name !== LG.tab) LG.go(name, {}); });
            bar.appendChild(b);
        });
    }

    LG.go = function (tab, opts) {
        if (!LG.allowed(tab)) tab = 'overview';
        LG.tab = tab;
        LG.opts = opts || {};
        LG.seq++;
        renderTabs();
        var def = LG.tabs[tab];
        LG.setLeft([ui.loading()]);
        LG.rightEmpty();
        try { def.render(LG.opts, LG.token()); } catch (err) { LAW.logError(err); LG.setLeft([ui.empty('ui_load_failed')]); }
    };

    /** Aktuellen Tab neu laden (keep = Auswahl behalten) */
    LG.reload = function (keep) {
        var def = LG.tabs[LG.tab];
        if (!def) return;
        LG.seq++;
        var opts = keep && def.keep ? def.keep() : LG.opts;
        try { def.render(opts || {}, LG.token()); } catch (err) { LAW.logError(err); }
    };

    var alertTimer = null;

    LAW.register('ledger', {
        root: null,
        setup: function () {
            this.root = $('app-ledger');
            $('lg-close').addEventListener('click', function () { LAW.closeLayer('ledger', 'cancel'); });
        },
        open: function (d) {
            LG.officer = LAW.obj(d.officer);
            LG.perms = LAW.arr(LG.officer.perms);
            renderHead();
            var tab = LAW.str(d.tab, 'overview');
            if (d.focusCharId !== undefined && d.focusCharId !== null && LG.allowed('people')) {
                LG.go('people', { charId: d.focusCharId });
            } else {
                LG.go(tab, {});
            }
        },
        update: function (d) {
            if (d.officer) { LG.officer = LAW.obj(d.officer); LG.perms = LAW.arr(LG.officer.perms); renderHead(); renderTabs(); }
            if (d.alertsChanged && LG.tab === 'overview') {
                clearTimeout(alertTimer);
                alertTimer = setTimeout(function () { if (LAW.isOpen('ledger') && LG.tab === 'overview') LG.reload(true); }, 350);
            }
            if (d.tab) LG.go(String(d.tab), d.focusCharId ? { charId: d.focusCharId } : {});
            else if (d.focusCharId) LG.go('people', { charId: d.focusCharId });
        },
        onHide: function () { LG.seq++; clearTimeout(alertTimer); },
    });

    // ==================================================================
    // TAB: overview
    // ==================================================================
    var KIND_ICON = { citizen: 'person', panic: 'bell', shots: 'gun', escape: 'jail', robbery: 'box', npc: 'skull', escort: 'wagon', bounty: 'skull', system: 'flag' };
    var PRIO_KIND = { 1: 'info', 2: 'warn', 3: 'bad' };

    function statTile(icon, value, labelKey) {
        return el('div', 'stat', [ui.icon(icon, 'stat__icon'), el('div', { cls: 'stat__v', text: value }), el('div', { cls: 'stat__l', text: t(labelKey) })]);
    }

    function alertCard(a) {
        a = LAW.obj(a);
        var prio = Math.max(1, Math.min(3, LAW.num(a.priority, 1)));
        var responders = LAW.arr(a.responders);
        var now = Date.now() / 1000;
        var card = el('div', 'alert alert--p' + prio + (a.mine ? ' is-mine' : ''));
        LAW.append(card, [
            el('div', 'alert__head', [
                ui.icon(KIND_ICON[a.kind] || 'flag', 'alert__icon'),
                el('span', { cls: 'alert__id', text: '#' + LAW.str(a.id) }),
                el('span', { cls: 'alert__title', text: LAW.str(a.title) }),
                ui.chip(t('ui_prio_' + prio), PRIO_KIND[prio]),
            ]),
            a.text ? el('div', { cls: 'alert__text', text: String(a.text) }) : null,
            el('div', { cls: 'alert__meta', text: [
                a.zone ? String(a.zone) : null,
                LAW.fmt.date(a.createdAt),
                a.expiresAt ? t('ui_ov_expires_in', LAW.fmt.duration(LAW.num(a.expiresAt) - now)) : null,
            ].filter(Boolean).join(' · ') }),
            el('div', { cls: 'alert__resp', text: responders.length ? t('ui_ov_responders', responders.join(', ')) : t('ui_ov_no_responders') }),
        ]);
        var btns = [];
        if (LG.can('dispatch')) {
            if (!a.mine) {
                btns.push(LAW.btn(t('ui_ov_accept'), function () {
                    return LAW.cb('dispatch:accept', [a.id]).then(function (res) {
                        if (!res.ok) return;
                        LAW.hint(t('ui_ov_accepted', a.id), 'success');
                        var c = res.data && res.data.coords ? res.data.coords : a.coords;
                        LG.waypoint(c);
                        LG.reload(true);
                    });
                }, 'primary small'));
            } else {
                btns.push(LAW.btn(t('ui_ov_route'), function () { return LG.waypoint(a.coords); }, 'small'));
            }
            btns.push(LAW.btn(t('ui_ov_close'), function () {
                return LAW.cb('dispatch:close', [a.id]).then(function (res) {
                    if (res.ok) { LAW.hint(t('ui_ov_closed', a.id), 'success'); LG.reload(true); }
                });
            }, 'ghost small'));
        }
        if (btns.length) card.appendChild(ui.actions(btns));
        return card;
    }

    LG.tabs.overview = {
        icon: 'book',
        perm: null,
        keep: function () { return {}; },
        render: function (opts, tok) {
            LG.setRight(t('ui_ov_alerts'), '', [ui.loading()]);
            LAW.cb('core:ledgerOverview', [], { quiet: true }).then(function (res) {
                if (!LG.alive(tok)) return;
                if (!res.ok) { LG.setLeft([ui.empty('ui_load_failed')]); LG.setRight(t('ui_ov_alerts'), '', [ui.empty('ui_load_failed')]); return; }
                var d = LAW.obj(res.data);
                var st = LAW.obj(d.stats);
                var onDuty = LAW.arr(d.onDuty);
                var now = Date.now() / 1000;
                var tiles = [
                    statTile('doc', String(LAW.num(st.openWarrants)), 'ui_ov_stat_warrants'),
                    statTile('skull', String(LAW.num(st.activeBounties)), 'ui_ov_stat_bounties'),
                    statTile('jail', String(LAW.num(st.inmates)), 'ui_ov_stat_inmates'),
                    statTile('wagon', String(LAW.num(st.openEscorts)), 'ui_ov_stat_escorts'),
                ];
                if (st.balance !== undefined && st.balance !== null) tiles.push(statTile('money', LAW.fmt.money(st.balance), 'ui_ov_stat_balance'));
                LG.setLeft([
                    ui.h(t('ui_ov_figures')),
                    el('div', 'stats', tiles),
                    ui.h(t('ui_ov_on_duty', onDuty.length)),
                    ui.list(onDuty, function (o) {
                        o = LAW.obj(o);
                        return ui.row({
                            icon: 'badge',
                            title: LAW.str(o.name),
                            sub: [LAW.str(o.gradeLabel), LAW.str(o.deptLabel)].filter(Boolean).join(' · '),
                            right: o.since ? [el('span', { cls: 'row__time', text: t('ui_ov_since', LAW.fmt.duration(now - LAW.num(o.since))) })] : null,
                        });
                    }, 'ui_ov_nobody'),
                ]);
                var alerts = LAW.arr(d.alerts);
                var right = [];
                if (!alerts.length) {
                    right.push(ui.empty(LG.officer.onDuty === false ? 'ui_ov_alerts_offduty' : 'ui_ov_no_alerts'));
                } else {
                    alerts.forEach(function (a) { right.push(alertCard(a)); });
                }
                LG.setRight(t('ui_ov_alerts'), t('ui_ov_alerts_count', alerts.length), right);
            });
        },
    };

    // ==================================================================
    // TAB: people (Akten)
    // ==================================================================
    var people = { query: '', hits: null, charId: null, section: 'records' };

    function searchPeople(tok) {
        var q = people.query.trim();
        if (q.length < 2) { LAW.hint(t('ui_search_min'), 'error'); return Promise.resolve(); }
        var box = $('lg-people-hits');
        if (box) ui.fill(box, [ui.loading()]);
        return LAW.cb('records:search', [q], { quiet: true }).then(function (res) {
            if (!LG.alive(tok)) return;
            people.hits = res.ok ? LAW.arr(res.data) : [];
            renderHits();
        });
    }

    function renderHits() {
        var box = $('lg-people-hits');
        if (!box) return;
        if (people.hits === null) { ui.fill(box, [ui.empty('ui_people_hint')]); return; }
        ui.fill(box, [ui.list(people.hits, function (h) {
            h = LAW.obj(h);
            return ui.row({
                icon: 'person',
                title: LAW.str(h.name),
                sub: [h.age ? t('ui_age', h.age) : null, h.gender ? String(h.gender) : null].filter(Boolean).join(' · '),
                right: [ui.flags(h.flags)],
                active: String(h.charId) === String(people.charId),
                onClick: function () { loadFile(h.charId, LG.token()); },
            });
        }, 'ui_people_none')]);
    }

    function fileSection(f, name) {
        switch (name) {
            case 'records':
                return ui.list(f.records, function (r) {
                    r = LAW.obj(r);
                    var row = ui.row({
                        cls: 'row--record',
                        title: LAW.str(r.title),
                        sub: [LAW.str(r.typeLabel, r.type), LAW.str(r.officerName), LAW.str(r.deptLabel)].filter(Boolean).join(' · '),
                        meta: r.details ? String(r.details) : null,
                        right: [el('span', { cls: 'row__time', text: LAW.fmt.date(r.createdAt) })],
                    });
                    row.addEventListener('click', function () { row.classList.toggle('is-open'); });
                    return row;
                }, 'ui_file_no_records');
            case 'fines':
                return ui.list(f.fines, function (x) {
                    x = LAW.obj(x);
                    return ui.row({
                        title: LAW.str(x.reason, LG.codes(x.codes)),
                        sub: [LAW.fmt.money(x.amount), LAW.str(x.officerName), LAW.fmt.day(x.createdAt)].filter(Boolean).join(' · '),
                        right: [ui.status(x.status, x.statusLabel)],
                        onClick: LG.allowed('fines') ? function () { LG.go('fines', { status: 'all', selId: x.id }); } : null,
                    });
                }, 'ui_file_no_fines');
            case 'warrants':
                return ui.list(f.warrants, function (x) {
                    x = LAW.obj(x);
                    return ui.row({
                        title: LAW.str(x.reason, LG.codes(x.codes)),
                        sub: [x.jailMinutes ? LAW.fmt.minutes(x.jailMinutes) : null, ui.deadOrAlive(x.deadOrAlive), LAW.fmt.day(x.createdAt)].filter(Boolean).join(' · '),
                        right: [ui.status(x.status, x.statusLabel)],
                        onClick: LG.allowed('warrants') ? function () { LG.go('warrants', { status: 'all', selId: x.id }); } : null,
                    });
                }, 'ui_file_no_warrants');
            case 'bounties':
                return ui.list(f.bounties, function (x) {
                    x = LAW.obj(x);
                    return ui.row({
                        title: LAW.fmt.money(x.amount) + ' · ' + LAW.str(x.reason),
                        sub: [t('ui_bounty_kind_' + LAW.str(x.kind, 'official')), ui.deadOrAlive(x.deadOrAlive), LAW.fmt.day(x.createdAt)].join(' · '),
                        right: [ui.status(x.status, x.statusLabel)],
                        onClick: LG.allowed('bounties') ? function () { LG.go('bounties', { status: 'all', selId: x.id }); } : null,
                    });
                }, 'ui_file_no_bounties');
            case 'weapons':
                return ui.list(f.weapons, function (x) {
                    x = LAW.obj(x);
                    return ui.row({
                        icon: 'gun',
                        title: LAW.str(x.weaponLabel, x.weapon),
                        sub: t('ui_serial') + ' ' + LAW.str(x.serial, '–'),
                        right: [ui.status(x.status, x.statusLabel)],
                        onClick: LG.allowed('weapons') && x.serial ? function () { LG.go('weapons', { serial: x.serial }); } : null,
                    });
                }, 'ui_file_no_weapons');
            case 'licenses':
                return ui.list(f.licenses, function (x) {
                    x = LAW.obj(x);
                    var type = LAW.str(x.type);
                    var row = ui.row({
                        icon: type === 'weapon' ? 'gun' : 'skull',
                        title: LAW.has('ui_license_' + type) ? t('ui_license_' + type) : type,
                        sub: x.expiresAt ? t('ui_valid_until', LAW.fmt.day(x.expiresAt)) : null,
                        right: [ui.status(x.status, x.statusLabel)],
                    });
                    // Kopfgeldjaeger-Lizenz entziehen (A: bounty:revokeLicense, Recht license_manage)
                    if (type === 'bounty' && x.status === 'active' && LG.can('license_manage')) {
                        row.appendChild(el('div', 'row__btns', [LAW.btn(t('ui_file_revoke_license'), function () {
                            return LAW.confirm(t('ui_confirm_revoke_license', LAW.str(f.name))).then(function (ok) {
                                if (!ok) return;
                                return LAW.cb('bounty:revokeLicense', [f.charId]).then(function (res) {
                                    if (res.ok) { people.section = 'licenses'; loadFile(f.charId, LG.token()); }
                                });
                            });
                        }, 'danger tiny')]));
                    }
                    return row;
                }, 'ui_file_no_licenses');
        }
        return null;
    }

    function renderFile(f) {
        f = LAW.obj(f);
        var flags = LAW.obj(f.flags);
        var jail = f.jail ? LAW.obj(f.jail) : null;
        var charId = f.charId;

        var actions = [];
        if (LG.can('fine')) actions.push(LAW.btn(t('ui_file_fine'), function () { return LG.openForm('fine', { charId: charId }); }, 'small'));
        if (LG.can('warrant_create')) actions.push(LAW.btn(t('ui_file_warrant'), function () { return LG.openForm('warrant', { charId: charId }); }, 'small'));
        if (LG.can('bounty_manage')) actions.push(LAW.btn(t('ui_file_bounty'), function () { return LG.openForm('bounty_official', { charId: charId }); }, 'small'));
        if (LG.can('records_edit')) {
            actions.push(LAW.btn(t('ui_file_note'), function () { return LG.openForm('note', { charId: charId }); }, 'small'));
            actions.push(LAW.btn(f.dangerous ? t('ui_file_undanger') : t('ui_file_danger'), function () {
                return LAW.cb('records:setDangerous', [charId, !f.dangerous]).then(function (res) { if (res.ok) loadFile(charId, LG.token()); });
            }, f.dangerous ? 'ghost small' : 'danger small'));
        }

        var sections = [
            { id: 'records', label: t('ui_file_sec_records') + ' (' + LAW.arr(f.records).length + ')' },
            { id: 'fines', label: t('ui_file_sec_fines') + ' (' + LAW.arr(f.fines).length + ')' },
            { id: 'warrants', label: t('ui_file_sec_warrants') + ' (' + LAW.arr(f.warrants).length + ')' },
            { id: 'bounties', label: t('ui_file_sec_bounties') + ' (' + LAW.arr(f.bounties).length + ')' },
            { id: 'weapons', label: t('ui_file_sec_weapons') + ' (' + LAW.arr(f.weapons).length + ')' },
            { id: 'licenses', label: t('ui_file_sec_licenses') + ' (' + LAW.arr(f.licenses).length + ')' },
        ];
        var secBox = el('div', 'file__sec');
        var showSec = function (id) { people.section = id; ui.fill(secBox, [fileSection(f, id)]); };

        LG.setRight(LAW.str(f.name), t('ui_file_no', LAW.str(charId)), [
            f.dangerous ? el('div', 'stamp stamp--danger', [t('ui_file_dangerous_stamp')]) : null,
            LG.kvs([
                [t('ui_file_age'), f.age ? String(f.age) : null],
                [t('ui_file_gender'), f.gender ? String(f.gender) : null],
                [t('ui_file_blood'), f.bloodType ? String(f.bloodType) : t('ui_file_no_sample')],
            ]),
            el('div', 'file__flags', [ui.flags(flags)]),
            jail ? el('div', 'file__jail', [
                ui.icon('jail'),
                el('span', { text: t('ui_file_in_jail', LAW.str(jail.locationLabel, jail.location), LAW.fmt.duration(jail.remaining)) }),
            ]) : null,
            f.notes ? el('div', 'file__notes', [el('div', { cls: 'file__notesh', text: t('ui_file_notes') }), el('div', { cls: 'file__notest', text: String(f.notes) })]) : null,
            actions.length ? ui.actions(actions) : null,
            ui.segmented(sections, people.section, showSec),
            secBox,
        ]);
        showSec(people.section);
    }

    function loadFile(charId, tok) {
        people.charId = charId;
        LG.opts = { charId: charId };
        var my = people.fileSeq = (people.fileSeq || 0) + 1;   // nur die zuletzt angeklickte Akte zeigen
        renderHits();
        LG.setRight(t('ui_file_title'), '', [ui.loading()]);
        return LAW.cb('records:getFile', [charId], { quiet: true }).then(function (res) {
            if (!LG.alive(tok) || my !== people.fileSeq) return;
            if (!res.ok) { LG.setRight(t('ui_file_title'), '', [ui.empty('ui_load_failed')]); return; }
            renderFile(res.data);
        });
    }

    LG.tabs.people = {
        icon: 'people',
        perm: 'records_view',
        keep: function () { return { charId: people.charId, keepHits: true }; },
        render: function (opts, tok) {
            if (!opts.keepHits) { people.hits = null; people.section = 'records'; }
            var input = el('input', { cls: 'inp', type: 'text', attrs: { maxlength: '60', placeholder: t('ui_people_search_ph') }, value: people.query });
            input.addEventListener('input', function () { people.query = input.value; });
            input.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); searchPeople(LG.token()); } });
            LG.setLeft([
                ui.h(t('ui_people_search')),
                el('div', 'searchbar', [input, LAW.btn(t('ui_search'), function () { return searchPeople(LG.token()); }, 'small')]),
                el('div', { cls: 'hits', attrs: { id: 'lg-people-hits' } }),
            ]);
            renderHits();
            if (opts.charId !== undefined && opts.charId !== null) loadFile(opts.charId, tok);
            else { people.charId = null; LG.rightEmpty(t('ui_file_title')); }
            setTimeout(function () { if (LG.tab === 'people' && !opts.charId) input.focus(); }, 50);
        },
    };
})();
