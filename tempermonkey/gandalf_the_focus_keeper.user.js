// ==UserScript==
// @name         Gandalf the Focus Keeper
// @namespace    http://tampermonkey.net/
// @version      250515
// @description  Gandalf blocks mindless visits to distracting sites (socials, news, forums)—unless you really insist and jump through his hoops.
// @match        *://dtf.ru/*
// @grant        none
// ==/UserScript==

// Disclaimer: LLMs have been used to help generate the code.


(function() {
  'use strict';

  // ----- CONFIGURABLE VARS AT TOP -----
  const MEME1 = 'https://i125.fastpic.org/big/2025/0515/73/d074c6e3395810d4c9c2a22873010e73.jpeg'; // until u try and dislike images, keep them
  const MEME2 = 'https://i125.fastpic.org/big/2025/0515/0c/f2a693003f6f74497144d5d5c8f9850c.jpeg'; // until u try and dislike images, keep them
  const MEME3 = 'https://i125.fastpic.org/big/2025/0515/fe/f9c4e239f1d07217375bf1d7237184fe.jpeg'; // until u try and dislike images, keep them
  const NUM_WORDS = [
    "zero","one","two","three","four","five","six","seven","eight","nine","ten",
    "eleven","twelve","thirteen","fourteen","fifteen","sixteen","seventeen","eighteen","nineteen","twenty",
    "twenty-one","twenty-two","twenty-three","twenty-four","twenty-five","twenty-six","twenty-seven","twenty-eight","twenty-nine","thirty"
  ];
  // Template for the phrase challenge, using {minutes_word} as a placeholder. 
  // Avoid very short phrases. The goal to give yourself ~30 seconds of struggle to get to the content:
  const RAW_TARGET_TEXT = "I know this is a distracting site, and I'm opening it on purpose to take a break from what I should be doing. For the next {minutes_word} minutes, I don't expect to do anything useful. I just want to relax, waste time, and not feel bad about it.";
  // ------------------------------------

  const KEY   = 'blockUntil';
  const now   = Date.now();
  const until = Number(localStorage.getItem(KEY)) || 0;

  // Only run if not in grace period:
  if (location.search.includes('reset')) {
    localStorage.removeItem(KEY);
    return;
  }
  if (until > now) {
    setTimeout(() => location.reload(), until - now + 500);
    return;
  }

  // Title-locker (only while blocking)
  document.title = 'YOU SHALL NOT PASS';
  let titleInterval = setInterval(() => {
    if (document.title !== 'YOU SHALL NOT PASS') {
      document.title = 'YOU SHALL NOT PASS';
    }
  }, 333);

  function setEmojiFavicon() {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">
      <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="64">🧙‍♂️</text>
    </svg>`;
    const svg64 = btoa(unescape(encodeURIComponent(svg)));
    const url   = `data:image/svg+xml;base64,${svg64}`;
    let link = document.querySelector('link[rel="icon"]')
            || document.querySelector('link[rel="shortcut icon"]');
    if (!link) {
      link = document.createElement('link');
      link.rel = 'icon';
      document.head.appendChild(link);
    }
    link.href = url;
  }

  // trying to fight css bleeding from sites. 
  function injectBlockStyle() {
    if (document.getElementById('block-style')) return;
    const style = document.createElement('style');
    style.id = 'block-style';
    style.textContent = `
      html, body {
        background: #fff !important;
        color: #111 !important;
      }
      input, button, select, textarea {
        border: 1.5px solid #222 !important;
        border-radius: 5px !important;
        background: #fff !important;
        color: #111 !important;
        outline: none !important;
        box-shadow: none !important;
        font-family: inherit !important;
        transition: background .18s, border .15s;
      }
      button {
        background: #fff5a2 !important;
        color: #222 !important;
        border: 1.5px solid #bba800 !important;
        cursor: pointer;
        font-weight: 500;
        transition: background .18s, color .15s;
      }
      button:hover:not(:disabled) {
        background: #ffe066 !important;
        color: #222 !important;
        border-color: #e3c500 !important;
      }
      button:disabled {
        background: #f5f5f5 !important;
        color: #aaa !important;
        border: 1.5px solid #ccc !important;
        cursor: not-allowed;
      }
      input[type="range"] {
        width: 130px !important;
        margin: 0 9px;
        accent-color: #e3c500;
      }
      input:focus, button:focus {
        border-color: #777 !important;
      }
      pre {
        color: #b00 !important;
      }
    `;
    document.head.appendChild(style);
  }

  // --- STATE MACHINE ---
  let state = 0; // 0: meme1+plea, 1: meme2+slider, 2: meme3+phrase
  let graceMinutes = 1;

  function render() {
    const cardCSS = `
      max-width:420px;
      margin:60px auto 0 auto;
      background:#fff;
      border-radius:16px;
      box-shadow:0 4px 24px 0 #0001;
      padding:30px 22px 24px 22px;
      text-align:center;
      border:1.5px solid #eee;
    `;

    if (state === 0) {
      document.body.innerHTML = `
        <div style="${cardCSS}">
          <img src="${MEME1}" alt="" style="max-width:100%;height:auto; border-radius:10px; margin-bottom:24px;">
          <button id="plea" style="font-size:1em; padding:10px 22px; border-radius:6px;">
            But Gandalf, I <b>really</b> want to pass. Pleeease?
          </button>
        </div>
      `;
      setEmojiFavicon();
      injectBlockStyle();
      document.getElementById('plea').onclick = () => {
        state = 1;
        render();
      };

    } else if (state === 1) {
      document.body.innerHTML = `
        <div style="${cardCSS}">
          <img src="${MEME2}" alt="" style="max-width:100%;height:auto; border-radius:10px; margin-bottom:24px;">
          <div style="font-size:1em; margin-bottom:16px;">
            For how long (min)? <span id="sliderVal" style="font-weight:bold;">${graceMinutes}</span>
          </div>
          <input id="minSlider" type="range" min="1" max="30" value="${graceMinutes}">
          <button id="submitMin" style="font-size:1em; margin-left:12px; padding:8px 16px; border-radius:6px;">OK</button>
          <span id="minErr" style="color:red;display:block;margin-top:7px;"></span>
        </div>
      `;
      setEmojiFavicon();
      injectBlockStyle();
      const slider = document.getElementById('minSlider');
      const valSpan = document.getElementById('sliderVal');
      slider.oninput = () => {
        graceMinutes = parseInt(slider.value, 10);
        valSpan.textContent = graceMinutes;
      };
      document.getElementById('submitMin').onclick = () => {
        const val = parseInt(slider.value, 10);
        if (!Number.isInteger(val) || val < 1 || val > 30) {
          document.getElementById('minErr').textContent = 'Input 1–30 only.';
          slider.focus();
        } else {
          graceMinutes = val;
          state = 2;
          render();
        }
      };
      slider.addEventListener('keydown', e => {
        if (e.key === 'Enter') document.getElementById('submitMin').click();
      });

    } else if (state === 2) {
      // Substitution: number to word
      const minsWord = NUM_WORDS[graceMinutes];
      const TARGET_TEXT = RAW_TARGET_TEXT.replace('{minutes_word}', minsWord);

      document.body.innerHTML = `
        <div style="${cardCSS}">
          <img src="${MEME3}" alt="" style="max-width:100%;height:auto; border-radius:10px; margin-bottom:22px;">
          <div style="font-size:1em; margin-bottom:10px;">
            To proceed, type this phrase exactly without typos:
          </div>
          <p id="target" style="user-select:none;pointer-events:none;font-style:italic;color:#555; margin:10px 0 14px;">
            ${TARGET_TEXT}
          </p>
          <div style="font-size:0.97em; margin-bottom:7px;">
            If you succeed, you’ll get ${graceMinutes} min of access.
          </div>
          <input id="chk" type="text" style="width:100%;padding:8px; margin-top:3px;" placeholder="Type here…" autofocus /><br/>
          <button id="go" style="margin-top:12px; padding:7px 18px; border-radius:6px;">Submit</button>
          <pre id="err" style="color:#b00;margin-top:1.2em;"></pre>
        </div>
      `;
      setEmojiFavicon();
      injectBlockStyle();
      const inp = document.getElementById('chk');
      const btn = document.getElementById('go');
      const err = document.getElementById('err');

      inp.addEventListener('paste',       e => e.preventDefault());
      inp.addEventListener('contextmenu', e => e.preventDefault());
      inp.addEventListener('keydown', e => {
        if ((e.ctrlKey||e.metaKey) && e.key.toLowerCase()==='v') e.preventDefault();
        if (e.key === 'Enter') { e.preventDefault(); btn.click(); }
      });

      btn.addEventListener('click', () => {
        if (inp.value.trim() === TARGET_TEXT) {
          clearInterval(titleInterval);
          localStorage.setItem(KEY, String(Date.now() + graceMinutes*60*1000));
          location.reload();
        } else {
          err.textContent = 'That wasn’t exactly right. Try again.';
          inp.value = '';
          inp.focus();
        }
      });
    }
  }

  render();

})();
