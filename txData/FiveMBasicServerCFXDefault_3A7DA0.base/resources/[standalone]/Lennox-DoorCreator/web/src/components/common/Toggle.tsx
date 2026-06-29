interface ToggleProps {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  description?: string;
}

export default function Toggle({ label, checked, onChange, description }: ToggleProps) {
  return (
    <div className="flex items-center justify-between">
      <div>
        <span className="text-sm text-gray-200">{label}</span>
        {description && <p className="text-xs text-gray-500 mt-0.5">{description}</p>}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        className="relative inline-flex h-5 w-9 items-center rounded-full transition-colors duration-200"
        style={{ background: checked ? 'var(--primary)' : 'rgba(255,255,255,0.1)' }}
      >
        <span
          className="inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform duration-200"
          style={{ transform: checked ? 'translateX(18px)' : 'translateX(3px)' }}
        />
      </button>
    </div>
  );
}
