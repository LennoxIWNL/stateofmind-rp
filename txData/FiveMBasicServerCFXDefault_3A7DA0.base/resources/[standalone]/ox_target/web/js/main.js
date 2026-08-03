// MADE BY MOTION SCRIPTS - https://discord.gg/WRR8q8XYfT

import { createOptions, resetOptionCount } from "./createOptions.js";
import { fetchNui } from "./fetchNui.js";

const optionsWrapper = document.getElementById("options-wrapper");
const body = document.body;
const eye  = document.getElementById("eye");

let isAltPressed = false;
let isVisible    = false;

// ── Style helpers (matches CSS accent vars) ───────────────────────────────

function applyActiveStyle(option) {
  option.style.background   = 'rgba(12, 12, 17, 0.93)';
  option.style.borderColor  = 'rgba(255, 255, 255, 0.11)';
  option.style.color        = 'rgba(255, 255, 255, 0.92)';
  option.style.transform    = 'translateX(7px)';
  option.style.boxShadow    =
    '0 4px 16px rgba(0,0,0,0.55), 0 12px 40px rgba(0,0,0,0.50), 0 0 28px rgba(59,130,246,0.10)';

  const keybind = option.querySelector('.option-keybind');
  const icon    = option.querySelector('.option-icon');

  if (keybind) {
    keybind.style.color       = '#3b82f6';
    keybind.style.background  = 'rgba(59, 130, 246, 0.12)';
    keybind.style.borderColor = 'rgba(59, 130, 246, 0.25)';
  }
  if (icon) {
    icon.style.color     = '#3b82f6';
    icon.style.transform = 'scale(1.15)';
  }
}

function clearActiveStyle(option) {
  option.style.background   = '';
  option.style.borderColor  = '';
  option.style.color        = '';
  option.style.transform    = '';
  option.style.boxShadow    = '';

  const keybind = option.querySelector('.option-keybind');
  const icon    = option.querySelector('.option-icon');

  if (keybind) {
    keybind.style.color       = '';
    keybind.style.background  = '';
    keybind.style.borderColor = '';
  }
  if (icon) {
    icon.style.color     = '';
    icon.style.transform = '';
  }
}

// ── Alt + number shortcut ─────────────────────────────────────────────────

document.addEventListener('keydown', (event) => {
  if (event.key === 'Alt') isAltPressed = true;

  if (isAltPressed && isVisible && event.key >= '1' && event.key <= '9') {
    const idx     = parseInt(event.key) - 1;
    const options = optionsWrapper.querySelectorAll('.option-container');

    if (options[idx]) {
      applyActiveStyle(options[idx]);
      setTimeout(() => {
        options[idx].click();
        fetchNui("releaseAlt", {});
        isAltPressed = false;
      }, 110);
    }
  }
});

document.addEventListener('keyup', (event) => {
  if (event.key === 'Alt') isAltPressed = false;
});

// ── NUI message handler ───────────────────────────────────────────────────

window.addEventListener("message", (event) => {
  optionsWrapper.innerHTML = "";
  resetOptionCount();

  switch (event.data.event) {

    case "visible": {
      isVisible = event.data.state;
      body.style.visibility = event.data.state ? "visible" : "hidden";
      return eye.classList.remove("eye-hover");
    }

    case "leftTarget": {
      return eye.classList.remove("eye-hover");
    }

    case "keyPressed": {
      const idx     = parseInt(event.data.key) - 1;
      const options = optionsWrapper.querySelectorAll('.option-container');

      if (options[idx]) {
        applyActiveStyle(options[idx]);
        setTimeout(() => clearActiveStyle(options[idx]), 240);
      }
      return;
    }

    case "setTarget": {
      eye.classList.add("eye-hover");

      if (event.data.options) {
        for (const type in event.data.options) {
          event.data.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
      }

      if (event.data.zones) {
        for (let i = 0; i < event.data.zones.length; i++) {
          event.data.zones[i].forEach((data, id) => {
            createOptions("zones", data, id + 1, i + 1);
          });
        }
      }
    }
  }
});