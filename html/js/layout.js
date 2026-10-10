/*
    ArA-LawSystem - Oberflaeche anpassen (/editlawinterface)

    Jeder Spieler kann HUDs, Hinweise und die Marke selbst verschieben und
    vergroessern. Gespeichert wird pro Spieler (Lua: Resource-KVP), hier nur
    angewendet.

    Layout = { <key> = { x = 0..1, y = 0..1, s = Groesse } }
      x/y = linke obere Ecke in Anteilen des Bildschirms
      s   = Groesse (CSS-Variable --s, 1 = Standard)
    Fehlt ein key, gilt die Standard-Position aus dem CSS.
*/
(function () {
    'use strict';
    var LAW = window.LAW;
    var el = LAW.el, t = LAW.t, $ = LAW.$;

    var MIN_S = 0.5, MAX_S = 2.0, STEP_S = 0.05;

    // Reihenfolge = Reihenfolge der Rahmen im Editor
    var TARGETS = [
        { key: 'duty',     id: 'hud-duty' },
        { key: 'notify',   id: 'toast-layer' },
        { key: 'jail',     id: 'hud-jail' },
        { key: 'cuffed',   id: 'hud-cuffed' },
        { key: 'robbery',  id: 'hud-robbery' },
        { key: 'k9',       id: 'hud-k9' },
        { key: 'escort',   id: 'hud-escort' },
        { key: 'evidence', id: 'hud-evidence' },
        { key: 'badge',    id: 'app-badge' },
    ];
    var BY_KEY = {};
    TARGETS.forEach(function (d) { BY_KEY[d.key] = d; });

    var current = {};     // angewendetes (gespeichertes) Layout
    var home = {};        // urspruenglicher Platz im DOM (fuer Elemente in .hud-bottom)

    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

    function clean(layout) {
        var out = {};
        layout = LAW.obj(layout);
        TARGETS.forEach(function (d) {
            var v = layout[d.key];
            if (!v || typeof v !== 'object') return;
            var x = Number(v.x), y = Number(v.y), s = Number(v.s);
            if (!isFinite(x) || !isFinite(y)) return;
            out[d.key] = { x: clamp(x, 0, 1), y: clamp(y, 0, 1), s: isFinite(s) ? clamp(s, MIN_S, MAX_S) : 1 };
        });
        return out;
    }

    function copy(layout) { return JSON.parse(JSON.stringify(layout || {})); }

    /** Ein Element auf Position/Groesse setzen (v = null -> Standard) */
    function applyOne(key, v) {
        var d = BY_KEY[key];
        var node = d && $(d.id);
        if (!node) return;
        var layer = $('hud-layer');
        if (!home[key]) home[key] = { parent: node.parentNode, next: node.nextSibling };
        if (!v) {
            node.classList.remove('is-custom');
            ['left', 'top', 'right', 'bottom', 'marginLeft'].forEach(function (p) { node.style[p] = ''; });
            node.style.removeProperty('--s');
            // zurueck an den alten Platz (Ueberfall/Handschellen stehen sonst nicht mehr unten mittig)
            var h = home[key];
            if (h && h.parent && node.parentNode !== h.parent) {
                h.parent.insertBefore(node, h.next && h.next.parentNode === h.parent ? h.next : null);
            }
            return;
        }
        // Elemente aus der unteren Gruppe herausloesen, sonst zaehlt die Position relativ zur Gruppe
        if (layer && node.parentNode && node.parentNode.classList && node.parentNode.classList.contains('hud-bottom')) {
            layer.appendChild(node);
        }
        node.classList.add('is-custom');
        node.style.left = (v.x * 100).toFixed(3) + '%';
        node.style.top = (v.y * 100).toFixed(3) + '%';
        node.style.right = 'auto';
        node.style.bottom = 'auto';
        node.style.marginLeft = '0';
        node.style.setProperty('--s', String(v.s || 1));
    }

    function applyAll(layout) {
        TARGETS.forEach(function (d) { applyOne(d.key, layout[d.key] || null); });
    }

    LAW.Layout = {
        /** Gespeichertes Layout anwenden (aus init / nach dem Speichern) */
        apply: function (layout) {
            current = clean(layout);
            applyAll(current);
        },
        get: function () { return copy(current); },
    };

    // ------------------------------------------------------------------
    // Beispiel-Anzeigen fuer den Editor
    // ------------------------------------------------------------------
    var demoHuds = [];      // HUD-Namen, die der Editor eingeblendet hat
    var demoToasts = [];
    var demoBadge = false;

    function isShown(id) {
        var n = $(id);
        return n && !n.classList.contains('hidden');
    }

    function showDemos(samples) {
        samples = LAW.obj(samples);
        var duty = LAW.obj(samples.duty);
        var demo = {
            duty: { deptLabel: LAW.str(duty.deptLabel, 'County Sheriff'), gradeLabel: LAW.str(duty.gradeLabel, 'Deputy'), badgeNumber: LAW.str(duty.badgeNumber, 'SO-0042') },
            jail: { remaining: 1500, total: 3600, reduced: 120, work: { done: 2, max: 5 } },
            cuffed: { by: LAW.str(samples.name, 'Deputy') },
            robbery: { progress: 0.45 },
            k9: { state: 'tracking', strength: 'medium' },
            escort: { typeLabel: t('ui_hud_escort'), id: 7, destinationLabel: 'Saint Denis', timeLeft: 900, escortsNear: 2, escortsTotal: 3 },
            evidence: { active: true, count: 3 },
        };
        demoHuds = [];
        Object.keys(demo).forEach(function (name) {
            if (isShown('hud-' + name) || !LAW.huds[name]) return;  // echte Anzeige nicht ueberschreiben
            LAW.huds[name].show(demo[name]);
            demoHuds.push(name);
        });

        var layer = $('toast-layer');
        demoToasts = [];
        if (layer) {
            [
                { kind: 'alert', title: t('ui_layout_demo_alert_title'), text: t('ui_layout_demo_alert_text') },
                { kind: 'info', title: t('ui_layout_demo_toast_title'), text: t('ui_layout_demo_toast_text') },
            ].forEach(function (d) {
                var box = el('div', 'toast toast--' + d.kind + ' toast--demo is-in', [
                    el('span', 'toast__pin'),
                    el('div', { cls: 'toast__title', text: d.title }),
                    el('div', { cls: 'toast__text', text: d.text }),
                ]);
                layer.appendChild(box);
                demoToasts.push(box);
            });
        }

        demoBadge = false;
        if (!isShown('app-badge') && LAW.apps.badge) {
            LAW.apps.badge.open({
                name: LAW.str(samples.name, 'Arthur Morgan'), deptLabel: demo.duty.deptLabel, gradeLabel: demo.duty.gradeLabel,
                badgeNumber: demo.duty.badgeNumber, seal: LAW.str(samples.seal, 'sheriff'), ms: 60000,
            });
            demoBadge = true;
        }
    }

    function hideDemos() {
        demoHuds.forEach(function (name) { if (LAW.huds[name]) LAW.huds[name].hide(); });
        demoHuds = [];
        demoToasts.forEach(function (b) { if (b.parentNode) b.parentNode.removeChild(b); });
        demoToasts = [];
        if (demoBadge && LAW.apps.badge && LAW.apps.badge.hideNow) LAW.apps.badge.hideNow();
        demoBadge = false;
    }

    // ------------------------------------------------------------------
    // Editor
    // ------------------------------------------------------------------
    var work = {};          // Layout waehrend des Bearbeitens
    var saved = false;      // true = Speichern gedrueckt (beim Schliessen nicht zuruecksetzen)
    var handles = {};       // key -> Rahmen-Element
    var selected = null;
    var drag = null;        // { key, sx, sy, left, top, w, h }
    var raf = 0;

    function rectOf(key) {
        var n = $(BY_KEY[key].id);
        if (!n || n.classList.contains('hidden')) return null;
        var r = n.getBoundingClientRect();
        if (!r.width || !r.height) return null;
        return r;
    }

    /** Aktuelle Position messen (fuer Elemente, die noch auf Standard stehen) */
    function ensureEntry(key) {
        if (work[key]) return work[key];
        var r = rectOf(key);
        if (!r) return null;
        work[key] = { x: r.left / window.innerWidth, y: r.top / window.innerHeight, s: 1 };
        return work[key];
    }

    function setPos(key, leftPx, topPx) {
        var v = ensureEntry(key);
        var r = rectOf(key);
        if (!v || !r) return;
        var W = window.innerWidth, H = window.innerHeight;
        leftPx = clamp(leftPx, 0, Math.max(0, W - Math.min(r.width, W)));
        topPx = clamp(topPx, 0, Math.max(0, H - Math.min(r.height, H)));
        v.x = leftPx / W;
        v.y = topPx / H;
        applyOne(key, v);
    }

    function setScale(key, s) {
        var v = ensureEntry(key);
        if (!v) return;
        v.s = Math.round(clamp(s, MIN_S, MAX_S) * 100) / 100;
        applyOne(key, v);
        // nach dem Vergroessern im Bild halten
        var r = rectOf(key);
        if (r) setPos(key, r.left, r.top);
    }

    function resetOne(key) {
        delete work[key];
        applyOne(key, null);
    }

    function select(key) {
        selected = key;
        Object.keys(handles).forEach(function (k) { handles[k].classList.toggle('is-sel', k === key); });
    }

    function buildHandles() {
        var box = LAW.clear($('lay-handles'));
        handles = {};
        TARGETS.forEach(function (d) {
            var h = el('div', { cls: 'lay-handle', attrs: { 'data-key': d.key } }, [
                el('span', 'lay-handle__label', [
                    el('span', { cls: 'lay-handle__name', text: t('ui_layout_' + d.key) }),
                    el('span', { cls: 'lay-handle__size' }),
                ]),
            ]);
            h.addEventListener('mousedown', function (e) {
                if (e.button !== 0) return;
                e.preventDefault();
                select(d.key);
                var r = rectOf(d.key);
                if (!r) return;
                drag = { key: d.key, sx: e.clientX, sy: e.clientY, left: r.left, top: r.top };
                h.classList.add('is-drag');
            });
            h.addEventListener('wheel', function (e) {
                e.preventDefault();
                select(d.key);
                var v = ensureEntry(d.key);
                if (v) setScale(d.key, (v.s || 1) + (e.deltaY < 0 ? STEP_S : -STEP_S));
            }, { passive: false });
            h.addEventListener('dblclick', function (e) {
                e.preventDefault();
                resetOne(d.key);
            });
            box.appendChild(h);
            handles[d.key] = h;
        });
    }

    /** Rahmen ueber die echten Elemente legen (jeden Frame, Inhalte koennen ihre Groesse aendern) */
    function syncHandles() {
        Object.keys(handles).forEach(function (key) {
            var h = handles[key], r = rectOf(key);
            if (!r) { h.classList.add('hidden'); return; }
            h.classList.remove('hidden');
            h.style.left = r.left + 'px';
            h.style.top = r.top + 'px';
            h.style.width = r.width + 'px';
            h.style.height = r.height + 'px';
            // Schild nicht aus dem Bild schieben
            h.classList.toggle('is-right', r.left > window.innerWidth / 2);
            h.classList.toggle('is-top', r.top < 30);
            // Kleine Rahmen ueber grosse (die Marke liegt sonst ueber Ueberfall/Handschellen)
            h.style.zIndex = String(Math.max(1, 100000 - Math.round(r.width * r.height / 50)));
            if (selected === key) h.style.zIndex = '100001';
            var v = work[key];
            h.querySelector('.lay-handle__size').textContent = Math.round(((v && v.s) || 1) * 100) + '%';
            h.classList.toggle('is-custom', !!v);
        });
        raf = window.requestAnimationFrame(syncHandles);
    }

    function onMove(e) {
        if (!drag) return;
        setPos(drag.key, drag.left + (e.clientX - drag.sx), drag.top + (e.clientY - drag.sy));
    }

    function onUp() {
        if (!drag) return;
        if (handles[drag.key]) handles[drag.key].classList.remove('is-drag');
        drag = null;
    }

    function save() {
        var data = clean(work);
        LAW.action('layout', 'save', { layout: data }).then(function (res) {
            if (!res.ok) return;
            saved = true;
            current = clean(res.data && res.data.layout ? res.data.layout : data);
            applyAll(current);
            LAW.closeLayer('layout', 'done');
        });
    }

    function resetAll() {
        work = {};
        applyAll(work);
    }

    LAW.register('layout', {
        root: null,
        setup: function () {
            this.root = $('app-layout');
            $('lay-save').addEventListener('click', save);
            $('lay-reset').addEventListener('click', resetAll);
            $('lay-cancel').addEventListener('click', function () { LAW.closeLayer('layout', 'cancel'); });
            // Werkzeugleiste an der Kopfzeile verschiebbar (falls sie etwas verdeckt)
            var bar = $('lay-bar'), head = $('lay-bar-head'), bd = null;
            head.addEventListener('mousedown', function (e) {
                var r = bar.getBoundingClientRect();
                bd = { sx: e.clientX, sy: e.clientY, left: r.left, top: r.top };
                e.preventDefault();
            });
            document.addEventListener('mousemove', function (e) {
                if (bd) {
                    bar.style.left = clamp(bd.left + e.clientX - bd.sx, 0, window.innerWidth - 60) + 'px';
                    bar.style.top = clamp(bd.top + e.clientY - bd.sy, 0, window.innerHeight - 40) + 'px';
                    bar.style.transform = 'none';
                }
                onMove(e);
            });
            document.addEventListener('mouseup', function () { bd = null; onUp(); });
        },
        open: function (d) {
            d = LAW.obj(d);
            if (d.layout) current = clean(d.layout);
            work = copy(current);
            saved = false;
            selected = null;
            document.body.classList.add('is-layout-editing');
            showDemos(d.samples);
            applyAll(work);
            buildHandles();
            if (!raf) raf = window.requestAnimationFrame(syncHandles);
        },
        onHide: function () {
            if (raf) { window.cancelAnimationFrame(raf); raf = 0; }
            drag = null;
            LAW.clear($('lay-handles'));
            handles = {};
            if (!saved) applyAll(current);   // Abbrechen: gespeichertes Layout wiederherstellen
            hideDemos();
            document.body.classList.remove('is-layout-editing');
        },
        onKey: function (e) {
            if (!selected) return;
            var r = rectOf(selected);
            if (!r) return;
            var step = e.shiftKey ? 10 : 1;
            if (e.key === 'ArrowLeft') { e.preventDefault(); setPos(selected, r.left - step, r.top); }
            else if (e.key === 'ArrowRight') { e.preventDefault(); setPos(selected, r.left + step, r.top); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); setPos(selected, r.left, r.top - step); }
            else if (e.key === 'ArrowDown') { e.preventDefault(); setPos(selected, r.left, r.top + step); }
            else if (e.key === '+' || e.key === '=') { e.preventDefault(); setScale(selected, ((work[selected] || {}).s || 1) + STEP_S); }
            else if (e.key === '-') { e.preventDefault(); setScale(selected, ((work[selected] || {}).s || 1) - STEP_S); }
            else if (e.key === 'Delete' || e.key === 'Backspace') { e.preventDefault(); resetOne(selected); }
        },
    });

    // Fenstergroesse geaendert: Prozentwerte bleiben, nur Rahmen neu (laeuft ueber syncHandles)
})();
