// ==UserScript==
// @name         YouTube WASD → Arrows
// @namespace    http://tampermonkey.net/
// @version      260429
// @description  On YouTube, make WASD behave like arrow keys: A/D = seek back/forward, W/S = volume up/down. Layout-agnostic via event.code (works in EN and RU). Disabled while typing in inputs / textareas / contenteditable so comments still work.
// @match        *://*.youtube.com/*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=youtube.com
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    const DEBUG = false;

    // Physical-key code (layout independent) → arrow descriptor.
    const MAP = {
        KeyA: { key: 'ArrowLeft',  code: 'ArrowLeft',  keyCode: 37 },
        KeyD: { key: 'ArrowRight', code: 'ArrowRight', keyCode: 39 },
        KeyW: { key: 'ArrowUp',    code: 'ArrowUp',    keyCode: 38 },
        KeyS: { key: 'ArrowDown',  code: 'ArrowDown',  keyCode: 40 },
    };

    function isTypingTarget(el) {
        if (!el) return false;
        if (el.isContentEditable) return true;
        const tag = el.tagName;
        return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
    }

    function makeSynthetic(type, src, target) {
        return new KeyboardEvent(type, {
            key: target.key,
            code: target.code,
            keyCode: target.keyCode,
            which: target.keyCode,
            bubbles: true,
            cancelable: true,
            composed: true,
            ctrlKey:  src.ctrlKey,
            shiftKey: src.shiftKey,
            altKey:   src.altKey,
            metaKey:  src.metaKey,
            repeat:   src.repeat,
        });
    }

    function handler(e) {
        if (!e.isTrusted) return; // ignore our own synthesized events
        if (e.ctrlKey || e.altKey || e.metaKey) return; // don't break Ctrl+A etc.

        const target = MAP[e.code];
        if (!target) return;

        if (isTypingTarget(e.target) || isTypingTarget(document.activeElement)) {
            if (DEBUG) console.log('[wasd→arrows] skip (typing)', e.code);
            return;
        }

        if (DEBUG) console.log('[wasd→arrows]', e.type, e.code, '→', target.code);

        e.preventDefault();
        e.stopImmediatePropagation();
        e.stopPropagation();

        // Dispatch on the player element so volume (Up/Down) handlers fire — they
        // appear to be gated on the event landing inside the player container, while
        // seek (Left/Right) fires from anywhere. Fallback to document.
        const player = document.querySelector('.html5-video-player') || document;
        const ev = makeSynthetic(e.type, e, target);
        player.dispatchEvent(ev);
    }

    window.addEventListener('keydown', handler, true);
    window.addEventListener('keyup',   handler, true);
    window.addEventListener('keypress', handler, true);

    if (DEBUG) console.log('[wasd→arrows] loaded on', location.href);
})();
