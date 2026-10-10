/*
    ArA-LawSystem - HUDs (Vertrag 10.4) - ohne Fokus, nur bei `hud`-Nachricht aktualisiert
    jail, cuffed, k9, escort, evidence, duty, robbery
*/
(function () {
    'use strict';
    var LAW = window.LAW;
    var el = LAW.el, t = LAW.t, $ = LAW.$, ui = LAW.ui;

    /** Einfache HUD-Huelle: Element #hud-<name>, build(box, data) fuellt es */
    function hud(name, build) {
        var box = null, last = null;
        LAW.huds[name] = {
            setup: function () { box = $('hud-' + name); },
            show: function (d) {
                if (!box) return;
                last = d;
                build(box, d);
                box.classList.remove('hidden');
                setTimeout(function () { box.classList.add('is-in'); }, 16);
            },
            hide: function () {
                if (!box) return;
                last = null;
                box.classList.remove('is-in');
                box.classList.add('hidden');
            },
            onInit: function () { if (last && box) build(box, last); },   // Texte nach init neu setzen
        };
    }

    function bar(frac, cls) {
        var p = Math.max(0, Math.min(1, LAW.num(frac))) * 100;
        return el('div', 'hbar' + (cls ? ' ' + cls : ''), [el('div', { cls: 'hbar__fill', style: { width: p.toFixed(1) + '%' } })]);
    }

    // ------------------------------------------------------------------
    hud('jail', function (box, d) {
        var total = LAW.num(d.total), remaining = LAW.num(d.remaining);
        var work = LAW.obj(d.work);
        var served = total > 0 ? (total - remaining) / total : 0;
        ui.fill(box, [
            el('div', 'hud-jail__bars', [ui.icon('jail', 'hud-jail__icon')]),
            el('div', 'hud-jail__main', [
                el('div', { cls: 'hud-jail__label', text: t('ui_hud_jail') }),
                el('div', { cls: 'hud-jail__time', text: LAW.fmt.duration(remaining) }),
                bar(served, 'hbar--iron'),
                el('div', 'hud-jail__meta', [
                    el('span', { text: t('ui_hud_jail_total', LAW.fmt.duration(total)) }),
                    LAW.num(d.reduced) > 0 ? el('span', { text: t('ui_hud_jail_reduced', LAW.fmt.duration(d.reduced)) }) : null,
                    work.max !== undefined ? el('span', { text: t('ui_hud_jail_work', LAW.num(work.done), LAW.num(work.max)) }) : null,
                ]),
            ]),
        ]);
    });

    // ------------------------------------------------------------------
    hud('cuffed', function (box, d) {
        ui.fill(box, [
            ui.icon('cuffs', 'hud-cuffed__icon'),
            el('div', 'hud-cuffed__txt', [
                el('div', { cls: 'hud-cuffed__title', text: t('ui_hud_cuffed') }),
                d.by ? el('div', { cls: 'hud-cuffed__by', text: t('ui_hud_cuffed_by', String(d.by)) }) : null,
            ]),
        ]);
    });

    // ------------------------------------------------------------------
    // Gleicher Aufbau und gleiche Groesse wie das Dienst-Abzeichen (duty):
    // Zeile 1 = Zustand, Zeile 2 = "Bluthund" (+ Witterung bei einer Verfolgung).
    // Laengere Texte (d.text) kommen zusaetzlich als Benachrichtigung vom Client.
    var STRENGTH = { fresh: 3, medium: 2, weak: 1 };
    function cap(s) { s = String(s || ''); return s.charAt(0).toUpperCase() + s.slice(1); }
    hud('k9', function (box, d) {
        var state = LAW.str(d.state, 'idle');
        var hasScent = d.strength !== undefined && d.strength !== null;
        box.className = box.className.replace(/\bk9--\S+/g, '').trim() + ' k9--' + state;
        var sub = [el('span', { cls: 'hud-k9__name', text: t('ui_hud_k9') })];
        if (hasScent) {
            var n = STRENGTH[d.strength] || 0;
            var dots = el('span', 'scent');
            for (var i = 1; i <= 3; i++) dots.appendChild(el('span', 'scent__dot' + (i <= n ? ' is-on' : '')));
            sub.push(el('span', { cls: 'hud-k9__sep', text: '·' }), dots,
                el('span', { cls: 'hud-k9__scentv', text: LAW.has('ui_k9_strength_' + d.strength) ? t('ui_k9_strength_' + d.strength) : String(d.strength) }));
        }
        ui.fill(box, [
            ui.icon('dog', 'hud-k9__icon'),
            el('div', 'hud-k9__txt', [
                el('div', { cls: 'hud-k9__state', text: cap(LAW.has('ui_k9_state_' + state) ? t('ui_k9_state_' + state) : state) }),
                el('div', 'hud-k9__sub', sub),
            ]),
        ]);
    });

    // ------------------------------------------------------------------
    hud('escort', function (box, d) {
        var near = LAW.num(d.escortsNear), total = LAW.num(d.escortsTotal);
        ui.fill(box, [
            el('div', 'hud-escort__head', [
                ui.icon('wagon', 'hud-escort__icon'),
                el('span', { cls: 'hud-escort__title', text: LAW.str(d.typeLabel, t('ui_hud_escort')) + (d.id !== undefined ? ' #' + d.id : '') }),
            ]),
            d.statusLabel ? el('div', { cls: 'hud-escort__status', text: String(d.statusLabel) }) : null,
            d.destinationLabel ? ui.kv(t('ui_hud_escort_dest'), String(d.destinationLabel), 'kv--hud') : null,
            d.timeLeft !== undefined && d.timeLeft !== null ? ui.kv(t('ui_hud_escort_time'), LAW.fmt.duration(d.timeLeft), 'kv--hud') : null,
            total > 0 ? ui.kv(t('ui_hud_escort_near'), near + ' / ' + total, 'kv--hud' + (near < total ? ' kv--warn' : '')) : null,
        ]);
    });

    // ------------------------------------------------------------------
    // evidence: { active:false } blendet aus
    (function () {
        hud('evidence', function (box, d) {
            ui.fill(box, [
                ui.icon('search', 'hud-ev__icon'),
                el('div', 'hud-ev__txt', [
                    el('div', { cls: 'hud-ev__title', text: t('ui_hud_evidence') }),
                    el('div', { cls: 'hud-ev__count', text: t('ui_hud_evidence_count', LAW.num(d.count)) }),
                ]),
            ]);
        });
        var h = LAW.huds.evidence, show = h.show;
        h.show = function (d) { if (d.active === false) h.hide(); else show(d); };
    })();

    // ------------------------------------------------------------------
    hud('duty', function (box, d) {
        ui.fill(box, [
            ui.icon('badge', 'hud-duty__icon'),
            el('div', 'hud-duty__txt', [
                el('div', { cls: 'hud-duty__dept', text: LAW.str(d.deptLabel, t('ui_on_duty')) }),
                el('div', { cls: 'hud-duty__grade', text: [LAW.str(d.gradeLabel), LAW.str(d.badgeNumber)].filter(Boolean).join(' · ') }),
            ]),
        ]);
    });

    // ------------------------------------------------------------------
    hud('robbery', function (box, d) {
        var p = Math.max(0, Math.min(1, LAW.num(d.progress)));
        ui.fill(box, [
            el('div', 'hud-rob__head', [
                ui.icon('box', 'hud-rob__icon'),
                el('span', { cls: 'hud-rob__text', text: LAW.str(d.text, t('ui_hud_robbery')) }),
                el('span', { cls: 'hud-rob__pct', text: Math.round(p * 100) + '%' }),
            ]),
            bar(p, 'hbar--blood'),
        ]);
    });
})();
