import { useState } from 'react';
import { Layers, Play, Square } from 'lucide-react';
import type { BulkUpdateData, JobInfo, ApiResponse, NotificationType } from '../types';
import Button from '../components/common/Button';
import Input from '../components/common/Input';
import Slider from '../components/common/Slider';
import Toggle from '../components/common/Toggle';
import Badge from '../components/common/Badge';
import { fetchNui } from '../utils/nui';

interface BulkCreatorProps {
  jobs: JobInfo[];
  gangs: JobInfo[];
  refresh: () => Promise<void>;
  addNotification: (type: NotificationType, msg: string) => void;
  bulkMode: boolean;
  bulkData: BulkUpdateData | null;
}

export default function BulkCreator({ jobs, gangs, refresh, addNotification, bulkMode, bulkData }: BulkCreatorProps) {
  const [radius, setRadius] = useState(10);
  const [namePattern, setNamePattern] = useState('Door {n}');
  const [locked, setLocked] = useState(true);
  const [saving, setSaving] = useState(false);

  const startBulk = () => fetchNui('startBulk');
  const stopBulk = () => fetchNui('stopBulk');

  const handleRadiusChange = (v: number) => {
    setRadius(v);
    fetchNui('setRadius', { radius: v });
  };

  const toggleEntity = (idx: number) => {
    fetchNui('toggleBulkEntity', { index: idx + 1 });
  };

  const handleCreate = async () => {
    setSaving(true);
    const result = await fetchNui<ApiResponse>('bulkCreate', {
      settings: {
        namePattern,
        state: locked ? 1 : 0,
        groups: {},
        maxDistance: 2.0,
        doorRate: 1.0,
        lockSound: 'door-bolt-4',
        unlockSound: 'door-bolt-4',
      },
    });
    setSaving(false);

    if (result.ok) {
      addNotification('success', result.message || 'Bulk creation complete');
      await refresh();
    } else {
      addNotification('error', result.message || 'Bulk creation failed');
    }
  };

  return (
    <div className="space-y-5 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-white">Bulk Creator</h2>
          <p className="text-xs text-gray-500 mt-0.5">Register multiple doors at once using radius selection</p>
        </div>
        {bulkMode ? (
          <Button variant="danger" onClick={stopBulk} icon={<Square size={14} />}>
            Stop Scan
          </Button>
        ) : (
          <Button onClick={startBulk} icon={<Play size={14} />}>
            Start Scan
          </Button>
        )}
      </div>

      {bulkMode && (
        <>
          <div className="glass-light rounded-xl p-4 space-y-3">
            <Slider
              label="Scan Radius"
              value={radius}
              min={1}
              max={50}
              step={1}
              onChange={handleRadiusChange}
              unit="m"
            />
            <Input
              label="Name Pattern"
              value={namePattern}
              onChange={(e) => setNamePattern(e.target.value)}
              placeholder="Door {n}"
            />
            <Toggle label="Locked by default" checked={locked} onChange={setLocked} />
          </div>

          {bulkData && (
            <div className="glass-light rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">
                  Detected Objects
                </h3>
                <span className="text-xs text-gray-500">
                  {bulkData.count} selected of {bulkData.entities.length}
                </span>
              </div>

              <div className="max-h-64 overflow-y-auto space-y-1">
                {bulkData.entities.length === 0 ? (
                  <p className="text-xs text-gray-500 text-center py-4">
                    No door objects detected in range
                  </p>
                ) : (
                  bulkData.entities.map((e, i) => (
                    <button
                      key={i}
                      onClick={() => toggleEntity(i)}
                      className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-left transition-all ${
                        e.selected !== false ? 'bg-white/5' : 'bg-white/[0.02] opacity-50'
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        <div
                          className="w-3 h-3 rounded border transition-colors"
                          style={{
                            borderColor: e.selected !== false ? 'var(--primary)' : 'rgba(255,255,255,0.2)',
                            background: e.selected !== false ? 'var(--primary)' : 'transparent',
                          }}
                        />
                        <span className="text-xs text-white">{e.modelName}</span>
                        <Badge text={e.category} />
                      </div>
                      <span className="text-[10px] text-gray-500 font-mono">{e.distance}m</span>
                    </button>
                  ))
                )}
              </div>

              {bulkData.count > 0 && (
                <div className="mt-3 pt-3 border-t border-white/5">
                  <Button
                    onClick={handleCreate}
                    disabled={saving || bulkData.count === 0}
                    className="w-full"
                    icon={<Layers size={14} />}
                  >
                    {saving ? 'Creating...' : `Register ${bulkData.count} Doors`}
                  </Button>
                </div>
              )}
            </div>
          )}
        </>
      )}

      {!bulkMode && (
        <div className="flex items-center justify-center py-16 text-gray-600">
          <div className="text-center">
            <Layers size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">Click "Start Scan" to begin detecting doors around you</p>
            <p className="text-xs mt-1 text-gray-700">A radius circle will appear in-game</p>
          </div>
        </div>
      )}
    </div>
  );
}
