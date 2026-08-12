/**
 * The /sethud editor.
 *
 * Drag to move, wheel to scale, toggle to hide. Everything it sends is LAYOUT:
 * where a panel sits, how big it is, whether it is on, and which variant it
 * uses. It cannot send a value, which is why the Lua accepts it without a
 * server round trip.
 */

import { useState } from 'react'
import { fetchNui } from '@som/ui-kit'
import {
  DEFAULT_LAYOUT, OUTBOUND, PANELS, PANEL_LABELS,
  type Layout, type PanelId,
} from '../contract'

type Props = {
  layout: Layout
  /** Live, unsaved changes, so dragging updates behind the dialog. */
  onChange: (next: Layout) => void
  onSave: (next: Layout) => void
}

export function Editor({ layout, onChange, onSave }: Props) {
  const [io, setIo] = useState<string | null>(null)
  const [note, setNote] = useState<string | null>(null)

  const toggle = (id: PanelId) =>
    onChange({ ...layout, [id]: { ...layout[id], on: !layout[id].on } })

  const exportLayout = async () => {
    const res = await fetchNui<{ layout: Layout | false }>(OUTBOUND.exportLayout, {}, { layout: false })
    setIo(JSON.stringify(res?.layout || layout, null, 2))
    setNote('Copy this and keep it somewhere.')
  }

  const importLayout = async () => {
    if (!io) return
    const res = await fetchNui<{ ok: boolean }>(OUTBOUND.importLayout, { raw: io }, { ok: false })
    setNote(res?.ok ? 'Imported.' : 'That is not a layout.')
  }

  return (
    <div className="hud-editor" onPointerDown={(e) => e.stopPropagation()} onWheel={(e) => e.stopPropagation()}>
      <header className="hud-editor__head">
        <h2>Edit positions</h2>
        <button className="hud-editor__esc" onClick={() => void fetchNui(OUTBOUND.closeEditor)}>
          ESC
        </button>
      </header>

      <p className="hud-editor__hint">
        Drag a panel to move it. Scroll on it to scale. Toggles hide it entirely.
      </p>

      <div className="hud-editor__styles">
        <label>
          <span>Speedometer</span>
          <select
            value={layout.speedoStyle}
            onChange={(e) => onChange({ ...layout, speedoStyle: e.target.value as Layout['speedoStyle'] })}
          >
            <option value="digital">Digital</option>
            <option value="ring">Ring</option>
          </select>
        </label>

        <label>
          <span>Compass</span>
          <select
            value={layout.compassStyle}
            onChange={(e) => onChange({ ...layout, compassStyle: e.target.value as Layout['compassStyle'] })}
          >
            <option value="primary">Primary</option>
            <option value="minimal">Minimal</option>
          </select>
        </label>
      </div>

      <div className="hud-editor__panels">
        {PANELS.map((id) => (
          <label key={id} className="hud-editor__toggle">
            <span>{PANEL_LABELS[id]}</span>
            <input type="checkbox" checked={layout[id]?.on ?? true} onChange={() => toggle(id)} />
            <i aria-hidden="true" />
          </label>
        ))}
      </div>

      {io !== null && (
        <textarea
          className="hud-editor__io"
          value={io}
          spellCheck={false}
          onChange={(e) => setIo(e.target.value)}
          placeholder="Paste a layout here, then Import."
        />
      )}

      {note && <p className="hud-editor__note">{note}</p>}

      <div className="hud-editor__actions">
        <button className="hud-btn" onClick={() => void exportLayout()}>Export</button>
        <button className="hud-btn" onClick={() => (io === null ? setIo('') : void importLayout())}>
          Import
        </button>
        <button
          className="hud-btn hud-btn--danger"
          onClick={() => {
            onChange(DEFAULT_LAYOUT)
            void fetchNui(OUTBOUND.resetLayout)
            setNote('Reset to defaults.')
          }}
        >
          Reset
        </button>
        <button className="hud-btn hud-btn--save" onClick={() => onSave(layout)}>
          Save positions
        </button>
      </div>
    </div>
  )
}
