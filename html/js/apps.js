/*
    ArA-LawSystem - generische Apps (Vertrag 10.3)
      menu      -> menuSelect { id } / menuCancel
      form      -> formSubmit { values } / formCancel
      document  -> nur anzeigen (ESC/Knopf blendet aus)
      badge     -> ohne Fokus, blendet nach data.ms (Default 6000) aus
*/
(function () {
    'use strict';
    var LAW = window.LAW;
    var el = LAW.el, t = LAW.t, $ = LAW.$;

    function hasBaseBelow() {
        return LAW.stack.some(function (n) { return LAW.apps[n] && LAW.apps[n].base; });
    }

    // ==================================================================
    // MENU
    // ==================================================================
    var menu = { items: [], sel: -1, rows: [] };

    function menuSetSel(i, scroll) {
        if (i < 0 || i >= menu.items.length) return;
        menu.sel = i;
        menu.rows.forEach(function (r, k) { r.classList.toggle('is-sel', k === i); });
        var it = menu.items[i];
        $('menu-desc').textContent = it && it.desc ? String(it.desc) : '';
        $('menu-desc').classList.toggle('is-empty', !(it && it.desc));
        if (scroll && menu.rows[i] && menu.rows[i].scrollIntoView) menu.rows[i].scrollIntoView({ block: 'nearest' });
    }

    function menuMove(dir) {
        var n = menu.items.length;
        if (!n) return;
        var i = menu.sel;
        for (var k = 0; k < n; k++) {
            i = (i + dir + n) % n;
            if (!menu.items[i].disabled) { menuSetSel(i, true); return; }
        }
    }

    function menuChoose(i) {
        var it = menu.items[i];
        if (!it || it.disabled) return;
        LAW.hideLayer('menu');
        LAW.post('menuSelect', { id: it.id }).then(function () { LAW.scheduleClose(); });
    }

    LAW.register('menu', {
        root: null,
        setup: function () { this.root = $('app-menu'); },
        open: function (d) {
            this.root.classList.toggle('is-centered', hasBaseBelow());
            $('menu-title').textContent = LAW.str(d.title);
            $('menu-sub').textContent = LAW.str(d.subtitle);
            $('menu-sub').classList.toggle('hidden', !d.subtitle);
            var list = LAW.clear($('menu-list'));
            menu.items = LAW.arr(d.items).map(function (x) { return LAW.obj(x); });
            menu.rows = [];
            menu.sel = -1;
            menu.items.forEach(function (it, i) {
                var row = el('div', { cls: 'mitem' + (it.disabled ? ' is-disabled' : ''), attrs: { role: 'option' } });
                var ic = it.icon ? LAW.ui.icon(it.icon, 'mitem__icon') : null;
                row.appendChild(ic || el('span', 'mitem__bullet'));
                row.appendChild(el('span', { cls: 'mitem__label', text: LAW.str(it.label, String(it.id)) }));
                if (it.badge !== undefined && it.badge !== null && it.badge !== '') row.appendChild(el('span', { cls: 'mitem__badge', text: String(it.badge) }));
                row.addEventListener('mouseenter', function () { if (!it.disabled) menuSetSel(i, false); });
                row.addEventListener('click', function () { menuChoose(i); });
                list.appendChild(row);
                menu.rows.push(row);
            });
            if (!menu.items.length) list.appendChild(LAW.ui.empty('ui_menu_empty'));
            menu.sel = -1;
            menuMove(1);
            if (menu.sel < 0) { $('menu-desc').textContent = ''; $('menu-desc').classList.add('is-empty'); }
        },
        update: function (d) { this.open(d); },
        onKey: function (e) {
            if (e.key === 'ArrowDown') { e.preventDefault(); menuMove(1); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); menuMove(-1); }
            else if (e.key === 'Enter') { e.preventDefault(); menuChoose(menu.sel); }
        },
    });

    // ==================================================================
    // FORM
    // ==================================================================
    var form = { def: null, fields: null };

    function formSummary() {
        var box = $('form-summary');
        LAW.clear(box);
        if (!form.fields || !form.fields.penal) return;
        var tt = form.fields.penal.totals();
        LAW.append(box, [
            el('span', { cls: 'fsum__l', text: t('ui_penal_sum_fine') }), el('b', { text: LAW.fmt.money(tt.fine) }),
            el('span', { cls: 'fsum__l', text: t('ui_penal_sum_jail') }), el('b', { text: tt.jail > 0 ? LAW.fmt.minutes(tt.jail) : '–' }),
            el('span', { cls: 'fsum__l', text: t('ui_penal_sum_count') }), el('b', { text: String(tt.count) }),
        ]);
    }

    function formSubmit() {
        if (!form.fields) return;
        var res = form.fields.collect();
        if (!res.ok) { LAW.hint(res.msg, 'error'); return; }
        LAW.hideLayer('form');
        LAW.post('formSubmit', { values: res.values }).then(function () { LAW.scheduleClose(); });
    }

    LAW.register('form', {
        root: null,
        setup: function () { this.root = $('app-form'); },
        open: function (d) {
            form.def = d;
            var fields = LAW.arr(d.fields);
            var hasPenal = fields.some(function (f) { return f && f.type === 'penalcode'; });
            $('form-panel').classList.toggle('form--wide', hasPenal);
            $('form-title').textContent = LAW.str(d.title);
            $('form-sub').textContent = LAW.str(d.subtitle);
            $('form-sub').classList.toggle('hidden', !d.subtitle);
            form.fields = LAW.Fields.build(fields, { onChange: formSummary });
            LAW.ui.fill($('form-body'), form.fields.node);
            var showSum = hasPenal && (d.summary === 'penalcode' || d.summary === undefined);
            $('form-summary').classList.toggle('hidden', !showSum);
            formSummary();
            var submit = LAW.btn(LAW.str(d.submitLabel, t('ui_submit')), formSubmit, 'primary');
            var cancel = LAW.btn(LAW.str(d.cancelLabel, t('ui_cancel')), function () { LAW.closeLayer('form', 'cancel'); }, 'ghost');
            LAW.ui.fill($('form-btns'), [cancel, submit]);
            $('form-body').scrollTop = 0;
            setTimeout(function () { if (form.fields) form.fields.focusFirst(); }, 40);
        },
        update: function (d) { this.open(Object.assign({}, form.def || {}, d)); },
        onHide: function () { form.fields = null; },
        onKey: function (e) {
            if (e.key !== 'Enter') return;
            var tg = e.target;
            if (!tg || tg.tagName !== 'INPUT' || tg.type === 'checkbox') return;
            if (tg.classList.contains('penal__search')) { e.preventDefault(); return; }
            e.preventDefault();
            formSubmit();
        },
    });

    // ==================================================================
    // DOCUMENT
    // ==================================================================
    var DOC_KINDS = { ticket: 'doc', warrant: 'doc', report: 'doc', evidence: 'doc', poster: 'poster', license: 'card', permit: 'card' };

    function docFields(fields, cls) {
        var list = LAW.arr(fields);
        if (!list.length) return null;
        var box = el('div', 'dfields' + (cls ? ' ' + cls : ''));
        list.forEach(function (f) {
            f = LAW.obj(f);
            box.appendChild(el('div', 'dfield', [
                el('span', { cls: 'dfield__k', text: LAW.str(f.label) }),
                el('span', { cls: 'dfield__v', text: LAW.str(f.value, '–') }),
            ]));
        });
        return box;
    }

    function docSignature(sig) {
        return [
            el('div', { cls: 'dsig__name', text: LAW.str(sig) }),
            el('div', { cls: 'dsig__label', text: t('ui_doc_signature') }),
        ];
    }

    function slot(cls, style, kids) {
        return el('div', { cls: 'slot ' + cls, style: style }, kids);
    }

    function buildDoc(d, kind) {
        var kicker = LAW.has('ui_doc_kind_' + kind) ? t('ui_doc_kind_' + kind) : '';
        if (kicker && String(d.title || '').toLowerCase() === kicker.toLowerCase()) kicker = t('ui_doc_kicker');
        var stage = el('div', { cls: 'stage stage--doc doc doc--' + kind, attrs: { id: 'doc-stage' } });
        LAW.append(stage, [
            slot('doc__kicker', { left: '12%', top: '6.5%', width: '76%', height: '3%' }, [kicker]),
            slot('doc__title', { left: '10%', top: '10%', width: '80%', height: '8%' }, [LAW.str(d.title)]),
            d.subtitle ? slot('doc__sub', { left: '12%', top: '18.5%', width: '76%', height: '3.5%' }, [String(d.subtitle)]) : null,
            slot('doc__content', { left: '11%', top: '24%', width: '78%', height: '52%' }, [
                docFields(d.fields),
                d.body ? el('div', { cls: 'doc__body', text: String(d.body) }) : null,
            ]),
            d.footer ? slot('doc__footer', { left: '11%', top: '77%', width: '78%', height: '4%' }, [String(d.footer)]) : null,
            d.seal ? slot('doc__seal', { left: '9%', top: '80.5%', width: '21%', height: '16.2%' }, [LAW.ui.seal(d.seal, d.sealLabel || d.deptLabel || '')]) : null,
            slot('doc__sig', { left: '52%', top: '84%', width: '38%', height: '11%' }, docSignature(d.signature)),
        ]);
        return stage;
    }

    function buildPoster(d) {
        var stage = el('div', { cls: 'stage stage--poster poster', attrs: { id: 'doc-stage' } });
        var doa = d.deadOrAlive;
        var reward = d.reward !== undefined && d.reward !== null ? LAW.num(d.reward) : null;
        var portrait = el('div', 'poster__portrait', [el('img', { attrs: { src: 'img/silhouette.svg', alt: '', draggable: 'false' } })]);
        LAW.append(stage, [
            slot('poster__wanted', { left: '8%', top: '4.5%', width: '84%', height: '13%' }, [t('ui_poster_wanted')]),
            doa !== undefined && doa !== null ? slot('poster__doa', { left: '8%', top: '18%', width: '84%', height: '5.5%' }, [doa ? t('ui_poster_dead_or_alive') : t('ui_poster_alive')]) : null,
            slot('poster__frame', { left: '27%', top: '25%', width: '46%', height: '27%' }, [portrait]),
            slot('poster__name', { left: '6%', top: '53.5%', width: '88%', height: '7%' }, [LAW.str(d.title)]),
            d.subtitle ? slot('poster__reason', { left: '10%', top: '61%', width: '80%', height: '4.5%' }, [String(d.subtitle)]) : null,
            slot('poster__crimes', { left: '12%', top: '66%', width: '76%', height: '13%' }, [
                docFields(d.fields, 'dfields--poster'),
                d.body ? el('div', { cls: 'poster__body', text: String(d.body) }) : null,
            ]),
            reward !== null ? slot('poster__reward', { left: '8%', top: '79.5%', width: '84%', height: '9.5%' }, [
                el('span', { cls: 'poster__rewardl', text: t('ui_poster_reward') }),
                el('span', { cls: 'poster__rewardv', text: LAW.fmt.money(reward) }),
            ]) : null,
            d.footer ? slot('poster__footer', { left: '10%', top: '89.5%', width: '80%', height: '3.5%' }, [String(d.footer)]) : null,
            d.seal ? slot('poster__seal', { left: '77%', top: '24%', width: '17%', height: '12.2%' }, [LAW.ui.seal(d.seal, '')]) : null,
        ]);
        return stage;
    }

    function buildCard(d, kind) {
        var stage = el('div', { cls: 'stage stage--card card card--' + kind, attrs: { id: 'doc-stage' } });
        var kicker = LAW.has('ui_doc_kind_' + kind) ? t('ui_doc_kind_' + kind) : '';
        if (kicker && String(d.title || '').toLowerCase() === kicker.toLowerCase()) kicker = t('ui_doc_kicker');
        LAW.append(stage, [
            slot('card__seal', { left: '5%', top: '9%', width: '17%', height: '26.4%' }, [LAW.ui.seal(d.seal || 'sheriff', d.sealLabel || d.deptLabel || '')]),
            slot('card__icon', { left: '7%', top: '42%', width: '13%', height: '20%' }, [LAW.ui.icon(kind === 'permit' ? 'gun' : 'skull', 'card__glyph')]),
            slot('card__kicker', { left: '25%', top: '8%', width: '70%', height: '5%' }, [kicker]),
            slot('card__title', { left: '25%', top: '13%', width: '70%', height: '10%' }, [LAW.str(d.title)]),
            d.subtitle ? slot('card__sub', { left: '25%', top: '23.5%', width: '70%', height: '5%' }, [String(d.subtitle)]) : null,
            slot('card__content', { left: '25%', top: '31%', width: '70%', height: '43%' }, [
                docFields(d.fields),
                d.body ? el('div', { cls: 'doc__body', text: String(d.body) }) : null,
            ]),
            d.footer ? slot('card__footer', { left: '5%', top: '77%', width: '44%', height: '13%' }, [String(d.footer)]) : null,
            slot('card__sig', { left: '55%', top: '75%', width: '40%', height: '16%' }, docSignature(d.signature)),
        ]);
        return stage;
    }

    LAW.register('document', {
        root: null,
        setup: function () {
            var self = this;
            this.root = $('app-document');
            $('doc-close').addEventListener('click', function () { LAW.closeLayer('document', 'cancel'); });
            this.root.addEventListener('click', function (e) { if (e.target === self.root) LAW.closeLayer('document', 'cancel'); });
        },
        open: function (d) {
            var kind = DOC_KINDS[d.kind] ? String(d.kind) : 'report';
            var type = DOC_KINDS[kind];
            var stage = type === 'poster' ? buildPoster(d) : type === 'card' ? buildCard(d, kind) : buildDoc(d, kind);
            LAW.ui.fill($('doc-holder'), stage);
        },
        update: function (d) { this.open(d); },
        onHide: function () { LAW.clear($('doc-holder')); },
    });

    // ==================================================================
    // BADGE (ohne Fokus)
    // ==================================================================
    var badgeTimer = null, badgeHide = null;

    LAW.register('badge', {
        root: null,
        nofocus: true,
        setup: function () { this.root = $('app-badge'); },
        /** sofort ausblenden (Beispiel-Marke im Oberflaechen-Editor) */
        hideNow: function () {
            clearTimeout(badgeTimer); clearTimeout(badgeHide);
            this.root.classList.remove('is-in', 'is-out');
            this.root.classList.add('hidden');
            LAW.clear(this.root);
        },
        open: function (d) {
            var root = this.root;
            var key = LAW.sealKey(d.seal);
            var stage = el('div', { cls: 'stage stage--wallet wallet wallet--' + key, attrs: { id: 'badge-stage' } });
            LAW.append(stage, [
                slot('wallet__badge', { left: '5%', top: '9%', width: '42%', height: '82%' }, [LAW.ui.badgeImg(key)]),
                slot('wallet__dept', { left: '54%', top: '12%', width: '40%', height: '9%' }, [LAW.str(d.deptLabel)]),
                slot('wallet__name', { left: '54%', top: '27%', width: '40%', height: '14%' }, [LAW.str(d.name)]),
                slot('wallet__grade', { left: '54%', top: '43%', width: '40%', height: '8%' }, [LAW.str(d.gradeLabel)]),
                slot('wallet__nol', { left: '54%', top: '62%', width: '40%', height: '6%' }, [t('ui_badge_number')]),
                slot('wallet__no', { left: '54%', top: '69%', width: '40%', height: '10%' }, [LAW.str(d.badgeNumber, '–')]),
            ]);
            LAW.ui.fill(root, stage);
            clearTimeout(badgeTimer); clearTimeout(badgeHide);
            root.classList.remove('hidden', 'is-out');
            setTimeout(function () { root.classList.add('is-in'); }, 16);
            var ms = Math.max(1500, Math.min(LAW.num(d.ms, 6000) || 6000, 60000));
            badgeTimer = setTimeout(function () {
                root.classList.add('is-out');
                root.classList.remove('is-in');
                badgeHide = setTimeout(function () { root.classList.add('hidden'); LAW.clear(root); }, 450);
            }, ms);
        },
    });
})();
