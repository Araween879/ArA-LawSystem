/*
    ArA-LawSystem - Steckbriefbrett `board` (Vertrag 10.5)
    bounty:board() -> { posters, bounties, contracts }  ·  npc:accept(id)
*/
(function () {
    'use strict';
    var LAW = window.LAW;
    var el = LAW.el, t = LAW.t, $ = LAW.$, ui = LAW.ui;

    var BD = LAW.Board = { data: {}, seq: 0, side: 'bounties', board: null };

    function alive(k) { return k === BD.seq && LAW.isOpen('board'); }

    function posterDoc(p) {
        p = LAW.obj(p);
        var crimes = LAW.arr(p.crimes);
        return {
            kind: 'poster',
            title: LAW.str(p.name, p.targetName),
            subtitle: LAW.str(p.reason),
            fields: crimes.length ? [{ label: t('ui_poster_crimes'), value: crimes.join(', ') }] : [],
            reward: LAW.num(p.amount),
            deadOrAlive: !!p.deadOrAlive,
            footer: [LAW.str(p.deptLabel), p.createdAt ? LAW.fmt.day(p.createdAt) : ''].filter(Boolean).join(' · '),
            seal: BD.data.seal || 'sheriff',
        };
    }

    // deterministische "zufaellige" Schraeglage je Plakat
    function tilt(i) { var r = [-2.6, 1.8, -1.1, 2.4, -0.6, 1.2, -2.0, 0.8]; return r[i % r.length]; }

    function posterCard(p, i) {
        p = LAW.obj(p);
        var card = el('button', { cls: 'wposter', type: 'button', attrs: { style: '--tilt:' + tilt(i) + 'deg' } }, [
            el('span', 'wposter__pin'),
            el('span', { cls: 'wposter__wanted', text: t('ui_poster_wanted') }),
            el('span', { cls: 'wposter__doa', text: p.deadOrAlive ? t('ui_poster_dead_or_alive') : t('ui_poster_alive') }),
            el('span', 'wposter__face', [el('img', { attrs: { src: 'img/silhouette.svg', alt: '', draggable: 'false' } })]),
            el('span', { cls: 'wposter__name', text: LAW.str(p.name) }),
            el('span', { cls: 'wposter__reason', text: LAW.str(p.reason) }),
            el('span', { cls: 'wposter__rewardl', text: t('ui_poster_reward') }),
            el('span', { cls: 'wposter__reward', text: LAW.fmt.money(p.amount) }),
        ]);
        card.addEventListener('click', function () { LAW.open('document', posterDoc(p)); });
        return card;
    }

    function difficulty(d) {
        if (typeof d === 'number') {
            var n = Math.max(1, Math.min(5, Math.round(d)));
            var s = '';
            for (var i = 0; i < n; i++) s += '★';
            return s;
        }
        var key = 'ui_npc_diff_' + String(d || '');
        return LAW.has(key) ? t(key) : LAW.str(d, '–');
    }

    function contractCard(c, k) {
        c = LAW.obj(c);
        var now = Date.now() / 1000;
        var btns = [];
        if (BD.data.canHunt) {
            btns.push(LAW.btn(t('ui_npc_accept'), function () {
                return LAW.confirm(t('ui_confirm_npc_accept', LAW.str(c.name)), { danger: false, okLabel: t('ui_npc_accept') }).then(function (ok) {
                    if (!ok) return;
                    return LAW.cb('npc:accept', [c.id]).then(function (res) { if (res.ok) load(); });
                });
            }, 'primary tiny'));
        }
        return el('div', 'contract', [
            el('div', 'contract__head', [
                el('span', { cls: 'contract__name', text: LAW.str(c.name) }),
                el('span', { cls: 'contract__reward', text: LAW.fmt.money(c.reward) }),
            ]),
            c.description ? el('div', { cls: 'contract__desc', text: String(c.description) }) : null,
            el('div', 'contract__meta', [
                el('span', { text: t('ui_npc_area', LAW.str(c.areaLabel, '–')) }),
                c.gangSize ? el('span', { text: t('ui_npc_gang', c.gangSize) }) : null,
                el('span', { text: t('ui_npc_difficulty', difficulty(c.difficulty)) }),
                c.aliveBonus ? el('span', { text: t('ui_npc_alive_bonus', LAW.fmt.money(c.aliveBonus)) }) : null,
                c.expiresAt ? el('span', { text: t('ui_npc_expires', LAW.fmt.duration(LAW.num(c.expiresAt) - now)) }) : null,
            ]),
            btns.length ? ui.actions(btns) : null,
        ]);
    }

    function renderSide(k) {
        var box = $('bd-side-list');
        var d = LAW.obj(BD.board);
        if (!box) return;
        if (BD.side === 'contracts') {
            var list = LAW.arr(d.contracts);
            ui.fill(box, [
                !BD.data.canHunt ? el('div', { cls: 'hint hint--bad', text: t('ui_board_need_license') }) : null,
                list.length ? list.map(function (c) { return contractCard(c, k); }) : ui.empty('ui_board_no_contracts'),
            ]);
        } else {
            ui.fill(box, [ui.list(d.bounties, function (b) {
                b = LAW.obj(b);
                return ui.row({
                    icon: 'skull',
                    title: LAW.str(b.targetName),
                    sub: LAW.fmt.money(b.amount) + ' · ' + ui.deadOrAlive(b.deadOrAlive),
                    meta: LAW.str(b.reason),
                    right: [ui.chip(t('ui_bounty_kind_' + LAW.str(b.kind, 'official')), b.kind === 'private' ? 'warn' : 'info')],
                    onClick: function () {
                        LAW.open('document', posterDoc({ name: b.targetName, reason: b.reason, amount: b.amount, deadOrAlive: b.deadOrAlive, createdAt: b.createdAt }));
                    },
                });
            }, 'ui_board_no_bounties')]);
        }
    }

    function load() {
        var k = ++BD.seq;
        ui.fill($('bd-posters'), [ui.loading()]);
        ui.fill($('bd-side-list'), [ui.loading()]);
        LAW.cb('bounty:board', [], { quiet: true }).then(function (res) {
            if (!alive(k)) return;
            if (!res.ok) { ui.fill($('bd-posters'), [ui.empty('ui_load_failed')]); LAW.clear($('bd-side-list')); return; }
            BD.board = LAW.obj(res.data);
            var posters = LAW.arr(BD.board.posters);
            ui.fill($('bd-posters'), posters.length ? posters.map(posterCard) : [el('div', { cls: 'board-empty', text: t('ui_board_no_posters') })]);
            renderSide(k);
        });
    }
    BD.reload = load;

    LAW.register('board', {
        root: null,
        setup: function () {
            this.root = $('app-board');
            $('bd-close').addEventListener('click', function () { LAW.closeLayer('board', 'cancel'); });
        },
        open: function (d) {
            BD.data = d;
            $('bd-station').textContent = LAW.str(d.stationLabel, LAW.str(d.station));
            BD.side = 'bounties';
            ui.fill($('bd-side-tabs'), [ui.segmented([
                { id: 'bounties', label: t('ui_board_bounties') },
                { id: 'contracts', label: t('ui_board_contracts') },
            ], BD.side, function (id) { BD.side = id; renderSide(BD.seq); })]);
            load();
        },
        update: function (d) { Object.assign(BD.data, d); load(); },
        onHide: function () { BD.seq++; },
    });
})();
