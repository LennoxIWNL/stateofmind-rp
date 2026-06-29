import { Minus, X } from 'lucide-react';

interface HeaderProps {
  onClose: () => void;
}

export default function Header({ onClose }: HeaderProps) {
  return (
    <div className="flex items-center justify-between px-5 py-3 border-b border-white/5 bg-black/20">
      <div className="flex items-center gap-3">
        <div
          className="w-2 h-2 rounded-full"
          style={{ background: 'var(--primary)', boxShadow: '0 0 8px var(--primary-glow)' }}
        />
        <h1 className="text-sm font-semibold tracking-wide">
          <span style={{ color: 'var(--primary)' }}>Lennox</span>
          <span className="text-gray-300 ml-1.5">Door Creator</span>
        </h1>
        <span className="text-[10px] text-gray-600 font-mono">v1.0.0</span>
      </div>
      <div className="flex items-center gap-1">
        <button
          onClick={onClose}
          className="p-1.5 rounded-md text-gray-500 hover:text-gray-300 hover:bg-white/5 transition-colors"
        >
          <Minus size={14} />
        </button>
        <button
          onClick={onClose}
          className="p-1.5 rounded-md text-gray-500 hover:text-red-400 hover:bg-red-500/10 transition-colors"
        >
          <X size={14} />
        </button>
      </div>
    </div>
  );
}
