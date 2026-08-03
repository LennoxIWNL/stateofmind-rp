// MADE BY MOTION SCRIPTS - https://discord.gg/WRR8q8XYfT

import { fetchNui } from "./fetchNui.js";

const optionsWrapper = document.getElementById("options-wrapper");
let optionCount = 0;

function onClick() {
  this.style.pointerEvents = "none";
  fetchNui("select", [this.targetType, this.targetId, this.zoneId]);
  setTimeout(() => (this.style.pointerEvents = "auto"), 100);
}

export function createOptions(type, data, id, zoneId) {
  if (data.hide) return;

  optionCount++;
  const keybindNumber = optionCount > 9 ? '' : optionCount.toString();

  const option = document.createElement("div");

  const keybindElement = keybindNumber
    ? `<span class="option-keybind">${keybindNumber}</span>`
    : '';

  const iconColor = data.iconColor
    ? `style="color:${data.iconColor}"` 
    : '';

  const iconElement = `<i class="fa-fw ${data.icon} option-icon" ${iconColor}></i>`;

  option.innerHTML = `${keybindElement}${iconElement}<p class="option-label">${data.label}</p>`;
  option.className = "option-container";
  option.targetType = type;
  option.targetId = id;
  option.zoneId = zoneId;
  option.keybind = keybindNumber;

  option.addEventListener("click", onClick);
  optionsWrapper.appendChild(option);
}

export function resetOptionCount() {
  optionCount = 0;
}