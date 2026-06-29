import { DoorOpen, Building2, FileBox, ScrollText, RefreshCw } from 'lucide-react';
import type { DoorListItem, Building } from '../types';
import Button from '../components/common/Button';

interface DashboardProps {
  doors: DoorListItem[];
  buildings: Building[];
  refresh: () => Promise<void>;
}

export default function Dashboard({ doors, buildings, refresh }: DashboardProps) {
  const lockedCount = doors.filter((d) => d.state === 1).length;
  const unlockedCount = doors.length - lockedCount;

  const categories: Record<string, number> = {};
  doors.forEach((d) => {
    categories[d.category] = (categories[d.category] || 0) + 1;
  });

  const stats = [
    { label: 'Total Doors', value: doors.length, icon: DoorOpen, color: '#6366f1' },
    { label: 'Buildings', value: buildings.length, icon: Building2, color: '#22c55e' },
    { label: 'Locked', value: lockedCount, icon: DoorOpen, color: '#ef4444' },
    { label: 'Unlocked', value: unlockedCount, icon: DoorOpen, color: '#22c55e' },
  ];

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-white">Dashboard</h2>
          <p className="text-xs text-gray-500 mt-0.5">Overview of your door management system</p>
        </div>
        <Button variant="secondary" size="sm" onClick={refresh} icon={<RefreshCw size={14} />}>
          Refresh
        </Button>
      </div>

      <div className="grid grid-cols-4 gap-3">
        {stats.map((s) => (
          <div key={s.label} className="glass-light rounded-xl p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg" style={{ background: s.color + '15' }}>
                <s.icon size={18} style={{ color: s.color }} />
              </div>
              <div>
                <p className="text-2xl font-bold text-white">{s.value}</p>
                <p className="text-[10px] text-gray-500 uppercase tracking-wider">{s.label}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      {Object.keys(categories).length > 0 && (
        <div className="glass-light rounded-xl p-4">
          <h3 className="text-xs font-semibold text-gray-300 uppercase tracking-wider mb-3">
            Doors by Category
          </h3>
          <div className="space-y-2">
            {Object.entries(categories)
              .sort((a, b) => b[1] - a[1])
              .map(([cat, count]) => {
                const pct = doors.length > 0 ? (count / doors.length) * 100 : 0;
                return (
                  <div key={cat} className="flex items-center gap-3">
                    <span className="text-xs text-gray-400 capitalize w-20 truncate">{cat}</span>
                    <div className="flex-1 h-2 rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all duration-500"
                        style={{ width: `${pct}%`, background: 'var(--primary)' }}
                      />
                    </div>
                    <span className="text-[10px] text-gray-500 font-mono w-8 text-right">{count}</span>
                  </div>
                );
              })}
          </div>
        </div>
      )}

      {buildings.length > 0 && (
        <div className="glass-light rounded-xl p-4">
          <h3 className="text-xs font-semibold text-gray-300 uppercase tracking-wider mb-3">
            Buildings
          </h3>
          <div className="space-y-1">
            {buildings.slice(0, 5).map((b) => (
              <div key={b.id} className="flex items-center justify-between px-2 py-1.5 rounded hover:bg-white/5">
                <span className="text-xs text-white">{b.name}</span>
                <span className="text-[10px] text-gray-500">{b.doors.length} doors</span>
              </div>
            ))}
            {buildings.length > 5 && (
              <p className="text-[10px] text-gray-600 text-center pt-1">
                +{buildings.length - 5} more buildings
              </p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
