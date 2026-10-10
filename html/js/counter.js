/*
    ArA-LawSystem - Schalter `counter` (Vertrag 10.5)
    Reiter aus data.tabs: fines, bail, license, bounty, weapons, escort, property, report
*/
(function () {
    'use strict';
    var LAW = window.LAW;
    var el = LAW.el, t = LAW.t, $ = LAW.$, ui = LAW.ui;

    var ICON = { fines: 'money', bail: 'key', license: 'skull', bounty: 'flag', weapons: 'gun', escort: 'wagon', property: 'box', report: 'pen' };
    var KNOWN = ['fines', 'bail', 'license', 'bounty', 'weapons', 'escort', 'property', 'report'];

    var CT = LAW.Counter = { data: {}, tab: null, seq: 0, tabs: {} };

    function tok() { return CT.seq; }
    function alive(k) { return k === CT.seq && LAW.isOpen('counter'); }

    function cols(left, right) {
        ui.fill($('ct-sheet'), [el('div', 'ct-cols', [el('div', 'ct-col', left), el('div', 'ct-col ct-col--right', right)])]);
    }
    function colLeft() { return $('ct-sheet').querySelector('.ct-col'); }
    function colRight() { return $('ct-sheet').querySelector('.ct-col--right'); }

    function info(key) { return el('div', { cls: 'ct-info', text: t(key) }); }

    function sealKey() { return CT.data.seal || 'sheriff'; }

    /** Nach Erfolg den Schalter schliessen (vorp-Inventar braucht den Fokus) */
    function closeCounter() { LAW.closeLayer('counter', 'cancel'); }

    function renderTabs() {
        var bar = LAW.clear($('ct-tabs'));
        CT.list.forEach(function (name) {
            var b = el('button', { cls: 'ct-tab' + (name === CT.tab ? ' is-active' : ''), type: 'button' });
            var ic = ui.icon(ICON[name] || 'doc', 'ct-tab__icon');
            if (ic) b.appendChild(ic);
            b.appendChild(el('span', { cls: 'ct-tab__label', text: t('ui_ct_tab_' + name) }));
            b.addEventListener('click', function () { if (name !== CT.tab) CT.go(name); });
            bar.appendChild(b);
        });
    }

    CT.go = function (name) {
        CT.tab = name;
        CT.seq++;
        renderTabs();
        ui.fill($('ct-sheet'), [ui.loading()]);
        try { CT.tabs[name](tok()); } catch (err) { LAW.logError(err); ui.fill($('ct-sheet'), [ui.empty('ui_load_failed')]); }
    };
    CT.reload = function () { if (CT.tab) CT.go(CT.tab); };

    function after(res) { if (res && res.ok) CT.reload(); return res; }

    LAW.register('counter', {
        root: null,
        setup: function () {
            this.root = $('app-counter');
            $('ct-close').addEventListener('click', function () { LAW.closeLayer('counter', 'cancel'); });
        },
        open: function (d) {
            CT.data = d;
            var tabs = LAW.arr(d.tabs).map(String).filter(function (x) { return KNOWN.indexOf(x) >= 0; });
            CT.list = tabs.length ? tabs : ['fines', 'report'];
            $('ct-station').textContent = LAW.str(d.stationLabel, LAW.str(d.station));
            var c = LAW.obj(d.citizen);
            $('ct-citizen').textContent = c.name ? t('ui_ct_citizen', c.name) : '';
            CT.go(CT.list.indexOf(d.tab) >= 0 ? d.tab : CT.list[0]);
        },
        update: function (d) {
            Object.assign(CT.data, d);
            if (d.tab && CT.list.indexOf(d.tab) >= 0) CT.go(d.tab); else CT.reload();
        },
        onHide: function () { CT.seq++; clearTimeout(quoteTimer); },
    });

    // ==================================================================
    // fines
    // ==================================================================
    CT.tabs.fines = function (k) {
        LAW.cb('fines:mine', [], { quiet: true }).then(function (res) {
            if (!alive(k)) return;
            var list = res.ok ? LAW.arr(res.data) : [];
            var openSum = 0;
            list.forEach(function (f) { if (f.status === 'open' || f.status === 'overdue') openSum += LAW.num(f.amount); });
            cols([
                ui.h(t('ui_ct_fines_title')),
                res.ok ? ui.list(list, function (f) {
                    f = LAW.obj(f);
                    var payable = f.status === 'open' || f.status === 'overdue';
                    var row = ui.row({
                        icon: 'money',
                        title: LAW.fmt.money(f.amount) + ' · ' + LAW.str(f.reason, LAW.Ledger.codes(f.codes)),
                        sub: [LAW.str(f.deptLabel), LAW.str(f.officerName), t('ui_f_due') + ' ' + LAW.fmt.day(f.dueAt)].filter(Boolean).join(' · '),
                        right: [ui.status(f.status, f.statusLabel)],
                    });
                    var doc = LAW.Ledger.fineDocument(f);
                    doc.seal = sealKey();
                    var btns = [LAW.btn(t('ui_view_document'), function () { LAW.open('document', doc); }, 'ghost tiny')];
                    if (payable) {
                        btns.push(LAW.btn(t('ui_ct_pay'), function () {
                            return LAW.confirm(t('ui_confirm_pay_fine', LAW.fmt.money(f.amount)), { danger: false, okLabel: t('ui_ct_pay') }).then(function (ok) {
                                if (ok) return LAW.cb('fines:pay', [f.id]).then(after);
                            });
                        }, 'primary tiny'));
                    }
                    row.appendChild(el('div', 'row__btns', btns));
                    return row;
                }, 'ui_ct_fines_none') : ui.empty('ui_load_failed'),
            ], [
                el('div', 'ct-card', [
                    ui.icon('money', 'ct-card__icon'),
                    el('div', { cls: 'ct-card__l', text: t('ui_ct_fines_open_sum') }),
                    el('div', { cls: 'ct-card__v', text: LAW.fmt.money(openSum) }),
                ]),
                info('ui_ct_fines_info'),
            ]);
        });
    };

    // ==================================================================
    // bail
    // ==================================================================
    CT.tabs.bail = function (k) {
        LAW.cb('jail:bailList', [], { quiet: true }).then(function (res) {
            if (!alive(k)) return;
            cols([
                ui.h(t('ui_ct_bail_title')),
                res.ok ? ui.list(res.data, function (b) {
                    b = LAW.obj(b);
                    var row = ui.row({ icon: 'jail', title: LAW.str(b.name), sub: t('ui_f_bail') + ': ' + LAW.fmt.money(b.bail) });
                    row.appendChild(el('div', 'row__btns', [LAW.btn(t('ui_ct_pay_bail'), function () {
                        return LAW.confirm(t('ui_confirm_pay_bail', LAW.str(b.name), LAW.fmt.money(b.bail)), { okLabel: t('ui_ct_pay_bail') }).then(function (ok) {
                            if (ok) return LAW.cb('jail:payBail', [b.charId]).then(after);
                        });
                    }, 'primary tiny')]));
                    return row;
                }, 'ui_ct_bail_none') : ui.empty('ui_load_failed'),
            ], [info('ui_ct_bail_info')]);
        });
    };

    // ==================================================================
    // license
    // ==================================================================
    CT.tabs.license = function (k) {
        LAW.cb('bounty:licenseStatus', [], { quiet: true }).then(function (res) {
            if (!alive(k)) return;
            if (!res.ok) { cols([ui.empty('ui_load_failed')], []); return; }
            var s = LAW.obj(res.data);
            var active = !!s.active;
            var price = LAW.num(s.price), days = LAW.num(s.days);
            cols([
                ui.h(t('ui_ct_license_title')),
                el('div', 'license-card' + (active ? ' is-active' : ''), [
                    ui.seal(sealKey(), CT.data.stationLabel || '', 'license-card__seal'),
                    el('div', 'license-card__txt', [
                        el('div', { cls: 'license-card__state', text: active ? t('ui_ct_license_active') : t('ui_ct_license_none') }),
                        active && s.expiresAt ? el('div', { cls: 'license-card__exp', text: t('ui_valid_until', LAW.fmt.date(s.expiresAt)) }) : null,
                    ]),
                ]),
                ui.actions([LAW.btn(active ? t('ui_ct_license_renew', LAW.fmt.money(price), days) : t('ui_ct_license_buy', LAW.fmt.money(price), days), function () {
                    return LAW.confirm(t('ui_confirm_buy_license', LAW.fmt.money(price), days), { danger: false, okLabel: t('ui_ct_license_confirm') }).then(function (ok) {
                        if (ok) return LAW.cb('bounty:buyLicense', []).then(after);
                    });
                }, 'primary')]),
            ], [info('ui_ct_license_info')]);
        });
    };

    // ==================================================================
    // bounty (privates Kopfgeld)
    // ==================================================================
    var bounty = { q: '', hits: null, target: null };

    function bountyMine(k) {
        var box = $('ct-bounty-mine');
        LAW.cb('bounty:minePlaced', [], { quiet: true }).then(function (res) {
            if (!alive(k) || !box) return;
            ui.fill(box, [res.ok ? ui.list(res.data, function (b) {
                b = LAW.obj(b);
                var row = ui.row({
                    icon: 'skull',
                    title: LAW.str(b.targetName) + ' · ' + LAW.fmt.money(b.amount),
                    sub: [LAW.str(b.reason), ui.deadOrAlive(b.deadOrAlive), LAW.fmt.day(b.createdAt)].filter(Boolean).join(' · '),
                    right: [ui.status(b.status, b.statusLabel)],
                });
                if (b.status === 'pending' || b.status === 'active') {
                    row.appendChild(el('div', 'row__btns', [LAW.btn(t('ui_cancel_entry'), function () {
                        return LAW.confirm(t('ui_confirm_cancel_private', LAW.str(b.targetName))).then(function (ok) {
                            if (ok) return LAW.cb('bounty:cancelPrivate', [b.id]).then(after);
                        });
                    }, 'danger tiny')]));
                }
                return row;
            }, 'ui_ct_bounty_mine_none') : ui.empty('ui_load_failed')]);
        });
    }

    function bountyForm() {
        var box = $('ct-bounty-form');
        if (!box) return;
        if (!bounty.target) { ui.fill(box, [info('ui_ct_bounty_pick')]); return; }
        var fields = LAW.Fields.build([
            { name: 'amount', type: 'money', label: t('ui_f_amount'), required: true, min: 1 },
            { name: 'reason', type: 'text', label: t('ui_f_reason'), required: true, maxLength: 120 },
            { name: 'deadOrAlive', type: 'checkbox', label: t('ui_f_dead_or_alive'), placeholder: t('ui_dead_or_alive') },
        ], { compact: true });
        ui.fill(box, [
            el('div', 'ct-target', [ui.icon('person'), el('span', { text: LAW.str(bounty.target.name) })]),
            fields.node,
            ui.actions([LAW.btn(t('ui_ct_bounty_place'), function () {
                var r = fields.collect();
                if (!r.ok) { LAW.hint(r.msg, 'error'); return; }
                var v = r.values;
                return LAW.confirm(t('ui_confirm_place_bounty', LAW.str(bounty.target.name), LAW.fmt.money(v.amount))).then(function (ok) {
                    if (!ok) return;
                    return LAW.cb('bounty:placePrivate', [{ charId: bounty.target.charId, amount: v.amount, reason: v.reason, deadOrAlive: !!v.deadOrAlive }]).then(function (res) {
                        if (res.ok) { bounty.target = null; bounty.hits = null; CT.reload(); }
                    });
                });
            }, 'danger')]),
        ]);
    }

    function bountySearch(k) {
        var q = bounty.q.trim();
        if (q.length < 2) { LAW.hint(t('ui_search_min'), 'error'); return Promise.resolve(); }
        return LAW.cb('bounty:searchTarget', [q], { quiet: true }).then(function (res) {
            if (!alive(k)) return;
            bounty.hits = res.ok ? LAW.arr(res.data) : [];
            renderBountyHits();
        });
    }

    function renderBountyHits() {
        var box = $('ct-bounty-hits');
        if (!box) return;
        if (bounty.hits === null) { LAW.clear(box); return; }
        ui.fill(box, [ui.list(bounty.hits, function (h) {
            h = LAW.obj(h);
            return ui.row({
                icon: 'person', title: LAW.str(h.name),
                active: bounty.target && String(bounty.target.charId) === String(h.charId),
                onClick: function () { bounty.target = h; bountyForm(); },
            });
        }, 'ui_people_none')]);
    }

    CT.tabs.bounty = function (k) {
        var input = el('input', { cls: 'inp', type: 'text', attrs: { maxlength: '60', placeholder: t('ui_people_search_ph') }, value: bounty.q });
        input.addEventListener('input', function () { bounty.q = input.value; });
        input.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); bountySearch(tok()); } });
        cols([
            ui.h(t('ui_ct_bounty_title')),
            info('ui_ct_bounty_info'),
            el('div', 'searchbar', [input, LAW.btn(t('ui_search'), function () { return bountySearch(tok()); }, 'small')]),
            el('div', { cls: 'hits hits--short', attrs: { id: 'ct-bounty-hits' } }),
            el('div', { attrs: { id: 'ct-bounty-form' } }),
        ], [
            ui.h(t('ui_ct_bounty_mine')),
            el('div', { attrs: { id: 'ct-bounty-mine' } }, [ui.loading()]),
        ]);
        renderBountyHits();
        bountyForm();
        bountyMine(k);
    };

    // ==================================================================
    // weapons
    // ==================================================================
    CT.tabs.weapons = function (k) {
        LAW.cb('weapons:mine', [], { quiet: true }).then(function (res) {
            if (!alive(k)) return;
            cols([
                ui.h(t('ui_ct_weapons_title')),
                res.ok ? ui.list(res.data, function (w) {
                    w = LAW.obj(w);
                    var row = ui.row({
                        icon: 'gun',
                        title: LAW.str(w.weaponLabel, w.weapon),
                        sub: w.filed ? t('ui_ct_weapon_filed') : (w.serial ? t('ui_serial') + ' ' + w.serial : t('ui_ct_weapon_no_serial')),
                        right: [w.foreign ? ui.chip(t('ui_ct_weapon_foreign'), 'bad')
                            : w.status ? ui.status(w.status, w.statusLabel)
                            : ui.chip(LAW.str(w.statusLabel, t('ui_ct_weapon_unregistered')), 'warn')],
                    });
                    var btns = [];
                    // nur unregistrierte, eigene, nicht abgefeilte Waffen mit Seriennummer
                    if (!w.registered && !w.status && !w.foreign && !w.filed && w.serial) {
                        btns.push(LAW.btn(t('ui_ct_weapon_register'), function () { return LAW.cb('weapons:register', [w.id]).then(after); }, 'primary tiny'));
                    }
                    // Legaler Verkauf: eigene, registrierte Waffe, die man noch bei sich hat.
                    // Lua fragt nach dem Kaeufer in der Naehe und holt dessen Zustimmung ein.
                    if (w.registered && w.serial && w.status === 'registered' && !w.missing && w.id) {
                        btns.push(LAW.btn(t('ui_ct_weapon_transfer'), function () {
                            return LAW.action('counter', 'transferWeapon', { weaponId: w.id, serial: w.serial }).then(after);
                        }, 'ghost tiny'));
                    }
                    if (w.registered && w.serial && w.status !== 'stolen') {
                        btns.push(LAW.btn(t('ui_ct_weapon_stolen'), function () {
                            return LAW.confirm(t('ui_confirm_report_stolen', LAW.str(w.weaponLabel, w.weapon), LAW.str(w.serial)), { danger: false }).then(function (ok) {
                                if (ok) return LAW.cb('weapons:reportStolen', [w.serial]).then(after);
                            });
                        }, 'ghost tiny'));
                    }
                    if (btns.length) row.appendChild(el('div', 'row__btns', btns));
                    return row;
                }, 'ui_ct_weapons_none') : ui.empty('ui_load_failed'),
            ], [info('ui_ct_weapons_info')]);
        });
    };

    // ==================================================================
    // escort (Buchung mit Live-Preis)
    // ==================================================================
    var quoteTimer = null;

    function first(o, keys) {
        for (var i = 0; i < keys.length; i++) if (o[keys[i]] !== undefined && o[keys[i]] !== null) return o[keys[i]];
        return undefined;
    }

    /** Liste oder Tabelle-mit-Schluesseln -> [{...}] mit .key */
    function normList(x) {
        if (Array.isArray(x)) return x.map(function (o) { return o && typeof o === 'object' ? o : { key: o, label: String(o) }; });
        if (x && typeof x === 'object') {
            return Object.keys(x).map(function (k) {
                var v = x[k];
                return v && typeof v === 'object' ? Object.assign({ key: k }, v) : { key: k, label: String(v) };
            });
        }
        return [];
    }
    function keyOf(o) { return first(o, ['value', 'id', 'key', 'type', 'name', 'station']); }

    function escortMine(k) {
        var box = $('ct-escort-mine');
        LAW.cb('escort:mine', [], { quiet: true }).then(function (res) {
            if (!alive(k) || !box) return;
            ui.fill(box, [res.ok ? ui.list(res.data, function (x) {
                x = LAW.obj(x);
                var row = ui.row({
                    icon: 'wagon',
                    title: '#' + LAW.str(x.id) + ' · ' + LAW.str(x.typeLabel, x.type),
                    sub: LAW.str(x.pickupLabel, x.pickup) + (x.destinationLabel ? ' → ' + x.destinationLabel : '') + ' · ' + LAW.fmt.money(x.price),
                    right: [ui.status(x.status, x.statusLabel)],
                });
                // Versicherungsfall nach Ueberfall (Agent B / Review): insuranceState + insuranceAmount
                if (x.insuranceState) {
                    var s = String(x.insuranceState);
                    var sl = LAW.has('ui_ins_state_' + s) ? t('ui_ins_state_' + s) : s;
                    row.appendChild(el('div', { cls: 'hint' + (s === 'denied' ? ' hint--bad' : ''), text: t('ui_ct_escort_ins_state', sl, LAW.fmt.money(x.insuranceAmount)) }));
                }
                var btns = [];
                if (x.canClaim) {
                    btns.push(LAW.btn(t('ui_ct_escort_claim'), function () {
                        return LAW.cb('escort:claim', [x.id]).then(function (res2) { if (res2.ok) closeCounter(); });
                    }, 'primary tiny'));
                }
                if (x.status === 'open') {
                    btns.push(LAW.btn(t('ui_cancel_entry'), function () {
                        return LAW.confirm(t('ui_confirm_cancel_escort', LAW.str(x.id))).then(function (ok) {
                            if (ok) return LAW.cb('escort:cancel', [x.id]).then(after);
                        });
                    }, 'danger tiny'));
                }
                if (btns.length) row.appendChild(el('div', 'row__btns', btns));
                return row;
            }, 'ui_ct_escort_mine_none') : ui.empty('ui_load_failed')]);
        });
    }

    function renderQuote(q) {
        var box = $('ct-escort-quote');
        if (!box) return;
        if (!q) { ui.fill(box, [info('ui_ct_escort_quote_hint')]); return; }
        q = LAW.obj(q);
        ui.fill(box, [
            el('div', 'quote', [
                el('div', 'quote__lines', LAW.arr(q.breakdown).map(function (b) {
                    b = LAW.obj(b);
                    return el('div', 'quote__line', [el('span', { text: LAW.str(b.label) }), el('span', { text: LAW.fmt.money(b.amount) })]);
                })),
                ui.kv(t('ui_ct_escort_price'), LAW.fmt.money(q.price)),
                q.premium ? ui.kv(t('ui_ct_escort_premium'), LAW.fmt.money(q.premium)) : null,
                LAW.num(q.goldTotal) > 0 ? ui.kv(t('ui_ct_escort_gold'), t('ui_gold_amount', LAW.num(q.goldTotal).toFixed(2))) : null,
                q.deadlineMinutes ? ui.kv(t('ui_f_deadline'), LAW.fmt.minutes(q.deadlineMinutes)) : null,
                el('div', 'quote__total', [el('span', { text: t('ui_ct_escort_total') }), el('span', { text: LAW.fmt.money(q.total !== undefined ? q.total : LAW.num(q.price) + LAW.num(q.premium)) })]),
            ]),
        ]);
    }

    CT.tabs.escort = function (k) {
        LAW.cb('escort:options', [CT.data.station], { quiet: true }).then(function (res) {
            if (!alive(k)) return;
            if (!res.ok) { cols([ui.h(t('ui_ct_escort_title')), el('div', { cls: 'hint', text: LAW.errText(res) })], [ui.h(t('ui_ct_escort_mine')), el('div', { attrs: { id: 'ct-escort-mine' } })]); escortMine(k); return; }
            var o = LAW.obj(res.data);
            var types = normList(o.types);
            var dests = normList(o.destinations);
            var cargoItems = normList(o.cargoItems);
            var ins = LAW.obj(o.insurance);
            if (!types.length) types = [{ key: 'bodyguard' }, { key: 'transport' }, { key: 'cargo' }];

            var form = el('div', 'escort-form');
            var state = { type: keyOf(types[0]) };
            var inputs = {};

            function typeObj() { return types.filter(function (x) { return String(keyOf(x)) === String(state.type); })[0] || {}; }
            // Flags aus escort:options (Agent B): needsDuration, needsDestination, allowsCargo, allowsInsurance
            function isBodyguard() {
                var ty = typeObj();
                if (ty.needsDuration !== undefined) return !!ty.needsDuration;
                return String(state.type) === 'bodyguard' || !!ty.durations;
            }
            function isCargo() {
                var ty = typeObj();
                if (ty.allowsCargo !== undefined) return !!ty.allowsCargo;
                return String(state.type) === 'cargo';
            }
            function allowsInsurance() {
                var ty = typeObj();
                if (ty.allowsInsurance !== undefined) return !!ty.allowsInsurance;
                return isCargo();
            }

            function values() {
                var ty = typeObj();
                var v = { type: state.type, escorts: Math.round(LAW.num(inputs.escorts && inputs.escorts.value, first(ty, ['minEscorts', 'MinEscorts']) || 1)), insurance: !!(inputs.insurance && inputs.insurance.checked) };
                if (isBodyguard()) v.durationMin = LAW.num(inputs.duration && inputs.duration.value);
                else if (inputs.destination && inputs.destination.value !== '') v.destination = keyOf(dests[Number(inputs.destination.value)] || {});
                if (isCargo() && inputs.recipient && inputs.recipient.value.trim()) v.recipientName = inputs.recipient.value.trim();
                if (!allowsInsurance()) v.insurance = false;
                v.cargo = [];
                v.money = 0; v.gold = 0;
                if (isCargo()) {
                    (inputs.cargo || []).forEach(function (c) { var n = Math.max(0, Math.floor(LAW.num(c.input.value))); if (n > 0) v.cargo.push({ name: c.name, amount: n }); });
                    v.money = Math.max(0, Math.round(LAW.num(inputs.money && inputs.money.value) * 100) / 100);
                    v.gold = Math.max(0, Math.round(LAW.num(inputs.gold && inputs.gold.value) * 100) / 100);
                }
                return v;
            }

            function requestQuote() {
                clearTimeout(quoteTimer);
                quoteTimer = setTimeout(function () {
                    if (!alive(k)) return;
                    var v = values();
                    if (!isBodyguard() && v.destination === undefined) { renderQuote(null); return; }
                    LAW.cb('escort:quote', [v], { silent: true, quiet: true }).then(function (r) {
                        if (!alive(k)) return;
                        if (r.ok) renderQuote(r.data);
                        else ui.fill($('ct-escort-quote'), [el('div', { cls: 'hint hint--bad', text: LAW.errText(r) })]);
                    });
                }, 350);
            }

            function field(labelKey, node, help) {
                return el('div', 'field', [el('label', { cls: 'field__label', text: t(labelKey) }), node, help ? el('div', { cls: 'field__help', text: help }) : null]);
            }

            function build() {
                LAW.clear(form);
                inputs = {};
                var ty = typeObj();
                // Art
                var sel = el('select', 'inp inp--select');
                types.forEach(function (x) {
                    var key = keyOf(x);
                    var lbl = LAW.str(x.label, LAW.has('ui_esc_type_' + key) ? t('ui_esc_type_' + key) : String(key));
                    var op = el('option', { value: String(key), text: lbl });
                    if (String(key) === String(state.type)) op.selected = true;
                    sel.appendChild(op);
                });
                sel.addEventListener('change', function () { state.type = sel.value; build(); requestQuote(); });
                form.appendChild(field('ui_ct_escort_type', sel, ty.desc ? String(ty.desc) : null));

                if (isBodyguard()) {
                    var durs = LAW.arr(first(ty, ['durations', 'Durations'])).length ? LAW.arr(first(ty, ['durations', 'Durations'])) : [30, 60, 90, 120];
                    var ds = el('select', 'inp inp--select');
                    durs.forEach(function (m) { ds.appendChild(el('option', { value: String(m), text: LAW.fmt.minutes(m) })); });
                    inputs.duration = ds;
                    form.appendChild(field('ui_ct_escort_duration', ds));
                } else {
                    var dsel = el('select', 'inp inp--select');
                    dsel.appendChild(el('option', { value: '', text: t('ui_select_choose') }));
                    dests.forEach(function (x, i) {
                        var km = first(x, ['km', 'distance']);
                        var extra = km !== undefined ? ' (' + LAW.num(km).toFixed(1) + ' km)' : '';
                        dsel.appendChild(el('option', { value: String(i), text: LAW.str(x.label, String(keyOf(x))) + extra }));
                    });
                    inputs.destination = dsel;
                    form.appendChild(field('ui_ct_escort_destination', dsel));
                }

                var minE = LAW.num(first(ty, ['minEscorts', 'MinEscorts']), 1), maxE = LAW.num(first(ty, ['maxEscorts', 'MaxEscorts']), 4);
                var esc = el('input', { cls: 'inp', type: 'number', attrs: { min: String(minE), max: String(maxE), step: '1' }, value: String(minE) });
                inputs.escorts = esc;
                form.appendChild(field('ui_ct_escort_escorts', esc, t('ui_ct_escort_escorts_help', minE, maxE)));

                if (isCargo()) {
                    inputs.cargo = [];
                    var cbox = el('div', 'cargo');
                    if (!cargoItems.length) cbox.appendChild(ui.empty('ui_ct_escort_no_cargo'));
                    cargoItems.forEach(function (c) {
                        var name = String(first(c, ['name', 'item', 'value', 'key']));
                        var max = first(c, ['owned', 'count', 'have', 'max']);
                        var unit = c.unitValue !== undefined ? c.unitValue : (typeof c.value === 'number' ? c.value : undefined);
                        var inp = el('input', { cls: 'inp inp--tiny', type: 'number', attrs: { min: '0', step: '1', max: max !== undefined ? String(max) : null }, value: '0' });
                        inputs.cargo.push({ name: name, input: inp });
                        cbox.appendChild(el('div', 'cargo__row', [
                            el('span', { cls: 'cargo__l', text: LAW.str(c.label, name) }),
                            el('span', { cls: 'cargo__m', text: [unit !== undefined ? t('ui_ct_escort_unit', LAW.fmt.money(unit)) : null, max !== undefined ? t('ui_ct_escort_have', max) : null].filter(Boolean).join(' · ') }),
                            inp,
                        ]));
                    });
                    form.appendChild(field('ui_ct_escort_cargo', cbox));
                    var money = el('input', { cls: 'inp', type: 'number', attrs: { min: '0', step: '0.01' }, value: '0' });
                    var gold = el('input', { cls: 'inp', type: 'number', attrs: { min: '0', step: '0.01' }, value: '0' });
                    inputs.money = money; inputs.gold = gold;
                    form.appendChild(el('div', 'field-pair', [field('ui_ct_escort_money', money), field('ui_ct_escort_gold', gold)]));
                    // Empfaenger: exakter Vor- und Nachname, leer = man selbst
                    var rec = el('input', { cls: 'inp', type: 'text', attrs: { maxlength: '60', placeholder: t('ui_ct_escort_recipient_ph') } });
                    inputs.recipient = rec;
                    form.appendChild(field('ui_ct_escort_recipient', rec, t('ui_ct_escort_recipient_help')));
                }

                if (allowsInsurance() && ins.available !== false) {
                    var insBox = el('input', { type: 'checkbox' });
                    inputs.insurance = insBox;
                    var pct = first(ins, ['premiumPercent', 'PremiumPercent', 'percent']);
                    var cov = first(ins, ['coverage', 'Coverage']);
                    var insHelp = [pct !== undefined ? t('ui_ct_escort_ins_premium', Math.round(LAW.num(pct) * 100)) : null, cov !== undefined ? t('ui_ct_escort_ins_coverage', Math.round(LAW.num(cov) * 100)) : null].filter(Boolean).join(' · ');
                    form.appendChild(field('ui_ct_escort_insurance', el('label', 'check', [insBox, el('span', 'check__box'), el('span', { cls: 'check__l', text: t('ui_ct_escort_insure') })]), insHelp || null));
                    // Bargeld und Gold sind nicht versichert (Sicherheits-Review)
                    form.appendChild(el('div', { cls: 'hint', text: t('ui_ct_escort_ins_note') }));
                }

                form.appendChild(ui.actions([LAW.btn(t('ui_ct_escort_book'), function () {
                    var v = values();
                    if (!isBodyguard() && v.destination === undefined) { LAW.hint(t('ui_form_required', t('ui_ct_escort_destination')), 'error'); return; }
                    if (v.escorts < minE || v.escorts > maxE) { LAW.hint(t('ui_ct_escort_escorts_help', minE, maxE), 'error'); return; }
                    return LAW.cb('escort:quote', [v], { quiet: true }).then(function (q) {
                        if (!q.ok) return;
                        var total = q.data && q.data.total !== undefined ? q.data.total : LAW.num(q.data && q.data.price) + LAW.num(q.data && q.data.premium);
                        renderQuote(q.data);
                        return LAW.confirm(t('ui_confirm_book_escort', LAW.fmt.money(total)), { danger: false, okLabel: t('ui_ct_escort_book') }).then(function (ok) {
                            if (!ok) return;
                            return LAW.cb('escort:book', [v]).then(function (r) { if (r.ok) CT.reload(); });
                        });
                    });
                }, 'primary')]));
            }

            // einmal registrieren (build() baut nur den Inhalt neu)
            form.addEventListener('input', requestQuote);
            form.addEventListener('change', requestQuote);

            cols([ui.h(t('ui_ct_escort_title')), form], [
                ui.h(t('ui_ct_escort_quote')),
                el('div', { attrs: { id: 'ct-escort-quote' } }),
                ui.h(t('ui_ct_escort_mine'), 'h--small'),
                el('div', { attrs: { id: 'ct-escort-mine' } }, [ui.loading()]),
            ]);
            build();
            renderQuote(null);
            requestQuote();
            escortMine(k);
        });
    };

    // ==================================================================
    // property (Habseligkeiten)
    // ==================================================================
    CT.tabs.property = function (k) {
        LAW.cb('jail:propertyStatus', [], { quiet: true }).then(function (res) {
            if (!alive(k)) return;
            var has = res.ok && res.data && res.data.hasProperty;
            cols([
                ui.h(t('ui_ct_property_title')),
                el('div', 'ct-card', [
                    ui.icon('box', 'ct-card__icon'),
                    el('div', { cls: 'ct-card__v ct-card__v--text', text: !res.ok ? LAW.errText(res) : has ? t('ui_ct_property_yes') : t('ui_ct_property_no') }),
                ]),
                has ? ui.actions([LAW.btn(t('ui_ct_property_claim'), function () {
                    return LAW.cb('jail:claimProperty', []).then(function (r) { if (r.ok) closeCounter(); });
                }, 'primary')]) : null,
            ], [info('ui_ct_property_info')]);
        });
    };

    // ==================================================================
    // report (Anzeige erstatten)
    // ==================================================================
    CT.tabs.report = function () {
        var area = el('textarea', { cls: 'inp inp--area inp--letter', attrs: { rows: '8', maxlength: '500', placeholder: t('ui_ct_report_ph') } });
        var counter = el('div', { cls: 'field__help', text: '0 / 500' });
        area.addEventListener('input', function () { counter.textContent = area.value.length + ' / 500'; });
        cols([
            ui.h(t('ui_ct_report_title')),
            info('ui_ct_report_info'),
            area, counter,
            ui.actions([LAW.btn(t('ui_ct_report_send'), function () {
                var text = area.value.trim();
                if (text.length < 5) { LAW.hint(t('ui_ct_report_short'), 'error'); return; }
                return LAW.cb('dispatch:report', [text]).then(function (r) { if (r.ok) { area.value = ''; counter.textContent = '0 / 500'; } });
            }, 'primary')]),
        ], [
            el('div', 'ct-card', [ui.icon('bell', 'ct-card__icon'), el('div', { cls: 'ct-card__v ct-card__v--text', text: t('ui_ct_report_side') })]),
        ]);
        setTimeout(function () { area.focus(); }, 60);
    };
})();
