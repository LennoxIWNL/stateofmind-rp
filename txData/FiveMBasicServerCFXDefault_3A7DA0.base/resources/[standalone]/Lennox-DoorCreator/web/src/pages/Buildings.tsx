import { useState } from 'react';
import { Plus, Building2, Trash2, Edit3, X } from 'lucide-react';
import type { Building, DoorListItem, JobInfo, ApiResponse, NotificationType } from '../types';
import Button from '../components/common/Button';
import Input from '../components/common/Input';
import Toggle from '../components/common/Toggle';
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

interface BuildingPermissions {
  groups: Record<string, number>;
  characters: string[];
  items: string[];
  lockpick: boolean;
  passcode: string | null;
}

const emptyPermissions: BuildingPermissions = {
  groups: {},
  characters: [],
  items: [],
  lockpick: false,
  passcode: null,
};

function readPermissions(b: Building): BuildingPermissions {
  const p = (b.permissions || {}) as Partial<BuildingPermissions>;
  return {
    groups: p.groups || {},
    characters: p.characters || [],
    items: p.items || [],
    lockpick: p.lockpick ?? false,
    passcode: p.passcode ?? null,
  };
}

export default function Buildings({ buildings, doors, jobs, gangs, refresh, addNotification, showConfirm }: BuildingsProps) {
  const [mode, setMode] = useState<'list' | 'create' | 'edit'>('list');
  const [editingBuilding, setEditingBuilding] = useState<Building | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [selectedDoors, setSelectedDoors] = useState<number[]>([]);
  const [saving, setSaving] = useState(false);

  const [groups, setGroups] = useState<Record<string, number>>({});
  const [characters, setCharacters] = useState<string[]>([]);
  const [items, setItems] = useState<string[]>([]);
  const [lockpick, setLockpick] = useState(false);
  const [passcode, setPasscode] = useState('');

  const [newGroupName, setNewGroupName] = useState('');
  const [newGroupGrade, setNewGroupGrade] = useState(0);
  const [newCharacter, setNewCharacter] = useState('');
  const [newItem, setNewItem] = useState('');

  const startCreate = () => {
    setMode('create');
    setName('');
    setDescription('');
    setSelectedDoors([]);
    setGroups({});
    setCharacters([]);
    setItems([]);
    setLockpick(false);
    setPasscode('');
  };

  const startEdit = (b: Building) => {
    setEditingBuilding(b);
    setName(b.name);
    setDescription(b.description);
    setSelectedDoors([...b.doors]);

    const perms = readPermissions(b);
    setGroups(perms.groups);
    setCharacters(perms.characters);
    setItems(perms.items);
    setLockpick(perms.lockpick);
    setPasscode(perms.passcode || '');

    setMode('edit');
  };

  const toggleDoor = (id: number) => {
    setSelectedDoors((prev) =>
      prev.includes(id) ? prev.filter((d) => d !== id) : [...prev, id]
    );
  };

  const addGroup = () => {
    if (!newGroupName) return;
    setGroups({ ...groups, [newGroupName]: newGroupGrade });
    setNewGroupName('');
    setNewGroupGrade(0);
  };

  const removeGroup = (key: string) => {
    const g = { ...groups };
    delete g[key];
    setGroups(g);
  };

  const addCharacter = () => {
    if (!newCharacter.trim()) return;
    setCharacters([...characters, newCharacter.trim()]);
    setNewCharacter('');
  };

  const removeCharacter = (idx: number) => {
    setCharacters(characters.filter((_, i) => i !== idx));
  };

  const addItem = () => {
    if (!newItem.trim()) return;
    setItems([...items, newItem.trim()]);
    setNewItem('');
  };

  const removeItem = (idx: number) => {
    setItems(items.filter((_, i) => i !== idx));
  };

  const handleSave = async () => {
    if (!name.trim()) return;
    setSaving(true);

    const permissions: BuildingPermissions = {
      groups,
      characters,
      items,
      lockpick,
      passcode: passcode || null,
    };

    const data = { name: name.trim(), description, doors: selectedDoors, permissions, metadata: {} };

    let result: ApiResponse;
    if (mode === 'edit' && editingBuilding) {
      result = await fetchNui<ApiResponse>('editBuilding', { id: editingBuilding.id, ...data });
    } else {
      result = await fetchNui<ApiResponse>('createBuilding', data);
    }

    if (result.ok) {
      const buildingId = mode === 'edit' && editingBuilding ? editingBuilding.id : result.id;
      if (buildingId && selectedDoors.length > 0) {
        await fetchNui<ApiResponse>('applyBuildingPerms', { id: buildingId, permissions });
      }
      addNotification('success', result.message || 'Building saved');
      setMode('list');
      setSaving(false);
      await refresh();
    } else {
      setSaving(false);
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

  const allJobs = [...jobs, ...gangs];

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

        <div className="glass-light rounded-xl p-4 space-y-3">
          <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">Passcode</h4>
          <p className="text-[10px] text-gray-500">Applies to every door currently assigned to this building.</p>
          <Input label="Passcode" value={passcode} onChange={(e) => setPasscode(e.target.value)} placeholder="Leave empty for none" />
          <Toggle label="Lockpickable" checked={lockpick} onChange={setLockpick} />
        </div>

        <div className="glass-light rounded-xl p-4 space-y-3">
          <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">
            Job/Gang Permissions ({Object.keys(groups).length})
          </h4>
          <p className="text-[10px] text-gray-500">Applied to every door in this building — overrides per-door settings.</p>
          <div className="space-y-1">
            {Object.entries(groups).map(([key, grade]) => (
              <div key={key} className="flex items-center justify-between px-2 py-1.5 rounded bg-white/5">
                <span className="text-xs text-white">{key}</span>
                <div className="flex items-center gap-2">
                  <span className="text-[10px] text-gray-400">Grade {grade}+</span>
                  <button onClick={() => removeGroup(key)} className="text-red-400 hover:text-red-300">
                    <X size={12} />
                  </button>
                </div>
              </div>
            ))}
          </div>
          <div className="flex gap-2">
            <select
              value={newGroupName}
              onChange={(e) => setNewGroupName(e.target.value)}
              className="input-field flex-1"
            >
              <option value="">Select job/gang...</option>
              {allJobs.map((j) => (
                <option key={j.name} value={j.name}>
                  {j.label} ({j.name})
                </option>
              ))}
            </select>
            <input
              type="number"
              value={newGroupGrade}
              onChange={(e) => setNewGroupGrade(Number(e.target.value))}
              min={0}
              className="input-field w-16"
              placeholder="Grade"
            />
            <Button variant="secondary" size="sm" onClick={addGroup} icon={<Plus size={12} />}>
              Add
            </Button>
          </div>
        </div>

        <div className="glass-light rounded-xl p-4 space-y-3">
          <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">
            Citizen IDs ({characters.length})
          </h4>
          <div className="space-y-1">
            {characters.map((cid, i) => (
              <div key={i} className="flex items-center justify-between px-2 py-1.5 rounded bg-white/5">
                <span className="text-xs text-white font-mono">{cid}</span>
                <button onClick={() => removeCharacter(i)} className="text-red-400 hover:text-red-300">
                  <X size={12} />
                </button>
              </div>
            ))}
          </div>
          <div className="flex gap-2">
            <Input
              value={newCharacter}
              onChange={(e) => setNewCharacter(e.target.value)}
              placeholder="Citizen ID..."
              className="flex-1"
            />
            <Button variant="secondary" size="sm" onClick={addCharacter} icon={<Plus size={12} />}>
              Add
            </Button>
          </div>
        </div>

        <div className="glass-light rounded-xl p-4 space-y-3">
          <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">
            Required Items ({items.length})
          </h4>
          <div className="space-y-1">
            {items.map((item, i) => (
              <div key={i} className="flex items-center justify-between px-2 py-1.5 rounded bg-white/5">
                <span className="text-xs text-white">{item}</span>
                <button onClick={() => removeItem(i)} className="text-red-400 hover:text-red-300">
                  <X size={12} />
                </button>
              </div>
            ))}
          </div>
          <div className="flex gap-2">
            <Input
              value={newItem}
              onChange={(e) => setNewItem(e.target.value)}
              placeholder="Item name..."
              className="flex-1"
            />
            <Button variant="secondary" size="sm" onClick={addItem} icon={<Plus size={12} />}>
              Add
            </Button>
          </div>
        </div>

        <div className="flex justify-end">
          <Button onClick={handleSave} disabled={!name.trim() || saving}>
            {saving ? 'Saving...' : mode === 'edit' ? 'Save Changes' : 'Create Building'}
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
          {buildings.map((b) => {
            const perms = readPermissions(b);
            const permCount = Object.keys(perms.groups).length + perms.characters.length + perms.items.length;
            return (
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
                  <span>{permCount > 0 ? `${permCount} permission rule${permCount === 1 ? '' : 's'}` : 'no permissions set'}</span>
                  <span>by {b.createdBy}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
