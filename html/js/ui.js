/*
    ArA-LawSystem - gemeinsame Bausteine
    Icons (Inline-SVG), Siegel/Marken, Listen-Helfer, Formularfelder (Vertrag 10.3)
    inkl. Feldtyp `penalcode`.
*/
(function () {
    'use strict';
    var LAW = window.LAW;
    var el = LAW.el, t = LAW.t;
    var SVGNS = 'http://www.w3.org/2000/svg';

    LAW.ui = {};

    // ------------------------------------------------------------------
    // Icons (24x24, Strich) - Daten aus Lua waehlen nur den Namen
    // ------------------------------------------------------------------
    var C = function (cx, cy, r) { return 'M' + (cx - r) + ' ' + cy + 'a' + r + ' ' + r + ' 0 1 0 ' + (2 * r) + ' 0a' + r + ' ' + r + ' 0 1 0 ' + (-2 * r) + ' 0'; };
    var ICONS = {
        star:    ['M12 2.5l2.8 6.3 6.7.6-5.1 4.5 1.5 6.6L12 17l-5.9 3.5 1.5-6.6-5.1-4.5 6.7-.6z'],
        badge:   ['M12 2l2.6 4.5H20l-2.7 4.5 2.7 4.5h-5.4L12 20l-2.6-4.5H4l2.7-4.5L4 6.5h5.4z', C(12, 11, 2.2)],
        shield:  ['M12 2.5l8 3v6c0 5-3.4 9-8 10.8-4.6-1.8-8-5.8-8-10.8v-6z', 'M12 7v10M8 11h8'],
        cuffs:   [C(7, 14, 4.2), C(17, 14, 4.2), 'M10.5 9.5h3', 'M7 9.8V7.5M17 9.8V7.5'],
        key:     [C(7, 12, 4), 'M11 12h10M18 12v3M21 12v2.5'],
        lock:    ['M5 11h14v10H5z', 'M8 11V7.5a4 4 0 0 1 8 0V11', 'M12 15v2'],
        search:  [C(10, 10, 6), 'M14.5 14.5L20.5 20.5'],
        doc:     ['M6 3h9l4 4v14H6z', 'M15 3v4h4', 'M9 11h7M9 14.5h7M9 18h4'],
        money:   ['M12 3v18', 'M16.5 7.2C15.6 5.8 14 5 12 5c-2.6 0-4.2 1.3-4.2 3.1 0 1.9 1.7 2.6 4.2 3 2.6.4 4.3 1.3 4.3 3.2 0 1.9-1.8 3.2-4.3 3.2-2 0-3.6-.8-4.5-2.2'],
        gold:    ['M2.5 19l2-5h6.5l2 5z', 'M11 19l2-5h6.5l2 5z', 'M6.8 14l2-5h6.5l2 5z'],
        jail:    ['M4 3h16v18H4z', 'M8 3v18M12 3v18M16 3v18', 'M4 10h16'],
        gun:     ['M2.5 8.5h14l1.5-2h3v4h-4.5l-1.2 2.3h-3.1l-.9 2.2-1.3 5H5.8l1.4-5.6-1.1-1.4H2.5z', 'M11 12.8c.5 1 1.6 1.4 2.5 1.2'],
        dog:     ['M5 7l3-3h4l2 2h3l3 3-2 3h-3l-1 8H9l-1-6-3-1z', 'M16 9h.01'],
        eye:     ['M2 12s3.8-6.5 10-6.5S22 12 22 12s-3.8 6.5-10 6.5S2 12 2 12z', C(12, 12, 3)],
        scale:   ['M12 3v17M7.5 20.5h9M4.5 7h15', 'M6.5 7L3.5 13.5h6z', 'M17.5 7l-3 6.5h6z'],
        wagon:   ['M2.5 6.5h14v7.5h-14z', 'M16.5 9.5h3l1.5 4.5h-4.5', C(6, 17.5, 2.2), C(15, 17.5, 2.2)],
        box:     ['M3 7.5l9-4.2 9 4.2v9.5l-9 4.2-9-4.2z', 'M3 7.5l9 4.2 9-4.2M12 11.7v9.5'],
        pin:     ['M12 21.5s6.8-6.6 6.8-11.6a6.8 6.8 0 0 0-13.6 0c0 5 6.8 11.6 6.8 11.6z', C(12, 9.8, 2.3)],
        person:  [C(12, 7.5, 4), 'M4 21c0-4.2 3.6-7.3 8-7.3s8 3.1 8 7.3'],
        people:  [C(8.5, 8, 3.2), C(16.5, 8.5, 2.8), 'M2.5 20c0-3.6 2.7-6.3 6-6.3s6 2.7 6 6.3', 'M15 13.8c3.3 0 6.5 2.3 6.5 6.2'],
        pen:     ['M4 20l1-4.5L16.5 4l3.5 3.5L8.5 19z', 'M14 6.5l3.5 3.5'],
        clock:   [C(12, 12, 9), 'M12 7v5l3.5 2.5'],
        bell:    ['M6 16v-5a6 6 0 0 1 12 0v5l2 2H4z', 'M10 20.5a2 2 0 0 0 4 0'],
        warning: ['M12 3L2 21h20z', 'M12 10v5', 'M12 18v.5'],
        skull:   ['M4.5 11a7.5 7.5 0 1 1 15 0v3.5h-2.8v3.5H7.3v-3.5H4.5z', 'M9 11.2h.01M15 11.2h.01', 'M10.5 18v2M13.5 18v2'],
        check:   ['M4 12.5l5 5L20 6.5'],
        cross:   ['M5.5 5.5l13 13M18.5 5.5l-13 13'],
        chevron: ['M9 5l7 7-7 7'],
        book:    ['M3 5c3-1.5 6-1.5 9 .5 3-2 6-2 9-.5v14c-3-1.5-6-1.5-9 .5-3-2-6-2-9-.5z', 'M12 5.5v14'],
        horse:   ['M5 20l1.5-6-2-3 3.5-6 3 1.5 4-2.5 1 3.5 3 2.5-1.5 2-3-1-1.5 3 1 6', 'M9 20l.5-5'],
        flag:    ['M5 21V4', 'M5 4h12l-2.5 4L17 12H5'],
    };
    var ICON_ALIAS = {
        handcuffs: 'cuffs', cuff: 'cuffs', uncuff: 'key', unlock: 'key', lockpick: 'key',
        file: 'doc', record: 'doc', records: 'doc', warrant: 'doc', report: 'doc', ticket: 'money', fine: 'money', fines: 'money',
        cash: 'money', dollar: 'money', bail: 'money', weapon: 'gun', weapons: 'gun', revolver: 'gun', k9: 'dog', hound: 'dog',
        evidence: 'search', scan: 'search', escort: 'wagon', transport: 'wagon', cargo: 'box', bodyguard: 'shield',
        bounty: 'skull', wanted: 'skull', panic: 'bell', alert: 'bell', dispatch: 'bell', waypoint: 'pin', gps: 'pin', map: 'pin',
        court: 'scale', judge: 'scale', prison: 'jail', sheriff: 'badge', marshal: 'star', police: 'shield', pinkerton: 'eye',
        note: 'pen', edit: 'pen', user: 'person', citizen: 'person', members: 'people', duty: 'badge', time: 'clock',
        ok: 'check', yes: 'check', no: 'cross', close: 'cross', ledger: 'book', storage: 'box', armory: 'gun', garage: 'wagon',
    };

    LAW.ui.icon = function (name, cls) {
        name = String(name || '').toLowerCase();
        if (ICON_ALIAS[name]) name = ICON_ALIAS[name];
        var paths = ICONS[name];
        if (!paths) return null;
        var svg = document.createElementNS(SVGNS, 'svg');
        svg.setAttribute('viewBox', '0 0 24 24');
        svg.setAttribute('class', 'icon' + (cls ? ' ' + cls : ''));
        svg.setAttribute('aria-hidden', 'true');
        for (var i = 0; i < paths.length; i++) {
            var p = document.createElementNS(SVGNS, 'path');
            p.setAttribute('d', paths[i]);
            svg.appendChild(p);
        }
        return svg;
    };
    LAW.ui.hasIcon = function (name) {
        name = String(name || '').toLowerCase();
        return !!(ICONS[name] || ICONS[ICON_ALIAS[name]]);
    };

    // ------------------------------------------------------------------
    // Siegel (Stempel) und Marken
    // ------------------------------------------------------------------
    var sealSeq = 0;

    /** Tinten-Siegel mit Behoerdenname im oberen Bogen (Text als SVG-Textknoten, kein HTML) */
    LAW.ui.seal = function (sealKey, label, cls) {
        var key = LAW.sealKey(sealKey);
        var wrap = el('div', 'seal seal--' + key + (cls ? ' ' + cls : ''));
        wrap.appendChild(el('img', { cls: 'seal__img', attrs: { src: 'img/seal_' + key + '.svg', alt: '', draggable: 'false' } }));
        if (label) {
            var id = 'sealarc' + (++sealSeq);
            var svg = document.createElementNS(SVGNS, 'svg');
            svg.setAttribute('viewBox', '0 0 200 200');
            svg.setAttribute('class', 'seal__ring');
            var defs = document.createElementNS(SVGNS, 'defs');
            var path = document.createElementNS(SVGNS, 'path');
            path.setAttribute('id', id);
            path.setAttribute('d', 'M 26 100 A 74 74 0 0 1 174 100');   // oberer Bogen im Band r 64..92 der Siegel-SVGs
            defs.appendChild(path);
            svg.appendChild(defs);
            var text = document.createElementNS(SVGNS, 'text');
            text.setAttribute('class', 'seal__text');
            text.setAttribute('text-anchor', 'middle');
            var tp = document.createElementNS(SVGNS, 'textPath');
            tp.setAttribute('href', '#' + id);
            tp.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', '#' + id);
            tp.setAttribute('startOffset', '50%');
            tp.setAttribute('text-anchor', 'middle');
            var s = String(label).toUpperCase();
            if (s.length > 28) s = s.slice(0, 27) + '.';
            // Lange Namen auf den Bogen stauchen (halber Umfang r=74 ~ 232)
            if (s.length > 18) { tp.setAttribute('textLength', '222'); tp.setAttribute('lengthAdjust', 'spacingAndGlyphs'); }
            tp.textContent = s;
            text.appendChild(tp);
            svg.appendChild(text);
            wrap.appendChild(svg);
        }
        return wrap;
    };

    LAW.ui.badgeImg = function (sealKey, cls) {
        return el('img', { cls: 'badge-img' + (cls ? ' ' + cls : ''), attrs: { src: 'img/badge_' + LAW.sealKey(sealKey) + '.svg', alt: '', draggable: 'false' } });
    };

    // ------------------------------------------------------------------
    // Kleine Bausteine
    // ------------------------------------------------------------------
    LAW.ui.empty = function (key) { return el('div', { cls: 'empty', text: t(key || 'ui_empty') }); };
    LAW.ui.loading = function () { return el('div', { cls: 'loading', text: t('ui_loading') }); };

    LAW.ui.h = function (text, cls) { return el('h3', { cls: 'h' + (cls ? ' ' + cls : ''), text: text }); };

    /** Zeile "Bezeichnung ...... Wert" */
    LAW.ui.kv = function (label, value, cls) {
        return el('div', 'kv' + (cls ? ' ' + cls : ''), [
            el('span', { cls: 'kv__k', text: label }),
            el('span', 'kv__dots'),
            el('span', { cls: 'kv__v', text: value === undefined || value === null || value === '' ? '–' : value }),
        ]);
    };

    var STATUS_KIND = {
        open: 'warn', overdue: 'bad', paid: 'good', cancelled: 'mute', pending: 'warn', active: 'bad', served: 'good',
        revoked: 'mute', expired: 'mute', claimed: 'good', collected: 'warn', analyzing: 'warn', analyzed: 'good',
        destroyed: 'mute', registered: 'good', stolen: 'bad', confiscated: 'warn', issued: 'info', accepted: 'info',
        delivered: 'good', completed: 'good', failed: 'bad', robbed: 'bad', online: 'good', offline: 'mute',
    };
    LAW.ui.chip = function (text, kind, icon) {
        var c = el('span', 'chip chip--' + (kind || 'info'));
        if (icon) { var i = LAW.ui.icon(icon); if (i) c.appendChild(i); }
        c.appendChild(document.createTextNode(String(text)));
        return c;
    };
    LAW.ui.status = function (status, label) {
        var s = String(status || '');
        var txt = label || (LAW.has('ui_status_' + s) ? t('ui_status_' + s) : s);
        return LAW.ui.chip(txt, STATUS_KIND[s] || 'info');
    };

    /** Flags einer Person (Vertrag 10.6 PersonHit.flags) als Chips */
    LAW.ui.flags = function (flags) {
        flags = LAW.obj(flags);
        var out = el('span', 'flags');
        if (flags.warrant) out.appendChild(LAW.ui.chip(t('ui_flag_warrant'), 'bad', 'doc'));
        if (flags.bounty) out.appendChild(LAW.ui.chip(t('ui_flag_bounty'), 'bad', 'skull'));
        if (flags.jailed) out.appendChild(LAW.ui.chip(t('ui_flag_jailed'), 'warn', 'jail'));
        if (flags.dangerous) out.appendChild(LAW.ui.chip(t('ui_flag_dangerous'), 'bad', 'warning'));
        return out;
    };

    LAW.ui.deadOrAlive = function (v) {
        return v ? t('ui_dead_or_alive') : t('ui_alive_only');
    };

    /**
     * Umschalter (Status-Filter usw.)
     * opts: [{ id, label }], active, onChange(id)
     */
    LAW.ui.segmented = function (opts, active, onChange) {
        var wrap = el('div', 'seg');
        opts.forEach(function (o) {
            var b = el('button', { cls: 'seg__btn' + (o.id === active ? ' is-active' : ''), text: o.label, type: 'button' });
            b.addEventListener('click', function () {
                var all = wrap.querySelectorAll('.seg__btn');
                for (var i = 0; i < all.length; i++) all[i].classList.remove('is-active');
                b.classList.add('is-active');
                onChange(o.id);
            });
            wrap.appendChild(b);
        });
        return wrap;
    };

    /** Eintrag einer Liste (Karteikarte). opts: { title, sub, meta, right, onClick, active, cls, icon } */
    LAW.ui.row = function (opts) {
        var r = el(opts.onClick ? 'button' : 'div', { cls: 'row' + (opts.active ? ' is-active' : '') + (opts.cls ? ' ' + opts.cls : ''), type: opts.onClick ? 'button' : undefined });
        if (opts.icon) { var ic = LAW.ui.icon(opts.icon, 'row__icon'); if (ic) r.appendChild(ic); }
        var main = el('div', 'row__main', [
            el('div', 'row__title', [opts.title !== undefined ? String(opts.title) : '', opts.titleExtra || null]),
            opts.sub ? el('div', { cls: 'row__sub', text: opts.sub }) : null,
            opts.meta ? el('div', { cls: 'row__meta', text: opts.meta }) : null,
        ]);
        r.appendChild(main);
        if (opts.right) r.appendChild(el('div', 'row__right', opts.right));
        if (opts.onClick) r.addEventListener('click', function () {
            var p = r.parentNode;
            if (p) { var a = p.querySelectorAll('.row.is-active'); for (var i = 0; i < a.length; i++) a[i].classList.remove('is-active'); }
            r.classList.add('is-active');
            opts.onClick();
        });
        return r;
    };

    LAW.ui.list = function (items, render, emptyKey) {
        var box = el('div', 'list');
        items = LAW.arr(items);
        if (!items.length) { box.appendChild(LAW.ui.empty(emptyKey)); return box; }
        items.forEach(function (it, i) { var n = render(it, i); if (n) box.appendChild(n); });
        return box;
    };

    LAW.ui.actions = function (btns) { return el('div', 'actions', btns); };

    /** Container fuellen: fill(node, kinder) */
    LAW.ui.fill = function (node, kids) { LAW.clear(node); LAW.append(node, kids); return node; };

    // ------------------------------------------------------------------
    // Formularfelder (Vertrag 10.3)
    // ------------------------------------------------------------------
    var PENAL_MAX = 5;
    var fieldSeq = 0;

    function optList(field) { return LAW.arr(field.options); }

    function sameVal(a, b) { return a === b || String(a) === String(b); }

    function numberInput(field, money) {
        var inp = el('input', { cls: 'inp', type: 'number', attrs: { step: money ? '0.01' : 'any', inputmode: 'decimal' } });
        if (field.min !== undefined && field.min !== null) inp.setAttribute('min', field.min);
        if (field.max !== undefined && field.max !== null) inp.setAttribute('max', field.max);
        if (field.placeholder) inp.placeholder = String(field.placeholder);
        if (field.default !== undefined && field.default !== null && field.default !== '') inp.value = String(field.default);
        return inp;
    }

    /** Strafkatalog-Feld: Suche + Kategorien + Anzahl je Delikt + Live-Summe */
    function penalWidget(field, onChange) {
        var options = optList(field).map(function (o) {
            return { id: o.value, label: LAW.str(o.label, String(o.value)), category: LAW.str(o.category, t('ui_penal_other')), fine: LAW.num(o.fine), jail: LAW.num(o.jail), desc: o.desc };
        });
        var counts = {};   // id -> count
        LAW.arr(field.default).forEach(function (d) {
            if (d && d.id !== undefined) counts[String(d.id)] = Math.max(0, Math.min(PENAL_MAX, LAW.num(d.count, 1)));
        });
        var cats = [];
        options.forEach(function (o) { if (cats.indexOf(o.category) < 0) cats.push(o.category); });
        var state = { q: '', cat: '' };

        var root = el('div', 'penal');
        var search = el('input', { cls: 'inp penal__search', type: 'text', attrs: { placeholder: t('ui_penal_search'), maxlength: '40' } });
        var catBar = el('div', 'penal__cats');
        var list = el('div', 'penal__list');
        var chosen = el('div', 'penal__chosen');
        var sumFine = el('span', 'penal__sumv');
        var sumJail = el('span', 'penal__sumv');
        var sum = el('div', 'penal__sum', [
            el('span', { cls: 'penal__suml', text: t('ui_penal_sum_fine') }), sumFine,
            el('span', { cls: 'penal__suml', text: t('ui_penal_sum_jail') }), sumJail,
        ]);

        function totals() {
            var f = 0, j = 0, n = 0;
            options.forEach(function (o) {
                var c = counts[String(o.id)] || 0;
                if (c > 0) { f += o.fine * c; j += o.jail * c; n += c; }
            });
            return { fine: Math.round(f * 100) / 100, jail: j, count: n };
        }

        function setCount(o, c) {
            c = Math.max(0, Math.min(PENAL_MAX, c));
            if (c === 0) delete counts[String(o.id)]; else counts[String(o.id)] = c;
            renderList();
            renderChosen();
            if (onChange) onChange();
        }

        function stepper(o) {
            var c = counts[String(o.id)] || 0;
            var minus = el('button', { cls: 'step__b', type: 'button', text: '−', disabled: c <= 0, title: t('ui_penal_less') });
            var plus = el('button', { cls: 'step__b', type: 'button', text: '+', disabled: c >= PENAL_MAX, title: t('ui_penal_more') });
            minus.addEventListener('click', function (e) { e.stopPropagation(); setCount(o, (counts[String(o.id)] || 0) - 1); });
            plus.addEventListener('click', function (e) { e.stopPropagation(); setCount(o, (counts[String(o.id)] || 0) + 1); });
            return el('span', 'step', [minus, el('span', { cls: 'step__n', text: String(c) }), plus]);
        }

        function renderCats() {
            LAW.clear(catBar);
            var mk = function (id, label) {
                var b = el('button', { cls: 'penal__cat' + (state.cat === id ? ' is-active' : ''), type: 'button', text: label });
                b.addEventListener('click', function () { state.cat = id; renderCats(); renderList(); });
                return b;
            };
            catBar.appendChild(mk('', t('ui_penal_all')));
            cats.forEach(function (c) { catBar.appendChild(mk(c, c)); });
        }

        function renderList() {
            var keepScroll = list.scrollTop;   // Liste nicht nach oben springen lassen, wenn +/- geklickt wird
            LAW.clear(list);
            var q = state.q.toLowerCase();
            var shown = 0;
            options.forEach(function (o) {
                if (state.cat && o.category !== state.cat) return;
                if (q && o.label.toLowerCase().indexOf(q) < 0 && String(o.id).toLowerCase().indexOf(q) < 0) return;
                shown++;
                var c = counts[String(o.id)] || 0;
                var row = el('div', 'penal__row' + (c > 0 ? ' is-on' : ''), [
                    el('div', 'penal__info', [
                        el('div', { cls: 'penal__label', text: o.label }),
                        el('div', { cls: 'penal__meta', text: (state.cat ? '' : o.category + ' · ') + LAW.fmt.money(o.fine) + (o.jail > 0 ? ' · ' + LAW.fmt.minutes(o.jail) : '') }),
                    ]),
                    stepper(o),
                ]);
                row.addEventListener('click', function () { if (!c) setCount(o, 1); });
                list.appendChild(row);
            });
            if (!shown) list.appendChild(LAW.ui.empty('ui_penal_none'));
            list.scrollTop = keepScroll;
        }

        function renderChosen() {
            LAW.clear(chosen);
            var any = false;
            options.forEach(function (o) {
                var c = counts[String(o.id)] || 0;
                if (!c) return;
                any = true;
                chosen.appendChild(el('div', 'penal__pick', [
                    el('span', { cls: 'penal__pickn', text: c + '×' }),
                    el('span', { cls: 'penal__pickl', text: o.label }),
                    el('span', { cls: 'penal__pickv', text: LAW.fmt.money(o.fine * c) }),
                    (function () {
                        var x = el('button', { cls: 'penal__x', type: 'button', title: t('ui_remove') });
                        x.appendChild(LAW.ui.icon('cross'));
                        x.addEventListener('click', function () { setCount(o, 0); });
                        return x;
                    })(),
                ]));
            });
            if (!any) chosen.appendChild(LAW.ui.empty('ui_penal_nothing'));
            var tt = totals();
            sumFine.textContent = LAW.fmt.money(tt.fine);
            sumJail.textContent = tt.jail > 0 ? LAW.fmt.minutes(tt.jail) : '–';
        }

        search.addEventListener('input', function () { state.q = search.value.trim(); renderList(); });

        root.appendChild(el('div', 'penal__cat-col', [search, catBar, list]));
        root.appendChild(el('div', 'penal__sel-col', [el('div', { cls: 'penal__selh', text: t('ui_penal_selected') }), chosen, sum]));
        renderCats(); renderList(); renderChosen();

        return {
            node: root,
            totals: totals,
            value: function () {
                var out = [];
                options.forEach(function (o) { var c = counts[String(o.id)] || 0; if (c > 0) out.push({ id: o.id, count: c }); });
                return out;
            },
            focus: function () { search.focus(); },
        };
    }

    /**
     * Baut Felder. -> { node, collect() -> { ok, values, msg }, penal, focusFirst() }
     * opts: { compact, onChange }
     */
    LAW.Fields = {};
    LAW.Fields.build = function (fields, opts) {
        opts = opts || {};
        var node = el('div', 'fields' + (opts.compact ? ' fields--compact' : ''));
        var readers = [];
        var penal = null;

        fields.forEach(function (f) {
            f = LAW.obj(f);
            if (!f.name) return;
            var type = String(f.type || 'text');
            var id = 'fld' + (++fieldSeq);
            var wrap = el('div', 'field field--' + type);
            var labelText = LAW.str(f.label, f.name) + (f.required ? ' *' : '');
            var label = el('label', { cls: 'field__label', text: labelText, attrs: { for: id } });
            var err = el('div', 'field__err');
            var help = f.help ? el('div', { cls: 'field__help', text: f.help }) : null;
            var read, input;

            switch (type) {
                case 'textarea':
                    input = el('textarea', { cls: 'inp inp--area', attrs: { id: id, rows: '4' } });
                    if (f.maxLength) input.setAttribute('maxlength', String(f.maxLength));
                    if (f.placeholder) input.placeholder = String(f.placeholder);
                    if (f.default !== undefined && f.default !== null) input.value = String(f.default);
                    read = function () { return input.value.trim(); };
                    break;
                case 'number':
                case 'money': {
                    var num = numberInput(f, type === 'money');
                    num.id = id;
                    read = function () {
                        var v = String(num.value || '').trim();
                        if (v === '') return null;
                        var n = Number(v.replace(',', '.'));
                        if (!isFinite(n)) return NaN;
                        return type === 'money' ? Math.round(n * 100) / 100 : n;
                    };
                    input = type === 'money' ? el('div', 'inp-money', [el('span', { cls: 'inp-money__cur', text: LAW.currency }), num]) : num;
                    break;
                }
                case 'select': {
                    var options = optList(f);
                    var sel = el('select', { cls: 'inp inp--select', attrs: { id: id } });
                    var hasDefault = false;
                    if (!f.required || f.default === undefined || f.default === null) {
                        sel.appendChild(el('option', { value: '', text: f.placeholder ? String(f.placeholder) : t('ui_select_choose') }));
                    }
                    options.forEach(function (o, i) {
                        var op = el('option', { value: String(i), text: LAW.str(o.label, String(o.value)) });
                        if (f.default !== undefined && f.default !== null && sameVal(o.value, f.default)) { op.selected = true; hasDefault = true; }
                        sel.appendChild(op);
                    });
                    if (!hasDefault && sel.options.length) sel.selectedIndex = 0;
                    // Optionswerte koennen Zahlen sein -> ueber den Index zurueckgeben (Typ bleibt erhalten)
                    read = function () {
                        var v = sel.value;
                        if (v === '') return null;
                        var o = options[Number(v)];
                        return o ? o.value : null;
                    };
                    var descBox = el('div', 'field__desc');
                    var showDesc = function () {
                        var o = sel.value === '' ? null : options[Number(sel.value)];
                        descBox.textContent = o && o.desc ? String(o.desc) : '';
                    };
                    sel.addEventListener('change', function () { showDesc(); if (opts.onChange) opts.onChange(); });
                    showDesc();
                    input = el('div', 'inp-wrap', [sel, descBox]);
                    break;
                }
                case 'multiselect': {
                    var mopts = optList(f);
                    var defs = LAW.arr(f.default);
                    var boxes = [];
                    input = el('div', 'multi');
                    mopts.forEach(function (o) {
                        var cb = el('input', { type: 'checkbox' });
                        cb.checked = defs.some(function (d) { return sameVal(d, o.value); });
                        boxes.push({ cb: cb, value: o.value });
                        input.appendChild(el('label', 'multi__opt', [cb, el('span', { cls: 'multi__box' }), el('span', { cls: 'multi__l', text: LAW.str(o.label, String(o.value)) }), o.desc ? el('span', { cls: 'multi__d', text: o.desc }) : null]));
                    });
                    read = function () { return boxes.filter(function (b) { return b.cb.checked; }).map(function (b) { return b.value; }); };
                    break;
                }
                case 'checkbox': {
                    var box = el('input', { type: 'checkbox', attrs: { id: id } });
                    box.checked = f.default === true || f.default === 1 || f.default === 'true';
                    input = el('label', 'check', [box, el('span', 'check__box'), el('span', { cls: 'check__l', text: f.placeholder ? String(f.placeholder) : t('ui_yes') })]);
                    read = function () { return box.checked; };
                    break;
                }
                case 'readonly':
                    input = el('div', { cls: 'inp inp--ro', text: f.display !== undefined ? String(f.display) : (f.placeholder ? String(f.placeholder) : LAW.str(f.default, '–')) });
                    read = function () { return f.default === undefined ? null : f.default; };
                    break;
                case 'penalcode':
                    penal = penalWidget(f, opts.onChange);
                    input = penal.node;
                    read = function () { return penal.value(); };
                    break;
                default: // text
                    input = el('input', { cls: 'inp', type: 'text', attrs: { id: id } });
                    if (f.maxLength) input.setAttribute('maxlength', String(f.maxLength));
                    if (f.placeholder) input.placeholder = String(f.placeholder);
                    if (f.default !== undefined && f.default !== null) input.value = String(f.default);
                    read = function () { return input.value.trim(); };
            }

            if (opts.onChange && type !== 'penalcode' && type !== 'select') {
                wrap.addEventListener('input', function () { opts.onChange(); });
                wrap.addEventListener('change', function () { opts.onChange(); });
            }

            LAW.append(wrap, [label, input, help, err]);
            node.appendChild(wrap);

            readers.push({
                f: f, type: type, wrap: wrap, err: err,
                read: read,
            });
        });

        function validate(r, v) {
            var f = r.f, lbl = LAW.str(f.label, f.name);
            var empty = v === null || v === undefined || v === '' || (Array.isArray(v) && v.length === 0) || (r.type === 'checkbox' && v === false);
            if (f.required && r.type !== 'readonly' && empty) return t('ui_form_required', lbl);
            if (empty) return null;
            if (r.type === 'number' || r.type === 'money') {
                if (typeof v !== 'number' || isNaN(v)) return t('ui_form_number', lbl);
                if (f.min !== undefined && f.min !== null && v < Number(f.min)) return t('ui_form_min', lbl, r.type === 'money' ? LAW.fmt.money(f.min) : f.min);
                if (f.max !== undefined && f.max !== null && v > Number(f.max)) return t('ui_form_max', lbl, r.type === 'money' ? LAW.fmt.money(f.max) : f.max);
            }
            if ((r.type === 'text' || r.type === 'textarea') && typeof v === 'string') {
                if (f.maxLength && v.length > Number(f.maxLength)) return t('ui_form_maxlen', lbl, f.maxLength);
                if (f.min !== undefined && f.min !== null && v.length < Number(f.min)) return t('ui_form_minlen', lbl, f.min);
            }
            if (r.type === 'multiselect' || r.type === 'penalcode') {
                if (f.min !== undefined && f.min !== null && v.length < Number(f.min)) return t('ui_form_min_items', lbl, f.min);
                if (f.max !== undefined && f.max !== null && v.length > Number(f.max)) return t('ui_form_max_items', lbl, f.max);
            }
            return null;
        }

        function collect() {
            var values = {}, firstErr = null, firstWrap = null;
            readers.forEach(function (r) {
                var v = r.read();
                var e = validate(r, v);
                r.wrap.classList.toggle('is-invalid', !!e);
                r.err.textContent = e || '';
                if (e && !firstErr) { firstErr = e; firstWrap = r.wrap; }
                if (v === null || v === undefined || (typeof v === 'number' && isNaN(v))) return;
                values[r.f.name] = v;
            });
            if (firstErr) {
                if (firstWrap && firstWrap.scrollIntoView) firstWrap.scrollIntoView({ block: 'nearest' });
                return { ok: false, msg: firstErr };
            }
            return { ok: true, values: values };
        }

        return {
            node: node,
            penal: penal,
            collect: collect,
            focusFirst: function () {
                var f = node.querySelector('input:not([type=checkbox]), textarea, select');
                if (f) f.focus();
            },
        };
    };
})();
