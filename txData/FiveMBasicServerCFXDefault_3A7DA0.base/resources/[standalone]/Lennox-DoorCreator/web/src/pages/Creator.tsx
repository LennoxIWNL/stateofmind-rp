import { useState, useCallback } from 'react';
import { Crosshair } from 'lucide-react';
import type { DoorListItem, DoorFull, DoorData, JobInfo, ApiResponse, NotificationType } from '../types';
import DoorList from '../components/DoorList';
import DoorEditor from '../components/DoorEditor';
import Button from '../components/common/Button';
import { fetchNui } from '../utils/nui';

interface CreatorProps {
  doors: DoorListItem[];
  jobs: JobInfo[];
  gangs: JobInfo[];
  refresh: () => Promise<void>;
  addNotification: (type: NotificationType, msg: string) => void;
  showConfirm: (title: string, msg: string, onConfirm: () => void) => void;
  editorData: (Partial<DoorData> & { modelName?: string; category?: string; isDouble?: boolean }) | null;
  setEditorData: (data: (Partial<DoorData> & { modelName?: string; category?: string; isDouble?: boolean }) | null) => void;
}

export default function Creator({ doors, jobs, gangs, refresh, addNotification, showConfirm, editorData, setEditorData }: CreatorProps) {
  const [selectedDoor, setSelectedDoor] = useState<DoorFull | null>(null);
  const [mode, setMode] = useState<'list' | 'create' | 'edit'>('list');

  const startCreator = () => {
    fetchNui('startCreator');
    setMode('create');
  };

  const handleSelectDoor = useCallback(async (door: DoorListItem) => {
    const full = await fetchNui<DoorFull>('getDoor', { id: door.id });
    if (full) {
      setSelectedDoor(full);
      setMode('edit');
    }
  }, []);

  const handleSave = useCallback(
    async (result: ApiResponse) => {
      if (result.ok) {
        addNotification('success', result.message || 'Door saved');
        setMode('list');
        setSelectedDoor(null);
        setEditorData(null);
        await refresh();
      } else {
        addNotification('error', result.message || 'Save failed');
      }
    },
    [addNotification, refresh, setEditorData]
  );

  const handleDelete = useCallback(() => {
    if (!selectedDoor) return;
    showConfirm(
      'Delete Door',
      `Are you sure you want to delete "${selectedDoor.name}" (#${selectedDoor.id})? This cannot be undone.`,
      async () => {
        const result = await fetchNui<ApiResponse>('deleteDoor', { id: selectedDoor.id });
        if (result.ok) {
          addNotification('success', result.message || 'Door deleted');
          setMode('list');
          setSelectedDoor(null);
          await refresh();
        } else {
          addNotification('error', result.message || 'Delete failed');
        }
      }
    );
  }, [selectedDoor, showConfirm, addNotification, refresh]);

  if (editorData && mode !== 'edit') {
    return (
      <div className="animate-fade-in">
        <DoorEditor
          prefill={editorData}
          jobs={jobs}
          gangs={gangs}
          onSave={handleSave}
          onCancel={() => {
            setEditorData(null);
            setMode('list');
          }}
        />
      </div>
    );
  }

  if (mode === 'edit' && selectedDoor) {
    return (
      <div className="animate-fade-in">
        <DoorEditor
          door={selectedDoor}
          jobs={jobs}
          gangs={gangs}
          onSave={handleSave}
          onDelete={handleDelete}
          onCancel={() => {
            setMode('list');
            setSelectedDoor(null);
          }}
        />
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full animate-fade-in">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="text-lg font-semibold text-white">Door Creator</h2>
          <p className="text-xs text-gray-500 mt-0.5">Create new doors or edit existing ones</p>
        </div>
        <Button onClick={startCreator} icon={<Crosshair size={14} />}>
          Select Door
        </Button>
      </div>

      <div className="flex-1 min-h-0">
        <DoorList doors={doors} onSelect={handleSelectDoor} selectedId={selectedDoor?.id} />
      </div>
    </div>
  );
}
