const panel = document.getElementById('textui');
const keyEl = document.getElementById('textui-key');
const labelEl = document.getElementById('textui-label');

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;

    if (data.action === 'showTextUI') {
        keyEl.textContent = typeof data.key === 'string' ? data.key : '';
        // textContent, not innerHTML: label text can originate from a config or
        // another resource and must never be able to inject markup.
        labelEl.textContent = typeof data.label === 'string' ? data.label : '';
        panel.classList.remove('hidden');
        return;
    }

    if (data.action === 'hideTextUI') {
        panel.classList.add('hidden');
    }
});
