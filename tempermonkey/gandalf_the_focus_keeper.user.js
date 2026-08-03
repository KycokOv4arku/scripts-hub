// ==UserScript==
// @name         Gandalf the Focus Keeper
// @namespace    http://tampermonkey.net/
// @version      260803
// @description  Gandalf blocks mindless visits to distracting sites (socials, news, forums)—unless you really insist and jump through his hoops.
// @author       👾claude sonnet 5 [mid] & 🤖gemini 3.5 flash [mid] for kckv4rk
// @run-at       document-start
// @match        *://dtf.ru/*
// @match        *://meduza.io/*
// @match        *://*.youtube.com/*
// @grant        none
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

const NUM_WORDS = [
    "zero","one","two","three","four","five","six","seven","eight","nine","ten",
    "eleven","twelve","thirteen","fourteen","fifteen","sixteen","seventeen","eighteen","nineteen","twenty",
    "twenty-one","twenty-two","twenty-three","twenty-four","twenty-five","twenty-six","twenty-seven","twenty-eight","twenty-nine","thirty"
];

const LOTR_SENTENCES = [
    "The road goes ever on, yet you stand frozen at the crossroads of illusion, lured by the whispers of the digital void.",
    "A shadow lies upon your purpose; the glowing screen binds your gaze with a subtle, unproductive power.",
    "Many that live deserve rest, but these hours are stolen by idle thoughts, like leaves scattered before the cold wind.",
    "Even the smallest task can change the course of your day, if but the courage is found to cast aside these fleeting comforts.",
    "Despair not, for the mind may yet be fortified against the creeping haze of procrastination that seeks to dim your inner fire.",
    "Stand fast, traveler of the West, and reclaim the fleeting moments of your life before they slip away into the dark."
];
// ------------------------------------

const KEY   = 'blockUntil';
const now   = Date.now();
const until = Number(localStorage.getItem(KEY)) || 0;

// --- FLOATING UNBLOCK TIMER WIDGET (TRUSTED-TYPES SAFE) ---
function injectFloatingWidget(untilTime) {
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
        const timeLeft = untilTime - Date.now();
        if (timeLeft <= 0) {
            widget.remove();
            location.reload();
            return;
        }

        const totalSecs = Math.ceil(timeLeft / 1000);

        if (totalSecs >= 60) {
            const mins = Math.ceil(totalSecs / 60);
            const minLabel = mins === 1 ? 'minute' : 'minutes';
            textSpan.textContent = `Gandalf's grace will last for another ${mins} ${minLabel}.`;
        } else {
            const secLabel = totalSecs === 1 ? 'second' : 'seconds';
            textSpan.textContent = `Gandalf's grace will last for another ${totalSecs} ${secLabel}.`;
        }
    }

    updateWidget();
    setInterval(updateWidget, 1000);
}

// Handle Allowed state (Grace period)
if (location.search.includes('reset')) {
    localStorage.removeItem(KEY);
    return;
}
if (until > now) {
    const initializeWidget = () => {
        injectFloatingWidget(until);
    };

    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', initializeWidget);
    } else {
        initializeWidget();
    }
    setTimeout(() => location.reload(), until - now + 500);
    return;
}

let unlocked = false;
let state = 0;
let graceMinutes = 1;
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
    const url   = `data:image/svg+xml;base64,${svg64}`;

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
        #gandalf-overlay { position: fixed !important; top: 0 !important; left: 0 !important; width: 100vw !important; height: 100vh !important; background: #ffffff !important; z-index: 2147483647 !important; overflow-y: auto !important; box-sizing: border-box !important; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif !important; font-size: 16px !important; color: #111111 !important; padding: 20px !important; }
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
                if (!Number.isInteger(val) || val < 1 || val > 30) {
                    const errSpan = document.getElementById('minErr');
                    if (errSpan) errSpan.textContent = 'Input 1–30 only.';
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

    // Auto-scroll logic: Keeps the highlighted word visible inside the scroll box
    if (textArea && curSpan) {
        curSpan.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
}

function updateProgressText(currentIndex, cpm) {
    const progressSpan = document.getElementById('gandalf-progress');
    if (progressSpan) {
        const elapsed = typingStartTime ? Math.round((Date.now() - typingStartTime) / 1000) : 0;
        progressSpan.textContent = `Rune ${currentIndex + 1} of ${words.length} | ${cpm} CPM | ${elapsed}s`;
    }
}

// Generates dynamic LOTR themed text matching length constraints of 150 to 650 characters
function generateDynamicLOTRText(minutes) {
    const minChars = 150;
    const maxChars = 650;
    const targetChars = minChars + ((minutes - 1) / 29) * (maxChars - minChars);

    let selectedSentences = [];
    let cumulativeLength = 0;

    for (let i = 0; i < LOTR_SENTENCES.length; i++) {
        selectedSentences.push(LOTR_SENTENCES[i]);
        cumulativeLength += LOTR_SENTENCES[i].length + (i > 0 ? 1 : 0);
        if (cumulativeLength >= targetChars) {
            break;
        }
    }
    return selectedSentences.join(" ");
}

function render() {
    ensureContainer();
    const container = document.getElementById('gandalf-overlay');
    if (!container) return;

    const cardCSS = `
      max-width:440px;
      margin:60px auto 0 auto;
      background:#fff;
      border-radius:16px;
      box-shadow:0 4px 24px 0 #0001;
      padding:30px 22px 24px 22px;
      text-align:center;
      border:1.5px solid #eee;
    `;

    if (state === 0) {
        setInnerHTML(container, `
            <div id="gandalf-card" style="${cardCSS}">
              <img src="${MEME1}" alt="" style="max-width:100%;height:auto; border-radius:10px; margin-bottom:24px;">
              <button id="plea" style="font-size:16px; padding:10px 22px; border-radius:6px;">
                I want to pass, please...
              </button>
            </div>
        `);
        setEmojiFavicon();
        injectBlockStyle();

    } else if (state === 1) {
        setInnerHTML(container, `
            <div id="gandalf-card" style="${cardCSS}">
              <img src="${MEME2}" alt="" style="max-width:100%;height:auto; border-radius:10px; margin-bottom:24px;">
              <div style="font-size:16px; margin-bottom:16px;">
                For how many minutes shall we stall? <span id="sliderVal" style="font-weight:bold;">${graceMinutes}</span>
              </div>
              <input id="minSlider" type="range" min="1" max="30" value="${graceMinutes}">
              <button id="submitMin" style="font-size:16px; margin-left:12px; padding:8px 16px; border-radius:6px;">Cast Spell</button>
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
            <div id="gandalf-card" style="${cardCSS}">
              <img src="${MEME3}" alt="" style="max-width:100%;height:auto; border-radius:10px; margin-bottom:15px;">

              <div style="font-size:15px; margin-bottom:12px; text-align: left; color: #555; font-weight: 500;">
                Speak "friend" or type these ruins precisely to breach the gate:
              </div>

              <div id="gandalf-text-area" style="text-align: left; margin: 12px 0; line-height: 1.6; font-size: 15px; border: 1.5px solid #e2e8f0; padding: 14px; border-radius: 8px; background: #fafafa; max-height: 110px; overflow-y: auto; user-select: none;">
                <span id="gandalf-text-done" style="color: #1b5e20; background: #e8f5e9;"></span><span id="gandalf-text-current" style="border-bottom: 2px solid #b91c1c; font-weight: bold; color: #000000 !important; background: transparent; padding: 0 1px;"></span><span id="gandalf-text-remaining" style="color: #64748b;"></span>
              </div>

              <div id="gandalf-progress" style="text-align: right; font-size: 12px; color: #64748b; font-weight: 500; margin-bottom: 10px;">Rune 1 of ${words.length} | 0 CPM | 0s</div>

              <input id="chk" type="text" style="width:100%; padding:10px; box-sizing: border-box; font-size: 16px;" placeholder="Type the active rune here…" autofocus autocomplete="off" /><br/>
            </div>
        `);

        setEmojiFavicon();
        injectBlockStyle();
        updateTypeDisplay(currentWordIndex);

        const inp = document.getElementById('chk');
        if (!inp) return;

        inp.addEventListener('paste',       e => e.preventDefault());
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

                        try {
                            localStorage.setItem(KEY, String(Date.now() + graceMinutes * 60 * 1000));
                        } catch (e) {
                            // Safe fallback
                        }

                        let countdownSeconds = 3;
                        function runCountdown() {
                            if (countdownSeconds > 0) {
                                setInnerHTML(container, `
                                    <div id="gandalf-card" style="${cardCSS}">
                                      <img src="${MEME4}" alt="" style="max-width:100%;height:auto; border-radius:10px; margin-bottom:15px;">
                                      <h2 style="font-size: 20px; color: #b91c1c; margin-bottom: 12px; font-weight: bold;">
                                        Fly, you fools! (${countdownSeconds})
                                      </h2>
                                      <div style="font-size: 14px; color: #555; margin-top: 10px;">
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