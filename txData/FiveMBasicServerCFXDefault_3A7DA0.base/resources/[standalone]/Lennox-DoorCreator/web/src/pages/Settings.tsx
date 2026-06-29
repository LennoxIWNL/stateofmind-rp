import { useTheme } from '../context/ThemeContext';
import ColorPicker from '../components/common/ColorPicker';

export default function Settings() {
  const { themeColor, setThemeColor } = useTheme();

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h2 className="text-lg font-semibold text-white">Settings</h2>
        <p className="text-xs text-gray-500 mt-0.5">Customize your Lennox Door Creator experience</p>
      </div>

      <div className="glass-light rounded-xl p-5 space-y-4">
        <h3 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">Theme</h3>
        <ColorPicker label="Primary Color" value={themeColor} onChange={setThemeColor} />

        <div className="pt-3 border-t border-white/5">
          <h4 className="text-xs text-gray-400 mb-3">Preview</h4>
          <div className="flex gap-3">
            <button className="btn-primary text-xs">Primary Button</button>
            <button className="btn-secondary text-xs">Secondary</button>
            <button className="btn-danger text-xs">Danger</button>
          </div>
          <div className="mt-3 flex gap-3 items-center">
            <div className="w-16 h-2 rounded-full" style={{ background: 'var(--primary)' }} />
            <div className="w-16 h-2 rounded-full" style={{ background: 'var(--primary-hover)' }} />
            <div className="w-16 h-2 rounded-full" style={{ background: 'var(--primary-muted)' }} />
            <span className="text-[10px] text-gray-500">Color variants</span>
          </div>
        </div>
      </div>

      <div className="glass-light rounded-xl p-5">
        <h3 className="text-xs font-semibold text-gray-300 uppercase tracking-wider mb-3">About</h3>
        <div className="space-y-2 text-xs">
          <div className="flex justify-between">
            <span className="text-gray-500">Product</span>
            <span className="text-white">Lennox Door Creator</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-500">Version</span>
            <span className="text-white font-mono">1.0.0</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-500">Author</span>
            <span style={{ color: 'var(--primary)' }}>Lennox</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-500">Target System</span>
            <span className="text-white">ox_doorlock</span>
          </div>
        </div>
      </div>
    </div>
  );
}
