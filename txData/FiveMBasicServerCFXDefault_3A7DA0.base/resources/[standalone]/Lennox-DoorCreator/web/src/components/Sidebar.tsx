import {
  LayoutDashboard,
  DoorOpen,
  Layers,
  Building2,
  FileBox,
  Download,
  Database,
  ScrollText,
  Settings,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import type { Page } from '../types';
import { cn } from '../utils/misc';

interface SidebarProps {
  currentPage: Page;
  onNavigate: (page: Page) => void;
  collapsed: boolean;
  onToggleCollapse: () => void;
}

const NAV_ITEMS: { page: Page; icon: typeof LayoutDashboard; label: string }[] = [
  { page: 'dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { page: 'creator', icon: DoorOpen, label: 'Create Door' },
  { page: 'bulk', icon: Layers, label: 'Bulk Create' },
  { page: 'buildings', icon: Building2, label: 'Buildings' },
  { page: 'templates', icon: FileBox, label: 'Templates' },
  { page: 'import', icon: Download, label: 'Import' },
  { page: 'backups', icon: Database, label: 'Backups' },
  { page: 'logs', icon: ScrollText, label: 'Logs' },
  { page: 'settings', icon: Settings, label: 'Settings' },
];

export default function Sidebar({ currentPage, onNavigate, collapsed, onToggleCollapse }: SidebarProps) {
  return (
    <div
      className={cn(
        'flex flex-col border-r border-white/5 bg-black/10 transition-all duration-200',
        collapsed ? 'w-14' : 'w-48'
      )}
    >
      <nav className="flex-1 py-2 space-y-0.5 px-1.5">
        {NAV_ITEMS.map(({ page, icon: Icon, label }) => {
          const active = currentPage === page;
          return (
            <button
              key={page}
              onClick={() => onNavigate(page)}
              className={cn(
                'w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-all duration-150',
                active
                  ? 'text-white'
                  : 'text-gray-500 hover:text-gray-300 hover:bg-white/5'
              )}
              style={active ? { background: 'var(--primary)', color: 'white' } : undefined}
            >
              <Icon size={16} className="flex-shrink-0" />
              {!collapsed && <span className="truncate">{label}</span>}
            </button>
          );
        })}
      </nav>
      <button
        onClick={onToggleCollapse}
        className="p-3 text-gray-600 hover:text-gray-400 transition-colors border-t border-white/5"
      >
        {collapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
      </button>
    </div>
  );
}
