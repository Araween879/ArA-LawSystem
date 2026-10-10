/*
    ArA-LawSystem - Browser-Testmodus
    Nur aktiv, wenn die Seite NICHT in RedM laeuft (typeof GetParentResourceName === 'undefined').
      - LAW.mockPost: beantwortet ready, close, cb, action, menuSelect/menuCancel, formSubmit/formCancel wie die Lua-Seite
      - jeder Callback-Name aus Vertrag 10.5 hat eine Testantwort (Zustand wird im Speicher veraendert)
      - Testleiste oben links: jede App, jedes Dokument, jede Marke, jedes HUD, Toasts, update, close
    Die Beschriftungen der Testleiste sind Entwickler-Werkzeug und NICHT uebersetzt (im Spiel unsichtbar).
*/
(function () {
    'use strict';
    if (typeof GetParentResourceName !== 'undefined') return;

    var LAW = window.LAW, M = window.LAW_MOCK;
    if (!LAW || !M) return;
    var S = M.strings;
    var D = 86400, H = 3600;
    var seq = 0;

    // ------------------------------------------------------------------
    // Lua-Seite nachahmen
    // ------------------------------------------------------------------
    /** wie SendNUIMessage: asynchron ueber postMessage, fokussierte open-Nachrichten bekommen seq */
    function send(msg) {
        if (msg.type === 'open' && !msg.nofocus) msg.seq = ++seq;
        window.postMessage(JSON.parse(JSON.stringify(msg)), '*');
    }
    function ok(data, msg) { return { ok: true, data: data, msg: msg }; }
    function fail(err, msg) { return { ok: false, err: err, msg: msg }; }
    function delay(v, ms) { return new Promise(function (res) { setTimeout(function () { res(v); }, ms || 160); }); }
    function nowS() { return Math.floor(Date.now() / 1000); }
    function find(list, key, val) { for (var i = 0; i < list.length; i++) if (String(list[i][key]) === String(val)) return list[i]; return null; }
    function removeFrom(list, key, val) { for (var i = list.length - 1; i >= 0; i--) if (String(list[i][key]) === String(val)) list.splice(i, 1); }
    function r2(n) { return Math.round(n * 100) / 100; }
    function statusLabel(s) { return S['ui_status_' + s] || s; }
    function setStatus(list, id, to, from, msg) {
        var x = find(list, 'id', id);
        if (!x) return fail('not_found', 'Nicht gefunden.');
        if (from && from.indexOf(x.status) < 0) return fail('already_done', 'Das wurde bereits erledigt.');
        x.status = to; x.statusLabel = statusLabel(to);
        return ok({ id: x.id }, msg);
    }
    function byStatus(list, st, groups) {
        if (!st || st === 'all') return list;
        var allowed = groups && groups[st] ? groups[st] : [st];
        return list.filter(function (x) { return allowed.indexOf(x.status) >= 0; });
    }

    // blockierende Menues/Formulare wie Law.UI.Menu / Law.UI.Form
    var pending = { menu: null, form: null };
    function uiMenu(def) {
        if (pending.menu) pending.menu(null);
        return new Promise(function (res) { pending.menu = res; send({ type: 'open', app: 'menu', data: def }); });
    }
    function uiForm(def) {
        if (pending.form) pending.form(null);
        return new Promise(function (res) { pending.form = res; send({ type: 'open', app: 'form', data: def }); });
    }
    function resolvePending(kind, value) {
        var p = pending[kind];
        pending[kind] = null;
        if (p) p(value);
    }

    // ------------------------------------------------------------------
    // Akte zusammenbauen (Form File, Vertrag 10.6)
    // ------------------------------------------------------------------
    var fileExtra = {
        101: { bloodType: 'B+', notes: 'Bewaffnet. Reitet einen weißen Araber. Nicht allein festnehmen!',
               licenses: [{ type: 'bounty', status: 'active', expiresAt: nowS() + 5 * D }] },
        102: { bloodType: 'O-', notes: '', licenses: [] },
    };
    var records = [
        { id: 1, charId: 101, type: 'warrant', typeLabel: 'Haftbefehl', title: 'Haftbefehl Nr. 31 ausgestellt', details: 'Bankraub in Valentine, ein Kassierer erschossen.', officerName: 'Arthur Callahan', deptLabel: 'County Sheriff', createdAt: nowS() - 3 * D },
        { id: 2, charId: 101, type: 'fine', typeLabel: 'Bußgeld', title: 'Bußgeld $60', details: 'Zweimal in Valentine in die Luft geschossen.', officerName: 'Arthur Callahan', deptLabel: 'County Sheriff', createdAt: nowS() - 5 * D },
        { id: 3, charId: 101, type: 'note', typeLabel: 'Notiz', title: 'Zeugenaussage', details: 'Zeuge (Barkeeper) sah ihn mit Bill Williamson.\nZweite Zeile der Notiz.', officerName: 'Jim Hawkins', deptLabel: 'County Sheriff', createdAt: nowS() - 2 * D },
        { id: 4, charId: 102, type: 'jail', typeLabel: 'Haft', title: 'Haft 40 Min.', details: 'Körperverletzung, Widerstand', officerName: 'Leigh Gray', deptLabel: 'Saint Denis Police', createdAt: nowS() - H },
    ];
    function buildFile(charId) {
        var p = find(M.people, 'charId', charId);
        if (!p) return null;
        var x = fileExtra[charId] || {};
        var weapons = Object.keys(M.weapons).map(function (k) { return M.weapons[k]; })
            .filter(function (w) { return String(w.ownerCharId) === String(charId); })
            .map(function (w) { return { serial: w.serial, weapon: w.weapon, weaponLabel: w.weaponLabel, status: w.status, statusLabel: w.statusLabel }; });
        return {
            charId: p.charId, name: p.name, age: p.age, gender: p.gender, bloodType: x.bloodType, dangerous: !!(p.flags && p.flags.dangerous),
            notes: x.notes, flags: p.flags,
            records: records.filter(function (r) { return String(r.charId) === String(charId); }),
            fines: M.fines.filter(function (f) { return String(f.charId) === String(charId); }),
            warrants: M.warrants.filter(function (w) { return String(w.charId) === String(charId); }),
            bounties: M.bounties.filter(function (b) { return String(b.charId) === String(charId); }),
            jail: find(M.inmates, 'charId', charId),
            weapons: weapons,
            licenses: x.licenses || [],
        };
    }

    // ------------------------------------------------------------------
    // Eskorte: Preis wie bei Agent B (vereinfacht)
    // ------------------------------------------------------------------
    function quote(v) {
        v = v || {};
        var o = M.escortOptions;
        var t = find(o.types, 'value', v.type);
        if (!t) return fail('escort_bad_type', 'Unbekannte Auftragsart.');
        var bd = [], price = 0;
        var add = function (label, amt) { amt = r2(amt); if (amt) bd.push({ label: label, amount: amt }); return amt; };
        var km = 0;
        if (v.type === 'bodyguard') {
            if (!v.durationMin) return fail('escort_bad_duration', 'Bitte eine Dauer wählen.');
            price += add('Grundpreis', 50);
            price += add('Dauer (' + v.durationMin + ' Min.)', 1.5 * v.durationMin);
        } else {
            var d = find(o.destinations, 'value', v.destination);
            if (!d) return fail('escort_bad_destination', 'Bitte ein Ziel wählen.');
            km = d.km;
            price += add('Grundpreis', v.type === 'cargo' ? 60 : 30);
            price += add('Strecke (' + km + ' km)', (v.type === 'cargo' ? 10 : 8) * km);
        }
        var cargoValue = 0;
        (v.cargo || []).forEach(function (c) { var it = find(o.cargoItems, 'name', c.name); if (it) cargoValue += it.unitValue * c.amount; });
        cargoValue += (v.money || 0) + (v.gold || 0) * 20;
        if (v.type === 'cargo') {
            if (cargoValue <= 0) return fail('escort_empty_cargo', 'Bitte Fracht, Geld oder Gold angeben.');
            price += add('Warenwert-Aufschlag', 0.05 * cargoValue);
        }
        if (v.escorts > 1) price += add('Zusätzliche Begleiter (' + (v.escorts - 1) + ')', 20 * (v.escorts - 1));
        var premium = v.type === 'cargo' && v.insurance ? add('Versicherungsprämie', 0.08 * cargoValue) : 0;
        if (v.money > 0) add('Bargeld zur Beförderung', v.money);
        return ok({ price: r2(price), premium: premium, total: r2(price + premium + (v.money || 0)), goldTotal: v.gold || 0,
            cargoValue: cargoValue, km: km, deadlineMinutes: v.type === 'bodyguard' ? v.durationMin : Math.max(15, Math.ceil(km * 6)), breakdown: bd });
    }

    // ------------------------------------------------------------------
    // Callbacks (Vertrag 10.5 + Zusaetze)
    // ------------------------------------------------------------------
    var CB = {
        // Kern
        'core:ledgerOpen': function () { return ok({ officer: M.officer }); },
        'core:ledgerOverview': function () { return ok(M.overview); },
        'core:counterOpen': function () { return ok(M.counter); },
        'core:boardOpen': function () { return ok({ station: 'valentine', stationLabel: 'Valentine', canHunt: true }); },
        'dispatch:list': function () { return ok(M.overview.alerts); },
        'dispatch:accept': function (id) {
            var a = find(M.overview.alerts, 'id', id);
            if (!a) return fail('not_found', 'Einsatz nicht gefunden.');
            if (!a.mine) { a.mine = true; a.responders.push(M.officer.name); }
            return ok({ coords: a.coords });
        },
        'dispatch:close': function (id) { removeFrom(M.overview.alerts, 'id', id); return ok(); },
        'dispatch:report': function (text) {
            if (!text || String(text).length < 5) return fail('invalid', 'Ungültige Eingabe.');
            return ok(null, 'Deine Anzeige wurde aufgenommen.');
        },
        // Akten
        'records:search': function (q) {
            q = String(q || '').toLowerCase();
            if (q.length < 2) return fail('invalid', 'Bitte mindestens 2 Zeichen.');
            return ok(M.people.filter(function (p) { return p.name.toLowerCase().indexOf(q) >= 0; }));
        },
        'records:getFile': function (charId) { var f = buildFile(charId); return f ? ok(f) : fail('not_found', 'Akte nicht gefunden.'); },
        'records:addNote': function (charId, title, text) {
            var id = records.length + 10;
            records.unshift({ id: id, charId: charId, type: 'note', typeLabel: 'Notiz', title: title, details: text, officerName: M.officer.name, deptLabel: M.officer.deptLabel, createdAt: nowS() });
            return ok({ id: id }, 'Notiz gespeichert.');
        },
        'records:setDangerous': function (charId, v) {
            var p = find(M.people, 'charId', charId);
            if (!p) return fail('not_found');
            p.flags = p.flags || {}; p.flags.dangerous = !!v;
            return ok({ dangerous: !!v }, v ? 'Als gefährlich markiert.' : 'Markierung entfernt.');
        },
        // Haftbefehle
        'warrants:list': function (st) { return ok(byStatus(M.warrants, st, { open: ['pending', 'active'] })); },
        'warrants:approve': function (id) { return setStatus(M.warrants, id, 'active', ['pending'], 'Haftbefehl freigegeben.'); },
        'warrants:revoke': function (id) { return setStatus(M.warrants, id, 'revoked', ['pending', 'active'], 'Haftbefehl widerrufen.'); },
        // Kopfgelder
        'bounty:list': function (st) { return ok(byStatus(M.bounties, st, { open: ['pending', 'active'] })); },
        'bounty:approve': function (id) { return setStatus(M.bounties, id, 'active', ['pending'], 'Kopfgeld freigegeben.'); },
        'bounty:cancel': function (id) { return setStatus(M.bounties, id, 'cancelled', ['pending', 'active'], 'Kopfgeld storniert, Betrag erstattet.'); },
        'bounty:revokeLicense': function (charId) {
            var x = fileExtra[charId];
            if (!x || !x.licenses.length) return fail('not_found', 'Keine Lizenz vorhanden.');
            x.licenses.forEach(function (l) { if (l.type === 'bounty') l.status = 'revoked'; });
            return ok(null, 'Lizenz entzogen.');
        },
        // Bussgelder
        'fines:list': function (st) { return ok(byStatus(M.fines, st, { unpaid: ['open', 'overdue'] })); },
        'fines:cancel': function (id) { return setStatus(M.fines, id, 'cancelled', ['open', 'overdue'], 'Bußgeld storniert.'); },
        // Gefaengnis
        'jail:list': function () { return ok(M.inmates); },
        'jail:release': function (charId) { removeFrom(M.inmates, 'charId', charId); removeFrom(M.bailList, 'charId', charId); return ok({ charId: charId }, 'Häftling freigelassen.'); },
        'jail:adjust': function (charId, delta) {
            var i = find(M.inmates, 'charId', charId);
            if (!i) return fail('not_found');
            i.sentence = Math.max(0, i.sentence + delta * 60);
            i.remaining = Math.max(0, i.remaining + delta * 60);
            if (i.remaining <= 0) { removeFrom(M.inmates, 'charId', charId); return ok({ charId: charId, released: true }, 'Haftzeit abgelaufen – freigelassen.'); }
            return ok({ charId: charId, sentence: i.sentence }, 'Haftzeit geändert.');
        },
        'jail:setBail': function (charId, amount) {
            var i = find(M.inmates, 'charId', charId);
            if (!i) return fail('not_found');
            i.bail = amount > 0 ? amount : null;
            removeFrom(M.bailList, 'charId', charId);
            if (i.bail) M.bailList.push({ charId: charId, name: i.name, bail: i.bail });
            return ok({ charId: charId, bail: i.bail }, i.bail ? 'Kaution festgesetzt.' : 'Kaution entfernt.');
        },
        // Beweise
        'evidence:list': function (f) {
            if (f && typeof f === 'object') f = f.status;
            var list = M.evidence;
            if (!f) list = list.filter(function (e) { return e.status !== 'destroyed'; });
            else if (f !== 'all') list = list.filter(function (e) { return e.status === f; });
            return ok(list);
        },
        'evidence:get': function (id) { var e = find(M.evidence, 'id', id); return e ? ok(e) : fail('not_found'); },
        'evidence:destroy': function (id) { return setStatus(M.evidence, id, 'destroyed', ['collected', 'analyzed'], 'Beweis vernichtet.'); },
        // Waffen
        'weapons:lookup': function (serial) {
            var w = M.weapons[String(serial || '').trim().toUpperCase()];
            return w ? ok(w) : fail('not_found', 'Diese Seriennummer ist nicht im Register.');
        },
        'weapons:setStatus': function (serial, status, note) {
            var w = M.weapons[String(serial).toUpperCase()];
            if (!w) return fail('not_found');
            w.status = status; w.statusLabel = statusLabel(status); if (note) w.notes = note;
            return ok(null, 'Status geändert.');
        },
        // Eskorten (Dienstbuch)
        'escort:listOpen': function () { return ok(M.escortsOpen); },
        'escort:listMine': function () { return ok(M.escortsMine); },
        'escort:accept': function (id) {
            var e = find(M.escortsOpen, 'id', id);
            if (!e) return fail('not_found');
            removeFrom(M.escortsOpen, 'id', id);
            e.escorts.push(M.officer.name); e.joined = true; e.status = 'accepted'; e.statusLabel = statusLabel('accepted');
            if (!e.leaderName) e.leaderName = M.officer.name;
            M.escortsMine.unshift(e);
            return ok({ id: id }, 'Auftrag angenommen.');
        },
        'escort:leave': function (id) { removeFrom(M.escortsMine, 'id', id); return ok({ id: id }, 'Auftrag verlassen.'); },
        // Behoerde
        'boss:overview': function () { return ok(M.boss); },
        'boss:hire': function () { return ok(null, 'Person eingestellt.'); },
        'boss:fire': function (charId) { removeFrom(M.boss.members, 'charId', charId); return ok(null, 'Entlassen.'); },
        'boss:setGrade': function (charId, grade) {
            var m = find(M.boss.members, 'charId', charId);
            if (!m) return fail('not_member');
            var g = find(M.boss.grades, 'grade', grade);
            m.grade = grade; m.gradeLabel = g ? g.label : String(grade);
            return ok(null, 'Rang geändert.');
        },
        'boss:deposit': function (amount) {
            M.boss.balance = r2(M.boss.balance + amount);
            M.boss.log.unshift({ id: Date.now(), amount: amount, balanceAfter: M.boss.balance, reason: 'deposit', actorName: M.officer.name, createdAt: nowS() });
            return ok({ balance: M.boss.balance }, '$' + amount.toFixed(2) + ' eingezahlt.');
        },
        'boss:withdraw': function (amount) {
            if (amount > M.boss.balance) return fail('society_empty', 'Die Kasse der Behörde reicht nicht.');
            M.boss.balance = r2(M.boss.balance - amount);
            M.boss.log.unshift({ id: Date.now(), amount: -amount, balanceAfter: M.boss.balance, reason: 'withdraw', actorName: M.officer.name, createdAt: nowS() });
            return ok({ balance: M.boss.balance }, '$' + amount.toFixed(2) + ' ausgezahlt.');
        },
        // Schalter
        'fines:mine': function () { return ok(M.myFines); },
        'fines:pay': function (id) {
            var f = find(M.myFines, 'id', id);
            if (!f || (f.status !== 'open' && f.status !== 'overdue')) return fail('already_done', 'Das wurde bereits erledigt.');
            f.status = 'paid'; f.statusLabel = statusLabel('paid'); f.paidAt = nowS();
            return ok({ id: id, amount: f.amount }, 'Bußgeld bezahlt.');
        },
        'jail:bailList': function () { return ok(M.bailList); },
        'jail:payBail': function (charId) {
            var b = find(M.bailList, 'charId', charId);
            if (!b) return fail('not_found', 'Keine Kaution festgesetzt.');
            removeFrom(M.bailList, 'charId', charId); removeFrom(M.inmates, 'charId', charId);
            return ok({ charId: charId, amount: b.bail }, 'Kaution bezahlt – die Person ist frei.');
        },
        'bounty:licenseStatus': function () { return ok(M.license); },
        'bounty:buyLicense': function () {
            var base = M.license.active && M.license.expiresAt > nowS() ? M.license.expiresAt : nowS();
            M.license.active = true; M.license.expiresAt = base + M.license.days * D;
            return ok(M.license, 'Lizenz gekauft.');
        },
        'bounty:searchTarget': function (name) {
            name = String(name || '').toLowerCase();
            return ok(M.people.filter(function (p) { return p.name.toLowerCase().indexOf(name) >= 0; }).map(function (p) { return { charId: p.charId, name: p.name }; }));
        },
        'bounty:placePrivate': function (o) {
            o = o || {};
            var p = find(M.people, 'charId', o.charId);
            var id = 90 + M.myBounties.length;
            M.myBounties.unshift({ id: id, charId: o.charId, targetName: p ? p.name : '?', kind: 'private', amount: o.amount, reason: o.reason, deadOrAlive: !!o.deadOrAlive, status: 'pending', statusLabel: statusLabel('pending'), createdAt: nowS() });
            return ok({ id: id, status: 'pending', fee: r2(o.amount * 0.1) }, 'Kopfgeld hinterlegt – wartet auf Freigabe.');
        },
        'bounty:minePlaced': function () { return ok(M.myBounties); },
        'bounty:cancelPrivate': function (id) {
            var r = setStatus(M.myBounties, id, 'cancelled', ['pending', 'active'], 'Kopfgeld storniert.');
            if (r.ok) r.data.refund = find(M.myBounties, 'id', id).amount;
            return r;
        },
        'weapons:mine': function () { return ok(M.myWeapons); },
        'weapons:register': function (weaponId) {
            var w = find(M.myWeapons, 'id', weaponId);
            if (!w || w.filed || !w.serial) return fail('invalid', 'Diese Waffe kann nicht registriert werden.');
            w.registered = true; w.status = 'registered'; w.statusLabel = statusLabel('registered');
            return ok(null, 'Waffe registriert – Waffenschein ausgestellt ($10).');
        },
        'weapons:reportStolen': function (serial) {
            var w = find(M.myWeapons, 'serial', serial);
            if (!w || !w.registered) return fail('invalid');
            w.status = 'stolen'; w.statusLabel = statusLabel('stolen'); w.registered = false;
            return ok(null, 'Als gestohlen gemeldet.');
        },
        'escort:options': function () { return ok(M.escortOptions); },
        'escort:quote': function (v) { return quote(v); },
        'escort:book': function (v) {
            var q = quote(v);
            if (!q.ok) return q;
            var t = find(M.escortOptions.types, 'value', v.type);
            var d = v.destination ? find(M.escortOptions.destinations, 'value', v.destination) : null;
            var id = 20 + M.myEscorts.length;
            M.myEscorts.unshift({ id: id, type: v.type, typeLabel: t.label, clientName: M.counter.citizen.name, pickup: 'valentine', pickupLabel: 'Valentine',
                destination: v.destination, destinationLabel: d ? d.label : null, durationMin: v.durationMin, escortsRequired: v.escorts, escorts: [],
                price: q.data.price, insurance: !!v.insurance, status: 'open', statusLabel: statusLabel('open'), createdAt: nowS() });
            return ok({ id: id, total: q.data.total }, 'Auftrag #' + id + ' gebucht.');
        },
        'escort:mine': function () { return ok(M.myEscorts); },
        'escort:insuranceList': function () { return ok(M.insurance); },
        'escort:insuranceDecide': function (id, pay) {
            var c = find(M.insurance, 'id', id);
            if (!c || c.state !== 'pending') return fail('already_done', 'Das wurde bereits erledigt.');
            if (pay && c.amount > M.boss.balance) return fail('society_empty', 'Die Kasse der Behörde reicht nicht.');
            c.state = pay ? 'paid' : 'denied'; c.stateLabel = S['ui_ins_state_' + c.state];
            if (pay) {
                M.boss.balance = r2(M.boss.balance - c.amount);
                M.boss.log.unshift({ id: Date.now(), amount: -c.amount, balanceAfter: M.boss.balance, reason: 'escort_insurance', actorName: M.officer.name, createdAt: nowS() });
            }
            return ok({ id: id, state: c.state }, pay ? 'Versicherung ausgezahlt.' : 'Versicherungsfall abgelehnt.');
        },
        'escort:cancel': function (id) { return setStatus(M.myEscorts, id, 'cancelled', ['open'], 'Auftrag storniert, alles erstattet.'); },
        'escort:claim': function (id) {
            var e = find(M.myEscorts, 'id', id);
            if (!e || !e.canClaim) return fail('invalid');
            e.canClaim = false; e.status = 'claimed'; e.statusLabel = statusLabel('claimed');
            setTimeout(function () { send({ type: 'close' }); }, 60);   // Lua schliesst vor dem vorp-Inventar
            return ok(null, 'Ware abgeholt.');
        },
        'jail:propertyStatus': function () { return ok(M.property); },
        'jail:claimProperty': function () {
            if (!M.property.hasProperty) return fail('not_found', 'Nichts abzuholen.');
            M.property.hasProperty = false;
            send({ type: 'close' });   // wie A: close vor dem vorp-Inventar
            return ok();
        },
        // Brett
        'bounty:board': function () { return ok(M.board); },
        'npc:accept': function (id) {
            var c = find(M.board.contracts, 'id', id);
            if (!c) return fail('not_found', 'Auftrag nicht mehr verfügbar.');
            removeFrom(M.board.contracts, 'id', id);
            return ok({ id: id, expiresAt: nowS() + 45 * 60 }, 'Auftrag angenommen – Zielgebiet ist markiert.');
        },
    };

    // ------------------------------------------------------------------
    // Formulare, die das Dienstbuch per action ledger:openForm anfordert
    // ------------------------------------------------------------------
    function personName(charId) { var p = find(M.people, 'charId', charId); return p ? p.name : '#' + charId; }
    var FORMS = {
        fine: function (p) {
            return { id: 'fine', title: 'Bußgeld ausstellen', subtitle: personName(p.charId), submitLabel: 'Ausstellen', summary: 'penalcode', fields: [
                { name: 'target', type: 'readonly', label: 'Person', default: p.charId, display: personName(p.charId) },
                { name: 'codes', type: 'penalcode', label: 'Delikte', required: true, options: M.penal },
                { name: 'note', type: 'text', label: 'Bemerkung', maxLength: 120, placeholder: 'optional' },
            ] };
        },
        warrant: function (p) {
            var fields = [];
            if (p.charId !== undefined) fields.push({ name: 'charId', type: 'readonly', label: 'Person', default: p.charId, display: personName(p.charId) });
            else fields.push({ name: 'charId', type: 'select', label: 'Person', required: true, options: M.people.map(function (x) { return { value: x.charId, label: x.name }; }) });
            return { id: 'warrant', title: 'Haftbefehl beantragen', submitLabel: 'Beantragen', summary: 'penalcode', fields: fields.concat([
                { name: 'codes', type: 'penalcode', label: 'Delikte', required: true, options: M.penal },
                { name: 'reason', type: 'text', label: 'Begründung', required: true, maxLength: 200 },
                { name: 'jailMinutes', type: 'number', label: 'Zusätzliche Haftminuten', min: 0, max: 60, default: 0 },
                { name: 'deadOrAlive', type: 'checkbox', label: 'Tot oder lebendig', placeholder: 'Ja, auch tot' },
                { name: 'bounty', type: 'money', label: 'Kopfgeld (optional)', min: 0, max: 2000 },
            ]) };
        },
        bounty_official: function (p) {
            var fields = [];
            if (p.charId !== undefined) fields.push({ name: 'charId', type: 'readonly', label: 'Person', default: p.charId, display: personName(p.charId) });
            else fields.push({ name: 'charId', type: 'select', label: 'Person', required: true, options: M.people.map(function (x) { return { value: x.charId, label: x.name }; }) });
            return { id: 'bounty_official', title: 'Offizielles Kopfgeld', submitLabel: 'Ausschreiben', fields: fields.concat([
                { name: 'amount', type: 'money', label: 'Betrag', required: true, min: 10, max: 2000, help: 'Wird aus der Kasse der Behörde bezahlt.' },
                { name: 'reason', type: 'text', label: 'Grund', required: true, maxLength: 120 },
                { name: 'deadOrAlive', type: 'checkbox', label: 'Tot oder lebendig', placeholder: 'Ja, auch tot' },
            ]) };
        },
        note: function (p) {
            return { id: 'note', title: 'Notiz zur Akte', subtitle: personName(p.charId), submitLabel: 'Speichern', fields: [
                { name: 'title', type: 'text', label: 'Titel', required: true, maxLength: 60 },
                { name: 'text', type: 'textarea', label: 'Text', required: true, maxLength: 500 },
            ] };
        },
        hire: function () {
            return { id: 'hire', title: 'Person einstellen', submitLabel: 'Einstellen', fields: [
                { name: 'player', type: 'select', label: 'Person in der Nähe', required: true, options: [{ value: 7, label: 'John Marston' }, { value: 9, label: 'Sean MacGuire' }], default: 7 },
                { name: 'grade', type: 'select', label: 'Rang', required: true, options: M.boss.grades.slice(0, 4).map(function (g) { return { value: g.grade, label: g.label }; }), default: 0 },
            ] };
        },
    };

    function actionHandler(app, name, payload) {
        payload = payload || {};
        if (app === 'ledger' && name === 'setWaypoint') {
            console.log('[Mock] Wegpunkt', payload);
            return ok();
        }
        if (app === 'ledger' && name === 'openForm') {
            var mk = FORMS[payload.form];
            if (!mk) return fail('no_form', S.ui_err_no_form);
            return uiForm(mk(payload)).then(function (values) {
                if (!values) return fail('cancelled');
                console.log('[Mock] Formular ' + payload.form, values);
                if (payload.form === 'note' && payload.charId !== undefined) CB['records:addNote'](payload.charId, values.title, values.text);
                return ok(null, 'Formular „' + payload.form + '“ verarbeitet (Test).');
            });
        }
        return fail('no_handler');
    }

    // ------------------------------------------------------------------
    // Endpoints
    // ------------------------------------------------------------------
    LAW.mockPost = function (endpoint, body) {
        body = body || {};
        console.log('[NUI → Lua]', endpoint, body);
        switch (endpoint) {
            case 'ready':
                setTimeout(function () {
                    send({ type: 'init', data: { locale: 'de', strings: S, currency: '$', resource: 'ArA-LawSystem' } });
                }, 20);
                return { ok: true };
            case 'close':
                resolvePending('menu', null); resolvePending('form', null);
                console.log('[Mock] close (seq ' + body.seq + ', zuletzt gesendet ' + seq + ')');
                return { ok: true };
            case 'menuSelect': resolvePending('menu', body.id); return { ok: true };
            case 'menuCancel': resolvePending('menu', null); return { ok: true };
            case 'formSubmit': resolvePending('form', body.values || {}); return { ok: true };
            case 'formCancel': resolvePending('form', null); return { ok: true };
            case 'cb': {
                var fn = CB[body.name];
                if (!fn) { console.warn('[Mock] Kein Test-Callback fuer', body.name); return delay(fail('no_handler', 'Kein Test-Callback: ' + body.name)); }
                var res;
                try { res = fn.apply(null, Array.isArray(body.args) ? body.args : []); } catch (e) { console.warn(e); res = fail('internal'); }
                return delay(res);
            }
            case 'action':
                return delay(actionHandler(body.app, body.name, body.payload), 60);
        }
        return { ok: false, err: 'no_handler' };
    };

    // ------------------------------------------------------------------
    // Testleiste
    // ------------------------------------------------------------------
    var k9States = ['idle', 'following', 'sniffing', 'tracking', 'waiting', 'searching', 'found', 'lost', 'staying'];
    var k9i = 0, robbery = 0, alertId = 20;
    var hudOn = {};

    function toggleHud(name, data) {
        hudOn[name] = !hudOn[name];
        send({ type: 'hud', hud: name, data: hudOn[name] ? data : null });
    }

    function openLedger(officer, tab, focusCharId) {
        send({ type: 'open', app: 'ledger', data: { officer: officer, tab: tab || 'overview', focusCharId: focusCharId } });
    }

    var DOCS = {
        ticket: function () { var d = LAW.Ledger.fineDocument(M.fines[0]); d.seal = 'sheriff'; return d; },
        warrant: function () {
            var w = M.warrants[0];
            return { kind: 'warrant', title: 'Haftbefehl', subtitle: w.targetName, seal: 'court', sealLabel: 'Gericht New Hanover', signature: 'Richter T. Hale', footer: 'County Sheriff · Valentine',
                fields: [{ label: 'Delikte', value: 'Bankraub, Mord' }, { label: 'Haftzeit', value: '3h 0m' }, { label: 'Kopfgeld', value: '$500.00' }, { label: 'Gültig bis', value: LAW.fmt.date(w.expiresAt) }],
                body: 'Alle Gesetzeshüter werden angewiesen, Micah Bell festzunehmen und der nächsten Dienststelle zu überstellen. Die Person gilt als bewaffnet und gefährlich.' };
        },
        poster: function () { return { kind: 'poster', title: 'Micah Bell', subtitle: 'Bankraub in Valentine', reward: 500, deadOrAlive: true, seal: 'sheriff', footer: 'County Sheriff · ' + LAW.fmt.day(M.now),
            fields: [{ label: 'Gesucht wegen', value: 'Bankraub, Mord, Pferdediebstahl' }] }; },
        license: function () { return { kind: 'license', title: 'Kopfgeldjäger-Lizenz', subtitle: 'Sadie Adler', seal: 'sheriff', sealLabel: 'County Sheriff', signature: 'A. Callahan',
            fields: [{ label: 'Inhaber', value: 'Sadie Adler' }, { label: 'Ausgestellt', value: LAW.fmt.day(M.now) }, { label: 'Gültig bis', value: LAW.fmt.day(M.now + 14 * D) }, { label: 'Nr.', value: 'KJ-0300' }],
            footer: 'Gilt in allen Bezirken. Nicht übertragbar.' }; },
        permit: function () { return { kind: 'permit', title: 'Waffenschein', subtitle: 'Varmint-Gewehr', seal: 'marshal', sealLabel: 'US Marshals', signature: 'J. Hawkins',
            fields: [{ label: 'Inhaber', value: 'Sadie Adler' }, { label: 'Waffe', value: 'Varmint-Gewehr' }, { label: 'Seriennr.', value: 'SN-77B312' }, { label: 'Registriert', value: LAW.fmt.date(M.now) }] }; },
        report: function () { return { kind: 'report', title: 'Einsatzbericht', subtitle: 'Überfall auf die Bank von Valentine', seal: 'police', sealLabel: 'Saint Denis Police', signature: 'Leigh Gray',
            fields: [{ label: 'Datum', value: LAW.fmt.date(M.now - D) }, { label: 'Ort', value: 'Valentine, Hauptstraße' }, { label: 'Beamte', value: 'L. Gray, A. Callahan' }],
            body: 'Gegen 14:10 Uhr betraten drei bewaffnete Männer die Bank.\nEin Kassierer wurde tödlich verletzt. Die Täter flohen Richtung Norden.\n\n<script>alert(1)</script> (muss als Text erscheinen)', footer: 'Akte 101 · Kopie an das Gericht' }; },
        evidence: function () { return { kind: 'evidence', title: 'Laborbericht', subtitle: 'Beweis Nr. 201', seal: 'pinkerton', sealLabel: 'Pinkerton-Detektei', signature: 'A. Milton',
            fields: [{ label: 'Art', value: 'Patronenhülse' }, { label: 'Fundort', value: 'Valentine' }, { label: 'Waffe', value: 'Cattleman-Revolver' }, { label: 'Seriennr.', value: 'SN-4F2A91' }],
            body: 'Hülse Kaliber .45.\n– Seriennummer lesbar\n– Registriert auf: Micah Bell', footer: 'Ausgewertet' }; },
    };

    var SEAL_DEMO = {
        sheriff: ['Arthur Callahan', 'County Sheriff', 'Sheriff', 'SO-0042'],
        marshal: ['Charles Smith', 'US Marshals', 'Deputy Marshal', 'USM-0003'],
        police: ['Leigh Gray', 'Saint Denis Police', 'Sergeant', 'SDPD-0017'],
        pinkerton: ['Andrew Milton', 'Pinkerton-Detektei', 'Direktor', 'PNK-0001'],
        prison: ['Walter Crane', 'Sisika-Gefängnis', 'Oberwärter', 'SIS-0021'],
        court: ['Theodore Hale', 'Gericht', 'Oberrichter', 'CRT-0002'],
    };

    var GROUPS = [
        ['Apps', [
            ['Dienstbuch (alle Rechte)', function () { openLedger(M.officer, 'overview'); }],
            ['Dienstbuch (Deputy)', function () { openLedger(M.officerLimited, 'overview'); }],
            ['Dienstbuch → Akte 101', function () { openLedger(M.officer, 'people', 101); }],
            ['Dienstbuch → Behörde', function () { openLedger(M.officer, 'department'); }],
            ['Schalter', function () { send({ type: 'open', app: 'counter', data: M.counter }); }],
            ['Steckbriefbrett', function () { send({ type: 'open', app: 'board', data: { station: 'valentine', stationLabel: 'Valentine', canHunt: true, seal: 'sheriff' } }); }],
            ['Brett (ohne Lizenz)', function () { send({ type: 'open', app: 'board', data: { station: 'rhodes', stationLabel: 'Rhodes', canHunt: false } }); }],
            ['Menü', function () {
                uiMenu({ title: 'Aktionen', subtitle: 'Person: Micah Bell', items: [
                    { id: 'arrest_cuff', label: 'Fesseln', icon: 'cuffs', badge: 'Person', desc: 'Legt der Person Handschellen an.' },
                    { id: 'arrest_search', label: 'Durchsuchen', icon: 'search', badge: 'Person' },
                    { id: 'arrest_idcheck', label: 'Akte prüfen', icon: 'doc', desc: 'Öffnet die Akte im Dienstbuch.' },
                    { id: 'fines_issue', label: 'Bußgeld ausstellen', icon: 'money' },
                    { id: 'k9', label: 'Bluthund rufen', icon: 'dog', disabled: true, desc: 'Kein Hund in der Nähe.' },
                    { id: 'evidence', label: 'Spurensuche an/aus', icon: 'evidence' },
                    { id: 'xss', label: '<b>Kein HTML</b> & "Anführungszeichen"', desc: '<img src=x onerror=alert(1)>' },
                    { id: 'noicon', label: 'Eintrag ohne Icon' },
                ] }).then(function (id) { if (id) LAW.toast({ title: 'menuSelect', text: String(id), kind: 'success', ms: 3000 }); });
            }],
            ['Formular (Bußgeld)', function () {
                uiForm(FORMS.fine({ charId: 101 })).then(function (v) { if (v) LAW.toast({ title: 'formSubmit', text: JSON.stringify(v), kind: 'success', ms: 7000 }); });
            }],
            ['Formular (alle Typen)', function () {
                uiForm({ id: 'demo', title: 'Alle Feldtypen', subtitle: 'Vertrag 10.3', submitLabel: 'Prüfen & senden', fields: [
                    { name: 'text', type: 'text', label: 'Text', required: true, maxLength: 30, placeholder: 'max. 30 Zeichen' },
                    { name: 'number', type: 'number', label: 'Zahl (1–10)', min: 1, max: 10, default: 3 },
                    { name: 'money', type: 'money', label: 'Betrag', min: 0.5, max: 500, help: 'zwei Nachkommastellen' },
                    { name: 'select', type: 'select', label: 'Auswahl', required: true, options: [{ value: 1, label: 'Valentine', desc: 'New Hanover' }, { value: 2, label: 'Rhodes', desc: 'Lemoyne' }] },
                    { name: 'multi', type: 'multiselect', label: 'Mehrfachauswahl', min: 1, options: [{ value: 'a', label: 'Pferd' }, { value: 'b', label: 'Wagen' }, { value: 'c', label: 'Zug', desc: 'teuer' }] },
                    { name: 'check', type: 'checkbox', label: 'Häkchen', placeholder: 'Ich bestätige' },
                    { name: 'ro', type: 'readonly', label: 'Nur lesen', default: 'SO-0042' },
                    { name: 'area', type: 'textarea', label: 'Langer Text', maxLength: 300 },
                    { name: 'codes', type: 'penalcode', label: 'Strafkatalog', options: M.penal, default: [{ id: 'theft', count: 2 }] },
                ] }).then(function (v) { if (v) LAW.toast({ title: 'formSubmit', text: JSON.stringify(v), kind: 'success', ms: 8000 }); });
            }],
        ]],
        ['Dokumente', Object.keys(DOCS).map(function (k) { return [k, function () { send({ type: 'open', app: 'document', data: DOCS[k]() }); }]; })],
        ['Marke', Object.keys(SEAL_DEMO).map(function (k) {
            return [k, function () { var s = SEAL_DEMO[k]; send({ type: 'open', app: 'badge', nofocus: true, data: { name: s[0], deptLabel: s[1], gradeLabel: s[2], badgeNumber: s[3], seal: k, ms: 6000 } }); }];
        })],
        ['HUD', [
            ['jail', function () { toggleHud('jail', { remaining: 1250, total: 2400, reduced: 300, work: { done: 3, max: 10 } }); }],
            ['cuffed', function () { toggleHud('cuffed', { by: 'Arthur Callahan' }); }],
            ['k9 (weiter)', function () {
                var st = k9States[k9i++ % k9States.length];
                hudOn.k9 = true;
                send({ type: 'hud', hud: 'k9', data: { state: st, strength: st === 'tracking' || st === 'sniffing' ? ['fresh', 'medium', 'weak'][k9i % 3] : null, text: st === 'tracking' ? 'Spur ist 12 Minuten alt.' : '' } });
            }],
            ['k9 aus', function () { hudOn.k9 = false; send({ type: 'hud', hud: 'k9', data: null }); }],
            ['escort', function () { toggleHud('escort', { id: 9, typeLabel: 'Werttransport', statusLabel: 'Unterwegs', destinationLabel: 'Saint Denis', timeLeft: 1450, escortsNear: 2, escortsTotal: 3 }); }],
            ['evidence', function () { toggleHud('evidence', { active: true, count: 3 }); }],
            ['duty', function () { toggleHud('duty', { deptLabel: 'County Sheriff', gradeLabel: 'Sheriff', badgeNumber: 'SO-0042' }); }],
            ['robbery (+20 %)', function () {
                robbery = robbery >= 1 ? 0 : r2(robbery + 0.2);
                send({ type: 'hud', hud: 'robbery', data: robbery > 0 ? { progress: robbery, text: 'Kiste wird aufgebrochen …' } : null });
            }],
        ]],
        ['Nachrichten', [
            ['toast info', function () { send({ type: 'toast', data: { title: 'Hinweis', text: 'Dienst begonnen: County Sheriff', kind: 'info', ms: 5000 } }); }],
            ['toast success', function () { send({ type: 'toast', data: { title: 'Erledigt', text: 'Bußgeld bezahlt.', kind: 'success', ms: 5000 } }); }],
            ['toast error', function () { send({ type: 'toast', data: { title: 'Fehler', text: 'Du hast nicht genug Geld dabei.', kind: 'error', ms: 5000 } }); }],
            ['toast alert', function () { send({ type: 'toast', data: { title: '#14 PANIK - Kollege in Not', text: 'Deputy Hawkins braucht sofort Hilfe! (Valentine)\nAnnehmen: /einsatz 14', kind: 'alert', ms: 12000 } }); }],
            ['neuer Einsatz (update)', function () {
                var id = ++alertId;
                var a = { id: id, kind: 'robbery', title: 'Überfall', text: 'Werttransport #9 wird überfallen!', coords: { x: 2632, y: -1312, z: 52 }, zone: 'Saint Denis', priority: 3, createdAt: nowS(), expiresAt: nowS() + 900, responders: [], mine: false };
                M.overview.alerts.unshift(a);
                send({ type: 'toast', data: { title: '#' + id + ' ' + a.title, text: a.text + '\nAnnehmen: /einsatz ' + id, kind: 'alert', ms: 12000 } });
                send({ type: 'update', app: 'ledger', data: { alertsChanged: true } });
            }],
            ['close (Lua)', function () { send({ type: 'close' }); }],
        ]],
    ];

    function buildBar() {
        var bar = LAW.el('div', { cls: 'devbar', attrs: { id: 'devbar' } });
        var head = LAW.el('button', { cls: 'devbar__head', type: 'button', text: 'ArA-Law · Testmodus' });
        head.addEventListener('click', function () { bar.classList.toggle('is-min'); });
        bar.appendChild(head);
        GROUPS.forEach(function (g) {
            var box = LAW.el('div', 'devbar__group', [LAW.el('div', { cls: 'devbar__title', text: g[0] })]);
            g[1].forEach(function (b) {
                var btn = LAW.el('button', { cls: 'devbar__btn', type: 'button', text: b[0] });
                btn.addEventListener('click', function (e) { e.stopPropagation(); b[1](); });
                box.appendChild(btn);
            });
            bar.appendChild(box);
        });
        bar.appendChild(LAW.el('div', { cls: 'devbar__hint', text: '?debug = Raster · Konsole zeigt alle Posts' }));
        document.body.appendChild(bar);
    }

    LAW.devStart = function () {
        buildBar();
        console.log('[ArA-Law] Browser-Testmodus aktiv. Testleiste oben links.');
    };
})();
