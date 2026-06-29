interface ColorPickerProps {
  label: string;
  value: string;
  onChange: (hex: string) => void;
}

const PRESETS = [
  '#6366f1', '#8b5cf6', '#a855f7', '#ec4899',
  '#ef4444', '#f97316', '#eab308', '#22c55e',
  '#14b8a6', '#06b6d4', '#3b82f6', '#6b7280',
];

export default function ColorPicker({ label, value, onChange }: ColorPickerProps) {
  return (
    <div className="space-y-2">
      <label className="text-xs text-gray-400 font-medium">{label}</label>
      <div className="flex items-center gap-3">
        <input
          type="color"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-8 h-8 rounded cursor-pointer border-0 bg-transparent"
        />
        <input
          type="text"
          value={value}
          onChange={(e) => {
            if (/^#[0-9A-Fa-f]{6}$/.test(e.target.value)) onChange(e.target.value);
          }}
          className="input-field w-24 font-mono text-xs"
          maxLength={7}
        />
      </div>
      <div className="flex gap-1.5 flex-wrap">
        {PRESETS.map((c) => (
          <button
            key={c}
            onClick={() => onChange(c)}
            className="w-6 h-6 rounded transition-transform hover:scale-110"
            style={{
              background: c,
              outline: value === c ? '2px solid white' : 'none',
              outlineOffset: 1,
            }}
          />
        ))}
      </div>
    </div>
  );
}
