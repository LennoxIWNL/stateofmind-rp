import { useState } from 'react';
import { Plus, Building2, Trash2, Edit3, Shield } from 'lucide-react';
import type { Building, DoorListItem, JobInfo, ApiResponse, NotificationType } from '../types';
import Button from '../components/common/Button';
import Input from '../components/common/Input';
import Badge from '../components/common/Badge';
import { fetchNui } from '../utils/nui';

interface BuildingsProps {
  buildings: Building[];
  doors: DoorListItem[];
  jobs: JobInfo[];
  gangs: JobInfo[];
  refresh: () => Promise<void>;
  addNotification: (type: NotificationType, msg: string) => void;
  showConfirm: (title: string, msg: string, onConfirm: () => void) => void;
}

export default function Buildings({ buildings, doors, jobs, gangs, refresh, addNotification, showConfirm }: BuildingsProps) {
  const [mode, setMode] = useState<'list' | 'create' | 'edit'>('list');
  const [editingBuilding, setEditingBuilding] = useState<Building | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [selectedDoors, setSelectedDoors] = useState<number[]>([]);

  const startCreate = () => {
    setMode('create');
    setName('');
    setDescription('');
    setSelectedDoors([]);
  };

  const startEdit = (b: Building) => {
    setEditingBuilding(b);
    setName(b.name);
    setDescription(b.description);
    setSelectedDoors([...b.doors]);
    setMode('edit');
  };

  const toggleDoor = (id: number) => {
    setSelectedDoors((prev) =>
      prev.includes(id) ? prev.filter((d) => d !== id) : [...prev, id]
    );
  };

  const handleSave = async () => {
    if (!name.trim()) return;

    const data = { name: name.trim(), description, doors: selectedDoors, permissions: {}, metadata: {} };

    let result: ApiResponse;
    if (mode === 'edit' && editingBuilding) {
      result = await fetchNui<ApiResponse>('editBuilding', { id: editingBuilding.id, ...data });
    } else {
      result = await fetchNui<ApiResponse>('createBuilding', data);
    }

    if (result.ok) {
      addNotification('success', result.message || 'Building saved');
      setMode('list');
      await refresh();
    } else {
      addNotification('error', result.message || 'Failed');
    }
  };

  const handleDelete = (b: Building) => {
    showConfirm(
      'Delete Building',
      `Delete "${b.name}"? You can choose to also delete its doors.`,
      async () => {
        const result = await fetchNui<ApiResponse>('deleteBuilding', { id: b.id, deleteDoors: false });
        if (result.ok) {
          addNotification('success', 'Building deleted');
          await refresh();
        }
      }
    );
  };

  if (mode === 'create' || mode === 'edit') {
    return (
      <div className="space-y-5 animate-fade-in">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">
            {mode === 'edit' ? 'Edit Building' : 'Create Building'}
          </h2>
          <Button variant="ghost" onClick={() => setMode('list')}>
            Cancel
          </Button>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <Input label="Building Name" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. MRPD" />
          <Input label="Description" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Optional description" />
        </div>

        <div className="glass-light rounded-xl p-4">
          <h3 className="text-xs font-semibold text-gray-300 uppercase tracking-wider mb-3">
            Assign Doors ({selectedDoors.length})
          </h3>
          <div className="max-h-60 overflow-y-auto space-y-1">
            {doors.map((d) => (
              <button
                key={d.id}
                onClick={() => toggleDoor(d.id)}
                className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-left transition-all ${
                  selectedDoors.includes(d.id) ? 'bg-white/5 glow-border' : 'hover:bg-white/5'
                }`}
              >
                <div className="flex items-center gap-2">
                  <div
                    className="w-3 h-3 rounded border transition-colors"
                    style={{
                      borderColor: selectedDoors.includes(d.id) ? 'var(--primary)' : 'rgba(255,255,255,0.2)',
                      background: selectedDoors.includes(d.id) ? 'var(--primary)' : 'transparent',
                    }}
                  />
                  <span className="text-xs text-white">{d.name}</span>
                  <span className="text-[10px] text-gray-500">#{d.id}</span>
                </div>
                <Badge text={d.category} />
              </button>
            ))}
          </div>
        </div>

        <div className="flex justify-end">
          <Button onClick={handleSave} disabled={!name.trim()}>
            {mode === 'edit' ? 'Save Changes' : 'Create Building'}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-5 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-white">Buildings</h2>
          <p className="text-xs text-gray-500 mt-0.5">Group doors by building for bulk management</p>
        </div>
        <Button onClick={startCreate} icon={<Plus size={14} />}>
          New Building
        </Button>
      </div>

      {buildings.length === 0 ? (
        <div className="flex items-center justify-center py-16 text-gray-600">
          <div className="text-center">
            <Building2 size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">No buildings created yet</p>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-3">
          {buildings.map((b) => (
            <div key={b.id} className="glass-light rounded-xl p-4">
              <div className="flex items-start justify-between mb-2">
                <div>
                  <h3 className="text-sm font-medium text-white">{b.name}</h3>
                  {b.description && <p className="text-xs text-gray-500 mt-0.5">{b.description}</p>}
                </div>
                <div className="flex gap-1">
                  <button onClick={() => startEdit(b)} className="p-1.5 rounded hover:bg-white/5 text-gray-500 hover:text-gray-300">
                    <Edit3 size={12} />
                  </button>
                  <button onClick={() => handleDelete(b)} className="p-1.5 rounded hover:bg-red-500/10 text-gray-500 hover:text-red-400">
                    <Trash2 size={12} />
                  </button>
                </div>
              </div>
              <div className="flex items-center gap-3 text-[10px] text-gray-500">
                <span>{b.doors.length} doors</span>
                <span>by {b.createdBy}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
