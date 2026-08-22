// ==UserScript==
// @name         Gandalf the Focus Keeper
// @namespace    http://tampermonkey.net/
// @version      260822
// @description  Gandalf blocks mindless visits to distracting sites (socials, news, forums)—unless you really insist and jump through his hoops.
// @author       👾 claude opus 5 [high] for kycok_ov4arku
// @run-at       document-start
// @match        *://dtf.ru/*
// @match        *://meduza.io/*
// @match        *://*.youtube.com/*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_deleteValue
// ==/UserScript==

(function() {
'use strict';

// Trusted Types: YouTube enforces a CSP that blocks raw string -> innerHTML.
let ttPolicy = null;
if (window.trustedTypes && window.trustedTypes.createPolicy) {
    try {
        ttPolicy = window.trustedTypes.createPolicy('gandalf-focus-keeper', {
            createHTML: (s) => s
        });
    } catch (e) {
        ttPolicy = null;
    }
}
function setInnerHTML(el, html) {
    el.innerHTML = ttPolicy ? ttPolicy.createHTML(html) : html;
}

// ----- CONFIGURABLE VARS AT TOP -----
const MEME1 = 'https://i125.fastpic.org/big/2025/0515/73/d074c6e3395810d4c9c2a22873010e73.jpeg'; // YOU SHALL NOT PASS
const MEME2 = 'https://i125.fastpic.org/big/2025/0515/0c/f2a693003f6f74497144d5d5c8f9850c.jpeg'; // Balrog: "I want to pass, please"
const MEME3 = 'https://i125.fastpic.org/big/2025/0515/fe/f9c4e239f1d07217375bf1d7237184fe.jpeg'; // Gandalf: "Ok, but give me a password"
const MEME4 = 'https://i128.fastpic.org/big/2026/0803/89/f5fc509525dbb859795573fc54c44489.jpeg'; // Falling Gandalf: "Fly, you fools!"

// Grace is picked from a small menu, not a continuous dial — a fine-grained
// slider just invites haggling with yourself, which is the habit being blocked.
const GRACE_MIN = 5;
const GRACE_MAX = 30;
const GRACE_STEP = 5;

// Cooldown scales with the grace taken. A flat penalty punishes honesty: if a
// 5-minute peek costs the same as 30, you learn to always request the maximum.
// Ratio 4 fixes the duty cycle at 20% wherever you land on the slider.
const COOLDOWN_RATIO = 4;
const COOLDOWN_FLOOR_MINUTES = 15; // stops 5-minute drive-bys from being ~free

// Grace only burns while you're actually looking. A wall-clock grace creates a
// pull back to the tab ("my time is running out"), which is backwards. But an
// indefinitely parked balance lets you dip in 30s at a time forever, so the
// token also dies this many times its length after issue, cooldown included.
const GRACE_SHELF_RATIO = 2;

const NUM_WORDS = [
    "zero","one","two","three","four","five","six","seven","eight","nine","ten",
    "eleven","twelve","thirteen","fourteen","fifteen","sixteen","seventeen","eighteen","nineteen","twenty",
    "twenty-one","twenty-two","twenty-three","twenty-four","twenty-five","twenty-six","twenty-seven","twenty-eight","twenty-nine","thirty"
];

// No content word is reused between these, so each one reads as new ground
// rather than a variation you can half-type from muscle memory. Only function
// words (the, of, and) repeat — unavoidable, and they aren't what you notice.
const LOTR_SENTENCES = [
    "A road lies ahead of you, long unwalked, while the pale glow of some flickering window holds your feet rooted to this very spot.",
    "Shadow gathers not in one great darkness but in small minutes, pilfered quietly, each too slight to mourn until they are all gone.",
    "Even the least of deeds may turn a whole age, if only a hand will rise from its idle rest and begin in earnest the work that waits.",
    "Despair suits none who yet draw breath; a mind can be armed against the creeping haze which dims every fire it once carried.",
    "Stand firm, wanderer of western lands, and take back what little remains of daylight before dusk lays cold claim upon it forever.",
    "A soul must choose how to spend such time as fate allots, for the hours slip grain by grain through fingers loosened without notice."
];
// ------------------------------------

const REMAIN_KEY = 'graceRemaining';   // ms of grace still unspent
const RESUMED_KEY = 'graceResumedAt';  // when the clock last started; 0 while held
const SHELF_KEY = 'graceExpiresAt';    // wall-clock forfeit deadline for the balance
const COOLDOWN_KEY = 'cooldownUntil';
const GRACE_TAKEN_KEY = 'graceTaken';  // so the cooldown screen can show the trade
const LEGACY_KEY = 'blockUntil';       // pre-260822 absolute deadline
const now = Date.now();

// Cross-site retrieval using GM storage APIs
const cooldown = Number(GM_getValue(COOLDOWN_KEY)) || 0;
const graceTaken = Number(GM_getValue(GRACE_TAKEN_KEY)) || 0;

if (GM_getValue(LEGACY_KEY)) GM_deleteValue(LEGACY_KEY);

// Expose reset handler to the console (debug only)
function resetGandalf() {
    [REMAIN_KEY, RESUMED_KEY, SHELF_KEY, COOLDOWN_KEY, GRACE_TAKEN_KEY, LEGACY_KEY].forEach(k => GM_deleteValue(k));
    console.log("Gandalf's blocks and cooldowns have been cleared.");
    location.reload();
}

/** Unspent grace in ms, accounting for a clock that may be running right now. */
function graceRemainingMs() {
    const stored = Number(GM_getValue(REMAIN_KEY)) || 0;
    const resumedAt = Number(GM_getValue(RESUMED_KEY)) || 0;
    return resumedAt ? stored - (Date.now() - resumedAt) : stored;
}

function mediaIsPlaying() {
    return Array.from(document.querySelectorAll('video, audio')).some(m => !m.paused && !m.ended);
}

// Audio in a background tab is still consumption, so hidden alone isn't enough.
function graceShouldRun() {
    return !document.hidden || mediaIsPlaying();
}

function setGraceRunning(run) {
    const resumedAt = Number(GM_getValue(RESUMED_KEY)) || 0;
    if (run && !resumedAt) {
        GM_setValue(RESUMED_KEY, String(Date.now()));
    } else if (!run && resumedAt) {
        GM_setValue(REMAIN_KEY, String(graceRemainingMs()));
        GM_setValue(RESUMED_KEY, '0');
    }
}

/** Grace is over. The cooldown clock starts *now* — never at unlock time, or a
 *  parked tab would let the penalty elapse against grace that was never spent. */
function spendGrace() {
    const taken = Number(GM_getValue(GRACE_TAKEN_KEY)) || GRACE_MIN;
    GM_deleteValue(REMAIN_KEY);
    GM_deleteValue(RESUMED_KEY);
    GM_deleteValue(SHELF_KEY);
    GM_setValue(COOLDOWN_KEY, String(Date.now() + cooldownFor(taken) * 60 * 1000));
    location.reload();
}

function graceIsStale() {
    const shelfAt = Number(GM_getValue(SHELF_KEY)) || 0;
    return shelfAt > 0 && Date.now() >= shelfAt;
}

if (typeof unsafeWindow !== 'undefined') {
    unsafeWindow.resetGandalf = resetGandalf;
} else {
    window.resetGandalf = resetGandalf;
}

// URL query parameter fallback reset
if (location.search.includes('reset')) {
    resetGandalf();
    return;
}

// --- FLOATING UNBLOCK TIMER WIDGET (TRUSTED-TYPES SAFE) ---
function injectFloatingWidget() {
    if (!document.documentElement) return;
    if (document.getElementById('gandalf-timer-widget')) return;

    const widget = document.createElement('div');
    widget.id = 'gandalf-timer-widget';

    const style = document.createElement('style');
    style.textContent = `
      #gandalf-timer-widget {
        position: fixed !important;
        top: 0 !important;
        left: 0 !important;
        z-index: 2147483647 !important;
        background: transparent !important;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
        font-size: 13px !important;
        color: #111111 !important;
        cursor: default !important;
        user-select: none !important;
        padding: 0 !important;
        margin: 0 !important;
        display: flex !important;
        align-items: center !important;
        line-height: 1.5 !important;
        transition: background 0.15s, box-shadow 0.15s, padding 0.15s !important;
        border-bottom-right-radius: 4px !important;
        overflow: hidden !important;
      }
      #gandalf-timer-widget:hover {
        background: #ffffff !important;
        box-shadow: 0 2px 8px rgba(0,0,0,0.15) !important;
        border: 1px solid #e2e8f0 !important;
        border-top: none !important;
        border-left: none !important;
        padding: 8px 12px 8px 8px !important;
        overflow: visible !important;
      }
      #gandalf-timer-text {
        display: none !important;
        margin-left: 6px !important;
        font-weight: 500 !important;
        white-space: nowrap !important;
      }
      #gandalf-timer-widget:hover #gandalf-timer-text {
        display: inline !important;
      }
    `;

    document.documentElement.appendChild(style);

    const iconSpan = document.createElement('span');
    iconSpan.textContent = '🧙‍♂️';
    iconSpan.style.cssText = 'display: inline-block !important; line-height: 1 !important;';

    const textSpan = document.createElement('span');
    textSpan.id = 'gandalf-timer-text';

    widget.appendChild(iconSpan);
    widget.appendChild(textSpan);
    document.documentElement.appendChild(widget);

    function updateWidget() {
        setGraceRunning(graceShouldRun());

        const timeLeft = graceRemainingMs();
        if (timeLeft <= 0 || graceIsStale()) {
            widget.remove();
            spendGrace();
            return;
        }

        const totalSecs = Math.ceil(timeLeft / 1000);
        let amount;
        if (totalSecs >= 60) {
            const mins = Math.ceil(totalSecs / 60);
            amount = `${mins} ${mins === 1 ? 'minute' : 'minutes'}`;
        } else {
            amount = `${totalSecs} ${totalSecs === 1 ? 'second' : 'seconds'}`;
        }

        const running = Number(GM_getValue(RESUMED_KEY)) || 0;
        textSpan.textContent = running
            ? `Gandalf's grace will last for another ${amount}.`
            : `Gandalf's grace is held at ${amount} while you are away.`;
    }

    updateWidget();
    setInterval(updateWidget, 1000);
    // Hidden tabs get their timers throttled to ~1/min, so don't wait for a tick
    // to notice you left — otherwise you'd be charged for up to a minute of it.
    document.addEventListener('visibilitychange', () => setGraceRunning(graceShouldRun()));
}

if (graceRemainingMs() > 0 && !graceIsStale()) {
    setGraceRunning(graceShouldRun());

    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', injectFloatingWidget);
    } else {
        injectFloatingWidget();
    }
    return;
}

// A balance that ran out or went stale while the tab was closed still owes a toll.
// Keyed off the shelf stamp, not the remainder — a remainder of exactly 0 is
// falsy and would hand out a free pass.
if (Number(GM_getValue(SHELF_KEY))) {
    spendGrace();
    return;
}

// Global active blocker checks
let inCooldown = (cooldown > now);
let unlocked = false;
let state = 0;
let graceMinutes = GRACE_MIN;
let typingStartTime = null;
let currentWordIndex = 0;
let words = [];
let cpmInterval = null;

// --- FLICKER-FREE TITLE INTERCEPTION ---
function interceptTitle() {
    try {
        const targetProto = ('title' in document) ? Document.prototype : HTMLDocument.prototype;
        const desc = Object.getOwnPropertyDescriptor(targetProto, 'title');

        Object.defineProperty(document, 'title', {
            get() {
                return unlocked ? desc.get.call(this) : 'YOU SHALL NOT PASS';
            },
            set(val) {
                if (unlocked) {
                    desc.set.call(this, val);
                } else {
                    desc.set.call(this, 'YOU SHALL NOT PASS');
                }
            },
            configurable: true
        });
    } catch (e) {
        // Fallback
    }
    if (!unlocked) {
        document.title = 'YOU SHALL NOT PASS';
    }
}

interceptTitle();

function setupTitleObserver() {
    const observer = new MutationObserver(() => {
        if (!unlocked && document.title !== 'YOU SHALL NOT PASS') {
            document.title = 'YOU SHALL NOT PASS';
        }
    });

    const checkHead = setInterval(() => {
        if (document.head) {
            clearInterval(checkHead);
            observer.observe(document.head, {
                childList: true,
                subtree: true,
                characterData: true
            });
            if (!unlocked) document.title = 'YOU SHALL NOT PASS';
        }
    }, 50);
}
setupTitleObserver();

// --- FAVICON CONTROLLER ---
function setEmojiFavicon() {
    if (!document.head) return;
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="56">🧙‍♂️</text></svg>';
    const svg64 = btoa(unescape(encodeURIComponent(svg)));
    const url = `data:image/svg+xml;base64,${svg64}`;

    const existingIcons = document.querySelectorAll('link[rel*="icon"]');
    existingIcons.forEach(icon => icon.remove());

    const link = document.createElement('link');
    link.rel = 'icon';
    link.type = 'image/svg+xml';
    link.href = url;
    document.head.appendChild(link);
}
let faviconInterval = setInterval(setEmojiFavicon, 500);

function injectBlockStyle() {
    if (document.getElementById('block-style')) return;
    const style = document.createElement('style');
    style.id = 'block-style';
    style.textContent = `
        html, body { overflow: hidden !important; height: 100% !important; margin: 0 !important; padding: 0 !important; }

        #gandalf-overlay {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            background: #ffffff !important;
            z-index: 2147483647 !important;
            box-sizing: border-box !important;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif !important;
            font-size: 16px !important;
            color: #111 !important;
            padding: 10px !important;
            display: flex !important;
            justify-content: center !important;
            align-items: center !important;
            overflow: hidden !important;
        }

        #gandalf-card {
            max-width: 640px !important;
            width: 100% !important;
            background: #fff !important;
            border-radius: 12px !important;
            box-shadow: 0 4px 20px 0 rgba(0,0,0,0.08) !important;
            padding: 16px !important;
            text-align: center !important;
            border: 1.5px solid #eee !important;
            box-sizing: border-box !important;
            display: flex !important;
            flex-direction: column !important;
            max-height: 90vh !important;
            overflow-y: auto !important;
        }

        #gandalf-card img {
            max-height: 35vh !important;
            width: auto !important;
            max-width: 100% !important;
            object-fit: contain !important;
            margin: 0 auto 12px auto !important;
            flex-shrink: 1 !important;
            display: block !important;
        }

        #gandalf-overlay input, #gandalf-overlay button, #gandalf-overlay select, #gandalf-overlay textarea { font-size: 16px !important; border: 1.5px solid #222 !important; border-radius: 5px !important; background: #fff !important; color: #111 !important; outline: none !important; box-shadow: none !important; font-family: inherit !important; transition: background .18s, border .15s; }
        #gandalf-overlay button { background: #fff5a2 !important; color: #222 !important; border: 1.5px solid #bba800 !important; cursor: pointer; font-weight: 500; transition: background .18s, color .15s; }
        #gandalf-overlay button:hover:not(:disabled) { background: #ffe066 !important; color: #222 !important; border-color: #e3c500 !important; }
        #gandalf-overlay button:disabled { background: #f5f5f5 !important; color: #aaa !important; border: 1.5px solid #ccc !important; cursor: not-allowed; }
        #gandalf-overlay input[type="range"] { width: 130px !important; margin: 0 9px; accent-color: #e3c500; }
        #gandalf-overlay input:focus, #gandalf-overlay button:focus { border-color: #777 !important; }
        #gandalf-overlay pre { color: #b00 !important; }
    `;
    document.documentElement.appendChild(style);
}

// --- PERSISTENT EVENT DELEGATION ---
function setupContainerListeners(container) {
    container.addEventListener('click', (e) => {
        const pleaBtn = e.target.closest('#plea');
        const submitBtn = e.target.closest('#submitMin');

        if (pleaBtn) {
            state = 1;
            render();
        }
        if (submitBtn) {
            const slider = document.getElementById('minSlider');
            if (slider) {
                const val = parseInt(slider.value, 10);
                const offGrid = (val - GRACE_MIN) % GRACE_STEP !== 0;
                if (!Number.isInteger(val) || val < GRACE_MIN || val > GRACE_MAX || offGrid) {
                    const errSpan = document.getElementById('minErr');
                    if (errSpan) errSpan.textContent = `${GRACE_MIN}–${GRACE_MAX}, in steps of ${GRACE_STEP}.`;
                    slider.focus();
                } else {
                    graceMinutes = val;
                    state = 2;
                    render();
                }
            }
        }
    });

    container.addEventListener('input', (e) => {
        const slider = e.target.closest('#minSlider');
        if (slider) {
            graceMinutes = parseInt(slider.value, 10);
            const valSpan = document.getElementById('sliderVal');
            if (valSpan) valSpan.textContent = graceMinutes;
            const cdSpan = document.getElementById('cdPreview');
            if (cdSpan) cdSpan.textContent = cooldownFor(graceMinutes);
        }
    });

    container.addEventListener('keydown', (e) => {
        const slider = e.target.closest('#minSlider');
        if (slider && e.key === 'Enter') {
            const btn = document.getElementById('submitMin');
            if (btn) btn.click();
        }
    });
}

function ensureContainer() {
    let container = document.getElementById('gandalf-overlay');
    if (!container) {
        container = document.createElement('div');
        container.id = 'gandalf-overlay';
        setupContainerListeners(container);
        document.documentElement.appendChild(container);
        return true;
    }
    return false;
}

function calculateCPM(currentInputLength) {
    if (!typingStartTime) return 0;
    const elapsedMinutes = (Date.now() - typingStartTime) / 60000;
    if (elapsedMinutes <= 0) return 0;

    const completedChars = words.slice(0, currentWordIndex).join(' ').length + (currentWordIndex > 0 ? 1 : 0);
    const totalChars = completedChars + currentInputLength;
    return Math.round(totalChars / elapsedMinutes);
}

function updateTypeDisplay(currentIndex) {
    const doneSpan = document.getElementById('gandalf-text-done');
    const curSpan = document.getElementById('gandalf-text-current');
    const remSpan = document.getElementById('gandalf-text-remaining');
    const textArea = document.getElementById('gandalf-text-area');

    if (!doneSpan || !curSpan || !remSpan) return;

    doneSpan.textContent = words.slice(0, currentIndex).join(' ') + (currentIndex > 0 ? ' ' : '');
    curSpan.textContent = words[currentIndex] || '';
    remSpan.textContent = (currentIndex < words.length - 1 ? ' ' : '') + words.slice(currentIndex + 1).join(' ');

    const currentInputLength = document.getElementById('chk')?.value.length || 0;
    const cpm = calculateCPM(currentInputLength);
    updateProgressText(currentIndex, cpm);

    // Dynamic centered autoscroll
    if (textArea && curSpan) {
        curSpan.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
}

function updateProgressText(currentIndex, cpm) {
    const progressSpan = document.getElementById('gandalf-progress');
    if (progressSpan) {
        const elapsed = typingStartTime ? Math.round((Date.now() - typingStartTime) / 1000) : 0;
        progressSpan.textContent = `Rune ${currentIndex + 1} of ${words.length} | ${cpm} CPM | ${elapsed}s`;
    }
}

/** Cooldown length in minutes for a given grace request. */
function cooldownFor(minutes) {
    return Math.max(COOLDOWN_FLOOR_MINUTES, minutes * COOLDOWN_RATIO);
}

/** One extra passage per step up the slider. Targeting a character count instead
 *  made neighbouring steps collide on the same passage count — the sentences are
 *  lumpy, so mapping stop to count keeps the toll strictly increasing. */
function passagesFor(minutes) {
    const step = Math.round((minutes - GRACE_MIN) / GRACE_STEP);
    return Math.min(LOTR_SENTENCES.length, step + 1);
}

function generateDynamicLOTRText(minutes) {
    return LOTR_SENTENCES.slice(0, passagesFor(minutes)).join(" ");
}

// --- COOLDOWN TICKER LOGIC ---
let cooldownInterval = null;

function renderCooldown() {
    ensureContainer();
    const container = document.getElementById('gandalf-overlay');
    if (!container) return;

    function updateCooldownTimer() {
        const remaining = cooldown - Date.now();
        if (remaining <= 0) {
            GM_deleteValue(COOLDOWN_KEY);
            GM_deleteValue(GRACE_TAKEN_KEY);
            location.reload();
            return;
        }
        const totalSecs = Math.ceil(remaining / 1000);
        const mins = Math.floor(totalSecs / 60);
        const secs = totalSecs % 60;
        const minLabel = mins === 1 ? 'minute' : 'minutes';
        const secLabel = secs === 1 ? 'second' : 'seconds';

        const timerSpan = document.getElementById('gandalf-cooldown-timer');
        if (timerSpan) {
            if (mins > 0) {
                timerSpan.textContent = `${mins} ${minLabel} and ${secs} ${secLabel}`;
            } else {
                timerSpan.textContent = `${secs} ${secLabel}`;
            }
        }
    }

    setInnerHTML(container, `
        <div id="gandalf-card">
          <img src="${MEME1}" alt="">
          <h2 style="font-size: 18px; color: #b91c1c; margin: 0 0 10px 0; font-weight: bold;">
            You shall not bypass the Cooldown!
          </h2>
          <div style="font-size: 14px; color: #555; margin-bottom: 16px; line-height: 1.5;">
            Gandalf is keeping you focused. The gates are sealed for another:<br>
            <b id="gandalf-cooldown-timer" style="font-size: 16px; color: #111; display: inline-block; margin-top: 6px;"></b>
          </div>
          <div style="font-size: 12px; color: #888;">
            ${graceTaken ? `You asked for ${graceTaken} min, so the toll is ${cooldownFor(graceTaken)} min. ` : ''}Take this time to focus on your primary task.
          </div>
        </div>
    `);

    setEmojiFavicon();
    injectBlockStyle();
    updateCooldownTimer();
    // The MutationObserver re-renders whenever the host page nukes the overlay,
    // so re-arm rather than stacking a new ticker each time.
    if (cooldownInterval) clearInterval(cooldownInterval);
    cooldownInterval = setInterval(updateCooldownTimer, 1000);
}

function render() {
    if (inCooldown) {
        renderCooldown();
        return;
    }

    ensureContainer();
    const container = document.getElementById('gandalf-overlay');
    if (!container) return;

    if (state === 0) {
        setInnerHTML(container, `
            <div id="gandalf-card">
              <img src="${MEME1}" alt="">
              <button id="plea" style="font-size:16px; padding:10px 22px; border-radius:6px; margin: 0 auto;">
                I want to pass, please...
              </button>
            </div>
        `);
        setEmojiFavicon();
        injectBlockStyle();

    } else if (state === 1) {
        setInnerHTML(container, `
            <div id="gandalf-card">
              <img src="${MEME2}" alt="">
              <div style="font-size:16px; margin-bottom:12px;">
                For how many minutes shall we stall? <span id="sliderVal" style="font-weight:bold;">${graceMinutes}</span>
              </div>
              <div style="display: flex; align-items: center; justify-content: center; gap: 10px; flex-wrap: wrap;">
                <input id="minSlider" type="range" min="${GRACE_MIN}" max="${GRACE_MAX}" step="${GRACE_STEP}" value="${graceMinutes}">
                <button id="submitMin" style="font-size:16px; padding:8px 16px; border-radius:6px;">Cast Spell</button>
              </div>
              <div style="font-size:13px; color:#888; margin-top:10px;">
                The gates then seal for <b id="cdPreview">${cooldownFor(graceMinutes)}</b> minutes.
              </div>
              <span id="minErr" style="color:red;display:block;margin-top:7px;font-size:14px;"></span>
            </div>
        `);
        setEmojiFavicon();
        injectBlockStyle();

    } else if (state === 2) {
        if (words.length === 0) {
            const rawText = generateDynamicLOTRText(graceMinutes);
            words = rawText.replace(/\s+/g, ' ').trim().split(' ');
            currentWordIndex = 0;
            typingStartTime = null;
        }

        setInnerHTML(container, `
            <div id="gandalf-card">
              <img src="${MEME3}" alt="">

              <div style="font-size:14px; margin-bottom:8px; text-align: left; color: #555; font-weight: 500;">
                Speak "friend" or type these runes precisely to breach the gate:
              </div>

              <div id="gandalf-text-area" style="text-align: left; margin: 10px 0; line-height: 1.6; font-size: 15px; border: 1.5px solid #e2e8f0; padding: 12px; border-radius: 8px; background: #fafafa; max-height: 100px; overflow-y: auto; user-select: none;">
                <span id="gandalf-text-done" style="color: #1b5e20; background: #e8f5e9;"></span><span id="gandalf-text-current" style="border-bottom: 2px solid #b91c1c; color: #000000 !important; background: rgba(185, 28, 28, 0.08); font-weight: inherit !important; padding: 0 !important; margin: 0 !important;"></span><span id="gandalf-text-remaining" style="color: #64748b;"></span>
              </div>

              <div id="gandalf-progress" style="text-align: right; font-size: 12px; color: #64748b; font-weight: 500; margin-bottom: 8px;">Rune 1 of ${words.length} | 0 CPM | 0s</div>

              <input id="chk" type="text" style="width:100%; padding:10px; box-sizing: border-box; font-size: 16px;" placeholder="Type the active rune here…" autofocus autocomplete="off" /><br/>
            </div>
        `);

        setEmojiFavicon();
        injectBlockStyle();
        updateTypeDisplay(currentWordIndex);

        const inp = document.getElementById('chk');
        if (!inp) return;

        inp.addEventListener('paste', e => e.preventDefault());
        inp.addEventListener('contextmenu', e => e.preventDefault());

        if (cpmInterval) {
            clearInterval(cpmInterval);
        }

        cpmInterval = setInterval(() => {
            if (typingStartTime && !unlocked) {
                const currentInputLength = inp.value.length;
                const liveCpm = calculateCPM(currentInputLength);
                updateProgressText(currentWordIndex, liveCpm);
            }
        }, 500);

        inp.addEventListener('input', () => {
            if (!typingStartTime) {
                typingStartTime = Date.now();
            }

            const val = inp.value;
            const targetWord = words[currentWordIndex];
            const isLast = currentWordIndex === words.length - 1;
            const expected = isLast ? targetWord : (targetWord + ' ');

            if (expected.startsWith(val)) {
                inp.style.backgroundColor = '#ffffff';

                if (val === expected) {
                    currentWordIndex++;
                    inp.value = '';

                    if (currentWordIndex < words.length) {
                        updateTypeDisplay(currentWordIndex);
                    } else {
                        unlocked = true;
                        clearInterval(cpmInterval);
                        clearInterval(mediaControlInterval);
                        clearInterval(faviconInterval);

                        const finalCPM = calculateCPM(0);
                        const finalElapsed = Math.round((Date.now() - typingStartTime) / 1000);

                        const graceMs = graceMinutes * 60 * 1000;

                        try {
                            GM_setValue(REMAIN_KEY, String(graceMs));
                            GM_setValue(RESUMED_KEY, String(Date.now()));
                            GM_setValue(SHELF_KEY, String(Date.now() + graceMs * GRACE_SHELF_RATIO));
                            GM_setValue(GRACE_TAKEN_KEY, String(graceMinutes));
                        } catch (e) {
                            // Safe fallback
                        }

                        let countdownSeconds = 3;
                        function runCountdown() {
                            if (countdownSeconds > 0) {
                                setInnerHTML(container, `
                                    <div id="gandalf-card">
                                      <img src="${MEME4}" alt="">
                                      <h2 style="font-size: 20px; color: #b91c1c; margin-bottom: 8px; font-weight: bold;">
                                        Fly, you fools! (${countdownSeconds})
                                      </h2>
                                      <div style="font-size: 14px; color: #555; margin-top: 8px;">
                                        Channeled at <b>${finalCPM} CPM</b> | Escaped in <b>${finalElapsed}s</b>
                                      </div>
                                    </div>
                                `);
                                countdownSeconds--;
                                setTimeout(runCountdown, 1000);
                            } else {
                                location.reload();
                            }
                        }
                        runCountdown();
                    }
                }
            } else {
                inp.style.backgroundColor = '#ffebe8';
            }
        });
    }
}

// --- BACKGROUND MEDIA BLOCKING ---
document.addEventListener('play', function(e) {
    if (!unlocked) {
        if (e.target && (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO')) {
            e.target.pause();
            e.target.muted = true;
        }
    }
}, true);

function pauseExistingMedia() {
    if (unlocked) return;
    const mediaElements = document.querySelectorAll('video, audio');
    mediaElements.forEach(media => {
        if (!media.paused) {
            media.pause();
        }
        media.muted = true;
    });
}
let mediaControlInterval = setInterval(pauseExistingMedia, 250);

const blockObserver = new MutationObserver(() => {
    if (!unlocked) {
        if (ensureContainer()) {
            render();
        }
    }
});

function initDOM() {
    if (!document.documentElement) {
        requestAnimationFrame(initDOM);
        return;
    }
    injectBlockStyle();
    ensureContainer();
    render();
    blockObserver.observe(document.documentElement, { childList: true, subtree: true });
}

initDOM();

})();
