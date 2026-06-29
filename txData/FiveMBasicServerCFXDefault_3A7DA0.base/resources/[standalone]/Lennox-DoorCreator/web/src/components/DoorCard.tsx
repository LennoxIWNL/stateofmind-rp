import { MapPin, Lock, Unlock, Hash } from 'lucide-react';
import type { DoorListItem } from '../types';
import Badge from './common/Badge';

interface DoorCardProps {
  door: DoorListItem;
  onClick?: () => void;
}

export default function DoorCard({ door, onClick }: DoorCardProps) {
  return (
    <div
      onClick={onClick}
      className="glass-light rounded-xl p-4 cursor-pointer hover:bg-white/5 transition-all duration-150 group"
    >
      <div className="flex items-start justify-between mb-3">
        <div>
          <h4 className="text-sm font-medium text-white group-hover:text-primary transition-colors">
            {door.name}
          </h4>
          <span className="text-[10px] text-gray-500 font-mono">#{door.id}</span>
        </div>
        <div className="flex items-center gap-1.5">
          <Badge text={door.category} />
          {door.state === 1 ? (
            <div className="p-1 rounded bg-red-500/10">
              <Lock size={12} className="text-red-400" />
            </div>
          ) : (
            <div className="p-1 rounded bg-emerald-500/10">
              <Unlock size={12} className="text-emerald-400" />
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2 text-[10px]">
        <div className="flex items-center gap-1.5 text-gray-500">
          <Hash size={10} />
          <span className="font-mono">{door.model}</span>
        </div>
        <div className="flex items-center gap-1.5 text-gray-500">
          <MapPin size={10} />
          <span className="font-mono">
            {door.coords.x.toFixed(1)}, {door.coords.y.toFixed(1)}
          </span>
        </div>
      </div>

      {door.groups && Object.keys(door.groups).length > 0 && (
        <div className="mt-2 flex gap-1 flex-wrap">
          {Object.keys(door.groups).map((g) => (
            <Badge key={g} text={g} variant="primary" />
          ))}
        </div>
      )}
    </div>
  );
}
