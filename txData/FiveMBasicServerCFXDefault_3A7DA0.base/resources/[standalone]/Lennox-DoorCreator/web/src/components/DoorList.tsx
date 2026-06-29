import { useState, useMemo } from 'react';
import { Search, MapPin, Lock, Unlock } from 'lucide-react';
import type { DoorListItem } from '../types';
import Badge from './common/Badge';
import { debounce } from '../utils/misc';

interface DoorListProps {
  doors: DoorListItem[];
  onSelect: (door: DoorListItem) => void;
  selectedId?: number;
}

export default function DoorList({ doors, onSelect, selectedId }: DoorListProps) {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');

  const handleSearch = useMemo(() => debounce((v: unknown) => setSearch(v as string), 300), []);

  const filtered = useMemo(() => {
    let list = doors;
    if (search) {
      const s = search.toLowerCase();
      list = list.filter(
        (d) =>
          d.name.toLowerCase().includes(s) ||
          d.id.toString().includes(s) ||
          d.model.toString().includes(s)
      );
    }
    if (filter !== 'all') {
      list = list.filter((d) => d.category === filter);
    }
    return list;
  }, [doors, search, filter]);

  const categories = useMemo(() => {
    const cats = new Set(doors.map((d) => d.category));
    return ['all', ...Array.from(cats).sort()];
  }, [doors]);

  return (
    <div className="flex flex-col h-full">
      <div className="space-y-2 mb-3">
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500" />
          <input
            type="text"
            placeholder="Search doors..."
            onChange={(e) => handleSearch(e.target.value)}
            className="input-field pl-9"
          />
        </div>
        <div className="flex gap-1 flex-wrap">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setFilter(cat)}
              className={`px-2 py-0.5 rounded text-[10px] capitalize transition-colors ${
                filter === cat
                  ? 'text-white'
                  : 'text-gray-500 hover:text-gray-300 bg-white/5'
              }`}
              style={filter === cat ? { background: 'var(--primary)' } : undefined}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto space-y-1">
        {filtered.length === 0 ? (
          <p className="text-xs text-gray-500 text-center py-8">No doors found</p>
        ) : (
          filtered.map((door) => (
            <button
              key={door.id}
              onClick={() => onSelect(door)}
              className={`w-full text-left p-3 rounded-lg transition-all duration-150 ${
                selectedId === door.id
                  ? 'glow-border bg-white/5'
                  : 'hover:bg-white/5'
              }`}
            >
              <div className="flex items-center justify-between mb-1">
                <span className="text-sm text-white font-medium truncate">{door.name}</span>
                <div className="flex items-center gap-1.5">
                  <Badge text={door.category} variant={door.isDoor ? 'primary' : 'neutral'} />
                  {door.state === 1 ? (
                    <Lock size={12} className="text-red-400" />
                  ) : (
                    <Unlock size={12} className="text-emerald-400" />
                  )}
                </div>
              </div>
              <div className="flex items-center gap-3 text-[10px] text-gray-500">
                <span className="font-mono">#{door.id}</span>
                <span className="flex items-center gap-1">
                  <MapPin size={10} />
                  {door.coords.x.toFixed(1)}, {door.coords.y.toFixed(1)}
                </span>
              </div>
            </button>
          ))
        )}
      </div>

      <div className="pt-2 border-t border-white/5 text-[10px] text-gray-600 text-center">
        {filtered.length} of {doors.length} doors
      </div>
    </div>
  );
}
