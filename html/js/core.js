/*
    ArA-LawSystem - NUI-Kern
    Router (Vertrag 10.1), Endpoints (Vertrag 10.2), Stapel, t(), Formatierer,
    ESC, Bestaetigungs-/Eingabedialog, Toasts, Debug-Raster.

    Regeln:
      - Daten aus Lua NIE als HTML einsetzen -> nur LAW.el()/textContent.
      - Alle sichtbaren Texte ueber LAW.t('ui_...') (Fallback: Schluessel).
      - Keine ES-Module, kein Build: alles haengt an window.LAW.
*/
(function () {
    'use strict';

    var IN_GAME = typeof GetParentResourceName !== 'undefined';
    var CLOSE_GRACE_MS = 200;   // Wartezeit, bevor ein leerer Stapel `close` postet (siehe C_REPORT)
    var BASE_APPS = { ledger: true, counter: true, board: true };

    var LAW = window.LAW = {
        IN_GAME: IN_GAME,
        RES: IN_GAME ? GetParentResourceName() : 'ArA-LawSystem',
        strings: {},
        currency: '$',
        locale: 'de',
        apps: {},       // name -> { root, open(data), update?(data), onHide?(), onKey?(e), base? }
        huds: {},       // name -> { show(data), hide() }
        stack: [],      // fokussierte Ebenen, letzte = oben
        debug: !IN_GAME && /[?&]debug\b/.test(location.search),
        ready: false,
        lastSeq: 0,     // hoechste `seq` einer fokussierten open-Nachricht -> geht mit `close` zurueck
    };

    // ------------------------------------------------------------------
    // Texte
    // ------------------------------------------------------------------
    LAW.t = function (key) {
        var s = LAW.strings[key];
        if (typeof s !== 'string') s = String(key);
        var args = Array.prototype.slice.call(arguments, 1), i = 0;
        // %s / %d = naechstes Argument, %% = Prozentzeichen (wie string.format)
        s = s.replace(/%[sd%]/g, function (m) {
            if (m === '%%') return '%';
            var v = args[i++];
            return v === undefined || v === null ? '' : String(v);
        });
        return s;
    };

    /** true, wenn ein Schluessel uebersetzt ist (fuer optionale Texte) */
    LAW.has = function (key) { return typeof LAW.strings[key] === 'string'; };

    /** Statische Beschriftungen im HTML: <span data-t="ui_close"></span> */
    LAW.applyStatic = function (root) {
        var list = (root || document).querySelectorAll('[data-t]');
        for (var i = 0; i < list.length; i++) list[i].textContent = LAW.t(list[i].getAttribute('data-t'));
        var ph = (root || document).querySelectorAll('[data-tph]');
        for (var j = 0; j < ph.length; j++) ph[j].setAttribute('placeholder', LAW.t(ph[j].getAttribute('data-tph')));
        var tt = (root || document).querySelectorAll('[data-tt]');
        for (var k = 0; k < tt.length; k++) tt[k].setAttribute('title', LAW.t(tt[k].getAttribute('data-tt')));
    };

    // ------------------------------------------------------------------
    // DOM-Helfer (kein innerHTML!)
    // ------------------------------------------------------------------
    /**
     * LAW.el('div', 'klasse', [kinder])  oder
     * LAW.el('button', { cls, text, title, type, value, disabled, attrs, style, data, on }, [kinder])
     * Strings in `kinder` werden zu Textknoten.
     */
    LAW.el = function (tag, opts, kids) {
        var e = document.createElement(tag);
        var k;
        if (typeof opts === 'string') {
            e.className = opts;
        } else if (opts) {
            if (opts.cls) e.className = opts.cls;
            if (opts.text !== undefined && opts.text !== null) e.textContent = String(opts.text);
            if (opts.title) e.title = String(opts.title);
            if (opts.type) e.type = opts.type;
            if (opts.value !== undefined && opts.value !== null) e.value = opts.value;
            if (opts.disabled) e.disabled = true;
            if (opts.attrs) for (k in opts.attrs) if (opts.attrs[k] !== undefined && opts.attrs[k] !== null) e.setAttribute(k, opts.attrs[k]);
            if (opts.style) for (k in opts.style) e.style[k] = opts.style[k];
            if (opts.data) for (k in opts.data) e.setAttribute('data-' + k, opts.data[k]);
            if (opts.on) for (k in opts.on) e.addEventListener(k, opts.on[k]);
        }
        if (kids !== undefined && kids !== null) LAW.append(e, kids);
        return e;
    };

    LAW.append = function (parent, kids) {
        if (!Array.isArray(kids)) kids = [kids];
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i];
            if (c === undefined || c === null || c === false) continue;
            if (Array.isArray(c)) { LAW.append(parent, c); continue; }
            parent.appendChild(typeof c === 'object' ? c : document.createTextNode(String(c)));
        }
        return parent;
    };

    LAW.clear = function (node) { while (node && node.firstChild) node.removeChild(node.firstChild); return node; };
    LAW.$ = function (id) { return document.getElementById(id); };

    /**
     * Knopf mit Sperre waehrend asynchroner Arbeit (verhindert Doppelklicks).
     * variant: '' | 'danger' | 'ghost' | 'small' ... (Leerzeichen-getrennt)
     */
    LAW.btn = function (label, onClick, variant, opts) {
        opts = opts || {};
        var cls = 'btn';
        if (variant) variant.split(' ').forEach(function (v) { if (v) cls += ' btn--' + v; });
        var b = LAW.el('button', { cls: cls, text: label, type: 'button', disabled: !!opts.disabled, title: opts.title });
        var busy = false;
        b.addEventListener('click', function (ev) {
            ev.stopPropagation();
            if (busy || b.disabled || !onClick) return;
            busy = true; b.classList.add('is-busy');
            var done = function () { busy = false; b.classList.remove('is-busy'); };
            try {
                var r = onClick(ev);
                if (r && typeof r.then === 'function') r.then(done, done); else done();
            } catch (err) { done(); LAW.logError(err); }
        });
        return b;
    };

    LAW.logError = function (err) {
        if (window.console && console.warn) console.warn('[ArA-Law NUI]', err && err.stack ? err.stack : err);
    };

    // ------------------------------------------------------------------
    // Daten-Helfer
    // ------------------------------------------------------------------
    /** Lua schickt leere Tabellen als {} oder [] und duenne Listen als Objekt -> immer Array */
    LAW.arr = function (x) {
        if (Array.isArray(x)) return x;
        if (x && typeof x === 'object') return Object.keys(x).map(function (k) { return x[k]; });
        return [];
    };
    LAW.obj = function (x) { return x && typeof x === 'object' && !Array.isArray(x) ? x : {}; };
    LAW.num = function (x, def) { var n = Number(x); return isFinite(n) ? n : (def === undefined ? 0 : def); };
    LAW.str = function (x, def) { return x === undefined || x === null || x === '' ? (def === undefined ? '' : def) : String(x); };

    LAW.hasPerm = function (perms, p) {
        var list = LAW.arr(perms);
        return list.indexOf('all') >= 0 || list.indexOf(p) >= 0;
    };
    LAW.hasAnyPerm = function (perms, arr) {
        for (var i = 0; i < arr.length; i++) if (LAW.hasPerm(perms, arr[i])) return true;
        return false;
    };

    var SEAL_ALIAS = { judge: 'court', prisonguard: 'prison', sisika: 'prison', usm: 'marshal', sdpd: 'police' };
    var SEALS = { sheriff: 1, marshal: 1, police: 1, pinkerton: 1, prison: 1, court: 1 };
    LAW.sealKey = function (s) {
        s = String(s || '').toLowerCase();
        if (SEAL_ALIAS[s]) s = SEAL_ALIAS[s];
        return SEALS[s] ? s : 'sheriff';
    };

    // ------------------------------------------------------------------
    // Formatierer
    // ------------------------------------------------------------------
    function pad(n) { return n < 10 ? '0' + n : String(n); }
    LAW.fmt = {
        date: function (ts) {
            ts = Number(ts);
            if (!ts) return '–';
            var d = new Date(ts * 1000);
            return pad(d.getDate()) + '.' + pad(d.getMonth() + 1) + '.' + d.getFullYear() + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
        },
        day: function (ts) {
            ts = Number(ts);
            if (!ts) return '–';
            var d = new Date(ts * 1000);
            return pad(d.getDate()) + '.' + pad(d.getMonth() + 1) + '.' + d.getFullYear();
        },
        /** Sekunden -> "1h 5m" / "12m" / "40s" */
        duration: function (sec) {
            sec = Math.max(0, Math.floor(Number(sec) || 0));
            if (sec < 60) return sec + 's';
            var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
            if (d > 0) return d + 'd ' + h + 'h';
            if (h > 0) return h + 'h ' + m + 'm';
            return m + 'm';
        },
        minutes: function (min) { return LAW.fmt.duration(LAW.num(min) * 60); },
        /** Sekunden -> "1:05:09" / "05:09" (HUD) */
        clock: function (sec) {
            sec = Math.max(0, Math.floor(Number(sec) || 0));
            var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
            return (h > 0 ? h + ':' + pad(m) : pad(m)) + ':' + pad(s);
        },
        money: function (n) {
            var v = LAW.num(n);
            return (v < 0 ? '-' : '') + LAW.currency + Math.abs(v).toFixed(2);
        },
        signedMoney: function (n) {
            var v = LAW.num(n);
            return (v > 0 ? '+' : v < 0 ? '-' : '') + LAW.currency + Math.abs(v).toFixed(2);
        },
    };

    // ------------------------------------------------------------------
    // JS -> Lua (Vertrag 10.2)
    // ------------------------------------------------------------------
    LAW.post = function (endpoint, body) {
        body = body || {};
        if (!IN_GAME) {
            var mock = LAW.mockPost ? LAW.mockPost(endpoint, body) : { ok: true };
            return Promise.resolve(mock);
        }
        return fetch('https://' + LAW.RES + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body),
        }).then(function (r) { return r.text(); }).then(function (tx) {
            if (!tx) return { ok: true };
            try { return JSON.parse(tx); } catch (e) { return { ok: false, err: 'bad_response' }; }
        }).catch(function () { return { ok: false, err: 'no_response' }; });
    };

    function normalize(res) {
        if (!res || typeof res !== 'object' || Array.isArray(res)) return { ok: false, err: 'no_response' };
        if (res.ok === undefined) return { ok: true, data: res };
        return res;
    }

    function errText(res) {
        if (res.msg) return String(res.msg);
        if (res.err && LAW.has('ui_err_' + res.err)) return LAW.t('ui_err_' + res.err);
        return LAW.t('ui_err_generic');
    }
    LAW.errText = errText;

    function report(res, opts) {
        opts = opts || {};
        if (!res.ok) {
            if (!opts.silent && res.err !== 'cancelled') LAW.hint(errText(res), 'error');
        } else if (res.msg && !opts.quiet) {
            LAW.hint(String(res.msg), 'success');
        }
        return res;
    }

    /** Server-Callback (Vertrag 10.5). opts: { silent: keine Fehler, quiet: keine Erfolgsmeldung } */
    LAW.cb = function (name, args, opts) {
        return LAW.post('cb', { name: name, args: args || [] }).then(normalize).then(function (res) { return report(res, opts); });
    };

    /** App-Aktion -> Law.UI.OnAction(app, name, fn) */
    LAW.action = function (app, name, payload, opts) {
        return LAW.post('action', { app: app, name: name, payload: payload || {} }).then(normalize).then(function (res) { return report(res, opts); });
    };

    // ------------------------------------------------------------------
    // Stapel
    // ------------------------------------------------------------------
    var closeTimer = null;

    function cancelClose() { if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; } }

    function syncLayers() {
        var n = LAW.stack.length;
        for (var i = 0; i < n; i++) {
            var a = LAW.apps[LAW.stack[i]];
            a.root.style.zIndex = String(20 + i * 2);
            a.root.classList.toggle('is-top', i === n - 1);
        }
        document.body.classList.toggle('has-focus', n > 0);
    }

    LAW.isOpen = function (name) { return LAW.stack.indexOf(name) >= 0; };
    LAW.top = function () { return LAW.stack.length ? LAW.stack[LAW.stack.length - 1] : null; };

    LAW.register = function (name, def) {
        def.name = name;
        def.base = !!BASE_APPS[name];
        LAW.apps[name] = def;
    };

    LAW.open = function (name, data, nofocus) {
        var app = LAW.apps[name];
        if (!app) { LAW.logError('Unbekannte App: ' + name); return; }
        data = data || {};
        if (nofocus || app.nofocus) { app.open(data); return; }     // z.B. Marke: nicht im Stapel

        cancelClose();
        LAW.closeModal();
        var idx = LAW.stack.indexOf(name);
        if (idx >= 0) LAW.stack.splice(idx, 1);
        if (app.base) {
            // Nur eine Grund-App gleichzeitig (Dienstbuch ODER Schalter ODER Brett)
            LAW.stack.slice().forEach(function (other) { if (other !== name && LAW.apps[other].base) LAW.hideLayer(other); });
            LAW.stack.unshift(name);
        } else {
            LAW.stack.push(name);
        }
        app.root.classList.remove('hidden');
        syncLayers();
        try { app.open(data); } catch (err) { LAW.logError(err); }
    };

    LAW.update = function (name, data) {
        var app = LAW.apps[name];
        if (!app || !LAW.isOpen(name) || !app.update) return;
        try { app.update(data || {}); } catch (err) { LAW.logError(err); }
    };

    /** Ebene nur ausblenden (ohne Lua-Nachricht) */
    LAW.hideLayer = function (name) {
        var idx = LAW.stack.indexOf(name);
        if (idx < 0) return;
        LAW.stack.splice(idx, 1);
        var app = LAW.apps[name];
        app.root.classList.add('hidden');
        app.root.classList.remove('is-top');
        if (app.onHide) { try { app.onHide(); } catch (err) { LAW.logError(err); } }
        syncLayers();
    };

    /** Ist der Stapel leer, nach kurzer Gnadenfrist `close` posten (Lua gibt den Fokus frei). */
    LAW.scheduleClose = function () {
        if (LAW.stack.length) return;
        cancelClose();
        closeTimer = setTimeout(function () {
            closeTimer = null;
            if (!LAW.stack.length) { LAW.closeModal(); LAW.post('close', { seq: LAW.lastSeq }); }
        }, CLOSE_GRACE_MS);
    };

    /**
     * Ebene schliessen.
     * reason 'cancel' (ESC/Knopf): menu -> menuCancel, form -> formCancel, sonst nur ausblenden.
     */
    LAW.closeLayer = function (name, reason) {
        if (!LAW.isOpen(name)) return;
        LAW.hideLayer(name);
        if (reason !== 'done') {
            if (name === 'menu') LAW.post('menuCancel');
            else if (name === 'form') LAW.post('formCancel');
        }
        LAW.scheduleClose();
    };

    LAW.closeTop = function () {
        var top = LAW.top();
        if (top) LAW.closeLayer(top, 'cancel');
    };

    /** `close` von Lua: alles Fokussierte weg, KEIN Post zurueck */
    LAW.closeAll = function () {
        cancelClose();
        LAW.closeModal();
        LAW.stack.slice().forEach(LAW.hideLayer);
    };

    // ------------------------------------------------------------------
    // Toasts
    // ------------------------------------------------------------------
    var TOAST_KINDS = { info: 1, success: 1, error: 1, alert: 1 };
    var MAX_TOASTS = 6;

    LAW.toast = function (d) {
        d = LAW.obj(d);
        var layer = LAW.$('toast-layer');
        if (!layer) return;
        var kind = TOAST_KINDS[d.kind] ? d.kind : 'info';
        var ms = Math.max(1500, Math.min(LAW.num(d.ms, 6000) || 6000, 120000));
        var box = LAW.el('div', 'toast toast--' + kind, [
            LAW.el('span', 'toast__pin'),
            d.title ? LAW.el('div', { cls: 'toast__title', text: d.title }) : null,
            d.text ? LAW.el('div', { cls: 'toast__text', text: d.text }) : null,
        ]);
        var gone = false;
        var remove = function () {
            if (gone) return;
            gone = true;
            box.classList.add('is-out');
            setTimeout(function () { if (box.parentNode) box.parentNode.removeChild(box); }, 320);
        };
        box.addEventListener('click', remove);
        layer.insertBefore(box, layer.firstChild);
        while (layer.children.length > MAX_TOASTS) layer.removeChild(layer.lastChild);
        setTimeout(function () { box.classList.add('is-in'); }, 16);
        setTimeout(remove, ms);
    };

    /** Kurzer Hinweis (Ergebnis eines Callbacks) */
    LAW.hint = function (text, kind) {
        LAW.toast({ text: text, kind: kind || 'info', ms: kind === 'error' ? 5500 : 4000 });
    };

    // ------------------------------------------------------------------
    // Modale Dialoge (Bestaetigen / kleine Eingabe) - gehoeren NICHT zum Stapel
    // ------------------------------------------------------------------
    var modal = null;   // { node, resolve, onKey }

    LAW.closeModal = function (value) {
        if (!modal) return;
        var m = modal;
        modal = null;
        var layer = LAW.$('modal-layer');
        LAW.clear(layer);
        layer.classList.add('hidden');
        m.resolve(value === undefined ? null : value);
    };

    LAW.modalOpen = function () { return !!modal; };

    /**
     * Basis fuer Dialoge. build(done) liefert den Inhalt; done(wert) schliesst.
     * onEnter(): optional, wird bei Enter aufgerufen.
     */
    LAW.openModal = function (build, opts) {
        opts = opts || {};
        LAW.closeModal(null);
        return new Promise(function (resolve) {
            var layer = LAW.$('modal-layer');
            var done = function (v) { if (modal && modal.resolve === resolve) LAW.closeModal(v); };
            modal = { resolve: resolve, onEnter: null, cancelValue: opts.cancelValue === undefined ? null : opts.cancelValue };
            var box = LAW.el('div', 'modal paper' + (opts.danger ? ' modal--danger' : ''));
            var content = build(done, function (fn) { if (modal) modal.onEnter = fn; });
            LAW.append(box, content);
            LAW.clear(layer);
            layer.appendChild(box);
            layer.classList.remove('hidden');
            var first = box.querySelector('input:not([type=checkbox]), textarea, select');
            if (first) setTimeout(function () { first.focus(); }, 30);
            else {
                var ok = box.querySelector('.modal__ok');
                if (ok) setTimeout(function () { ok.focus(); }, 30);
            }
        });
    };

    function modalKey(e) {
        if (!modal) return false;
        if (e.key === 'Escape') {
            e.preventDefault();
            LAW.closeModal(modal.cancelValue);
            return true;
        }
        // Enter auf einem fokussierten Knopf loest dessen eigenen Klick aus (z.B. Abbrechen)
        var tag = e.target && e.target.tagName;
        if (e.key === 'Enter' && modal.onEnter && tag !== 'TEXTAREA' && tag !== 'BUTTON') {
            e.preventDefault();
            modal.onEnter();
            return true;
        }
        return true;   // Tasten nicht an die App darunter weitergeben
    }

    /** Bestaetigung (gefaehrliche Aktionen). -> Promise<bool> */
    LAW.confirm = function (text, opts) {
        opts = opts || {};
        return LAW.openModal(function (done, onEnter) {
            onEnter(function () { done(true); });
            return [
                LAW.el('div', { cls: 'modal__title', text: opts.title || LAW.t('ui_confirm_title') }),
                LAW.el('div', { cls: 'modal__text', text: text }),
                LAW.el('div', 'modal__buttons', [
                    LAW.btn(opts.cancelLabel || LAW.t('ui_cancel'), function () { done(false); }, 'ghost'),
                    (function () {
                        var b = LAW.btn(opts.okLabel || LAW.t('ui_confirm_ok'), function () { done(true); }, opts.danger === false ? '' : 'danger');
                        b.classList.add('modal__ok');
                        return b;
                    })(),
                ]),
            ];
        }, { danger: opts.danger !== false, cancelValue: false }).then(function (v) { return v === true; });
    };

    /**
     * Kleiner Eingabedialog mit Feldern wie im Formular (Vertrag 10.3 Field).
     * -> Promise<values|null>. Benutzt LAW.Fields (ui.js).
     */
    LAW.dialog = function (def) {
        def = def || {};
        var form = null;
        return LAW.openModal(function (done, onEnter) {
            form = LAW.Fields.build(LAW.arr(def.fields), { compact: true });
            var submit = function () {
                var res = form.collect();
                if (!res.ok) { LAW.hint(res.msg, 'error'); return; }
                if (def.confirm) {
                    var text = typeof def.confirm === 'function' ? def.confirm(res.values) : def.confirm;
                    var values = res.values;
                    // Bestaetigung ersetzt den Dialog -> Ergebnis weiterreichen
                    var resolveOuter = modal.resolve;
                    modal = null;
                    LAW.confirm(text, { title: def.title }).then(function (ok) { resolveOuter(ok ? values : null); });
                    return;
                }
                done(res.values);
            };
            onEnter(submit);
            var okBtn = LAW.btn(def.okLabel || LAW.t('ui_ok'), submit, def.danger ? 'danger' : '');
            okBtn.classList.add('modal__ok');
            return [
                LAW.el('div', { cls: 'modal__title', text: def.title || '' }),
                def.text ? LAW.el('div', { cls: 'modal__text', text: def.text }) : null,
                form.node,
                LAW.el('div', 'modal__buttons', [
                    LAW.btn(LAW.t('ui_cancel'), function () { done(null); }, 'ghost'),
                    okBtn,
                ]),
            ];
        }, { danger: !!def.danger, cancelValue: null });
    };

    // ------------------------------------------------------------------
    // HUDs
    // ------------------------------------------------------------------
    LAW.hud = function (name, data) {
        var h = LAW.huds[name];
        if (!h) return;
        try {
            if (data === undefined || data === null || data === false) h.hide();
            else h.show(LAW.obj(data));
        } catch (err) { LAW.logError(err); }
    };

    // ------------------------------------------------------------------
    // Lua -> JS (Vertrag 10.1)
    // ------------------------------------------------------------------
    function applyInit(d) {
        d = LAW.obj(d);
        LAW.strings = LAW.obj(d.strings);
        if (d.currency) LAW.currency = String(d.currency);
        if (d.locale) { LAW.locale = String(d.locale); document.documentElement.lang = LAW.locale; }
        if (d.resource && !IN_GAME) LAW.RES = String(d.resource);
        LAW.ready = true;
        LAW.applyStatic();
        Object.keys(LAW.apps).forEach(function (k) { if (LAW.apps[k].onInit) { try { LAW.apps[k].onInit(); } catch (err) { LAW.logError(err); } } });
        Object.keys(LAW.huds).forEach(function (k) { if (LAW.huds[k].onInit) { try { LAW.huds[k].onInit(); } catch (err) { LAW.logError(err); } } });
        // eigenes Layout des Spielers (/editlawinterface)
        if (LAW.Layout && d.layout) { try { LAW.Layout.apply(d.layout); } catch (err) { LAW.logError(err); } }
    }

    LAW.handleMessage = function (m) {
        if (!m || typeof m !== 'object') return;
        switch (m.type) {
            case 'init':   applyInit(m.data); break;
            case 'open': {
                var nofocus = !!(m.nofocus || (m.data && m.data.nofocus));
                var seq = Number(m.seq);
                if (!nofocus && isFinite(seq) && seq > LAW.lastSeq) LAW.lastSeq = seq;
                LAW.open(String(m.app || ''), LAW.obj(m.data), nofocus);
                break;
            }
            case 'update': LAW.update(String(m.app || ''), LAW.obj(m.data)); break;
            case 'close':  LAW.closeAll(); break;
            case 'hud':    LAW.hud(String(m.hud || ''), m.data); break;
            case 'toast':  LAW.toast(m.data); break;
        }
    };

    window.addEventListener('message', function (ev) {
        try { LAW.handleMessage(ev.data); } catch (err) { LAW.logError(err); }
    });

    // ------------------------------------------------------------------
    // Tastatur
    // ------------------------------------------------------------------
    document.addEventListener('keydown', function (e) {
        if (modalKey(e)) return;
        var top = LAW.top();
        if (!top) return;
        if (e.key === 'Escape') {
            e.preventDefault();
            LAW.closeTop();
            return;
        }
        var app = LAW.apps[top];
        if (app.onKey) { try { app.onKey(e); } catch (err) { LAW.logError(err); } }
    });

    // ------------------------------------------------------------------
    // Debug-Raster (?debug im Browser): Klick in eine Buehne -> Prozentwerte
    // ------------------------------------------------------------------
    function setupDebug() {
        if (!LAW.debug) return;
        document.body.classList.add('debug');
        document.addEventListener('click', function (e) {
            var st = e.target && e.target.closest ? e.target.closest('.stage') : null;
            if (!st) return;
            var r = st.getBoundingClientRect();
            var x = ((e.clientX - r.left) / r.width * 100).toFixed(2);
            var y = ((e.clientY - r.top) / r.height * 100).toFixed(2);
            console.log('[debug] ' + (st.id || 'stage') + '  left:' + x + '%; top:' + y + '%;');
            var dot = LAW.el('div', { cls: 'debug-dot', style: { left: x + '%', top: y + '%' } });
            st.appendChild(dot);
            setTimeout(function () { if (dot.parentNode) dot.parentNode.removeChild(dot); }, 4000);
        }, true);
        console.log('[debug] Raster aktiv - in eine Buehne klicken, um left/top in % zu erhalten.');
    }

    // ------------------------------------------------------------------
    // Start: `ready` posten -> Lua schickt `init`
    // ------------------------------------------------------------------
    document.addEventListener('DOMContentLoaded', function () {
        LAW.applyStatic();
        Object.keys(LAW.apps).forEach(function (k) { if (LAW.apps[k].setup) { try { LAW.apps[k].setup(); } catch (err) { LAW.logError(err); } } });
        Object.keys(LAW.huds).forEach(function (k) { if (LAW.huds[k].setup) { try { LAW.huds[k].setup(); } catch (err) { LAW.logError(err); } } });
        setupDebug();
        if (!IN_GAME && LAW.devStart) LAW.devStart();
        LAW.post('ready');
    });
})();
