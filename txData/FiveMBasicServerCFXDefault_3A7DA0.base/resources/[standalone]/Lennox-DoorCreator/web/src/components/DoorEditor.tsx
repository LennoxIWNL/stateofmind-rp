import { useState, useEffect } from 'react';
import { Save, Trash2, X, Plus } from 'lucide-react';
import type { DoorData, DoorFull, JobInfo, ApiResponse } from '../types';
import Button from './common/Button';
import Input from './common/Input';
import Toggle from './common/Toggle';
import Slider from './common/Slider';
import { fetchNui } from '../utils/nui';

interface DoorEditorProps {
  door?: DoorFull | null;
  prefill?: Partial<DoorData> & { modelName?: string; category?: string; isDouble?: boolean };
  jobs: JobInfo[];
  gangs: JobInfo[];
  onSave: (result: ApiResponse) => void;
  onDelete?: () => void;
  onCancel: () => void;
}

export default function DoorEditor({ door, prefill, jobs, gangs, onSave, onDelete, onCancel }: DoorEditorProps) {
  const isEdit = !!door;
  const initial = door?.data || prefill || ({} as Partial<DoorData>);

  const [name, setName] = useState(door?.name || '');
  const [state, setState] = useState(initial.state ?? 1);
  const [lockpick, setLockpick] = useState(initial.lockpick ?? false);
  const [hideUi, setHideUi] = useState(initial.hideUi ?? false);
  const [holdOpen, setHoldOpen] = useState(initial.holdOpen ?? false);
  const [autolock, setAutolock] = useState(initial.autolock ?? 0);
  const [maxDistance, setMaxDistance] = useState(initial.maxDistance ?? 2.0);
  const [doorRate, setDoorRate] = useState(initial.doorRate ?? 1.0);
  const [lockSound, setLockSound] = useState(initial.lockSound ?? 'door-bolt-4');
  const [unlockSound, setUnlockSound] = useState(initial.unlockSound ?? 'door-bolt-4');
  const [passcode, setPasscode] = useState(initial.passcode || '');
  const [groups, setGroups] = useState<Record<string, number>>(initial.groups || {});
  const [characters, setCharacters] = useState<string[]>(initial.characters || []);
  const [items, setItems] = useState<string[]>(initial.items || []);
  const [lockpickDifficulty, setLockpickDifficulty] = useState<string[]>(
    initial.lockpickDifficulty || ['easy', 'easy', 'medium']
  );
  const [saving, setSaving] = useState(false);

  const [newGroupName, setNewGroupName] = useState('');
  const [newGroupGrade, setNewGroupGrade] = useState(0);
  const [newCharacter, setNewCharacter] = useState('');
  const [newItem, setNewItem] = useState('');

  const handleSave = async () => {
    if (!name.trim()) return;
    setSaving(true);

    const data: Record<string, unknown> = {
      name: name.trim(),
      model: initial.model,
      coords: initial.coords,
      heading: initial.heading,
      doors: (initial as DoorData).doors || null,
      state,
      lockpick,
      hideUi,
      holdOpen,
      auto: autolock > 0,
      autolock,
      maxDistance,
      doorRate,
      lockSound,
      unlockSound,
      passcode: passcode || null,
      groups,
      characters,
      items,
      lockpickDifficulty: lockpick ? lockpickDifficulty : null,
    };

    if (isEdit) {
      (data as Record<string, unknown>).id = door!.id;
    }

    const result = await fetchNui<ApiResponse>(isEdit ? 'editDoor' : 'createDoor', data);
    setSaving(false);
    onSave(result);
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

  const allJobs = [...jobs, ...gangs];

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-white">{isEdit ? 'Edit Door' : 'Create Door'}</h3>
        <Button variant="ghost" onClick={onCancel} icon={<X size={14} />}>
          Cancel
        </Button>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="col-span-2">
          <Input
            label="Door Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. MRPD Front Door"
            maxLength={50}
          />
        </div>

        {initial.model && (
          <>
            <Input label="Model Hash" value={String(initial.model)} disabled />
            <Input label="Heading" value={String(initial.heading?.toFixed(2) || 0)} disabled />
          </>
        )}

        {initial.coords && (
          <div className="col-span-2">
            <Input
              label="Coordinates"
              value={`${initial.coords.x.toFixed(3)}, ${initial.coords.y.toFixed(3)}, ${initial.coords.z.toFixed(3)}`}
              disabled
            />
          </div>
        )}
      </div>

      <div className="glass-light rounded-xl p-4 space-y-3">
        <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">Lock Settings</h4>
        <Toggle label="Locked" checked={state === 1} onChange={(v) => setState(v ? 1 : 0)} />
        <Toggle label="Lockpickable" checked={lockpick} onChange={setLockpick} />
        <Toggle label="Hide UI" checked={hideUi} onChange={setHideUi} />
        <Toggle label="Hold Open" checked={holdOpen} onChange={setHoldOpen} />
        <Slider label="Auto-lock (seconds)" value={autolock} min={0} max={300} step={5} onChange={setAutolock} unit="s" />
        <Slider label="Max Distance" value={maxDistance} min={0.5} max={10} step={0.5} onChange={setMaxDistance} unit="m" />
        <Slider label="Door Rate" value={doorRate} min={0.1} max={5} step={0.1} onChange={setDoorRate} />
      </div>

      <div className="glass-light rounded-xl p-4 space-y-3">
        <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">Sounds</h4>
        <Input label="Lock Sound" value={lockSound} onChange={(e) => setLockSound(e.target.value)} />
        <Input label="Unlock Sound" value={unlockSound} onChange={(e) => setUnlockSound(e.target.value)} />
      </div>

      <div className="glass-light rounded-xl p-4 space-y-3">
        <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">Passcode</h4>
        <Input label="Passcode" value={passcode} onChange={(e) => setPasscode(e.target.value)} placeholder="Leave empty for none" />
      </div>

      <div className="glass-light rounded-xl p-4 space-y-3">
        <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">
          Job/Gang Permissions ({Object.keys(groups).length})
        </h4>
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

      {lockpick && (
        <div className="glass-light rounded-xl p-4 space-y-3">
          <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">Lockpick Difficulty</h4>
          <div className="flex gap-2 flex-wrap">
            {lockpickDifficulty.map((d, i) => (
              <select
                key={i}
                value={d}
                onChange={(e) => {
                  const arr = [...lockpickDifficulty];
                  arr[i] = e.target.value;
                  setLockpickDifficulty(arr);
                }}
                className="input-field w-24"
              >
                <option value="easy">Easy</option>
                <option value="medium">Medium</option>
                <option value="hard">Hard</option>
              </select>
            ))}
            <Button variant="ghost" size="sm" onClick={() => setLockpickDifficulty([...lockpickDifficulty, 'easy'])}>
              +
            </Button>
          </div>
        </div>
      )}

      <div className="flex justify-between pt-2">
        {isEdit && onDelete ? (
          <Button variant="danger" icon={<Trash2 size={14} />} onClick={onDelete}>
            Delete
          </Button>
        ) : (
          <div />
        )}
        <Button onClick={handleSave} disabled={!name.trim() || saving} icon={<Save size={14} />}>
          {saving ? 'Saving...' : isEdit ? 'Save Changes' : 'Create Door'}
        </Button>
      </div>
    </div>
  );
}
