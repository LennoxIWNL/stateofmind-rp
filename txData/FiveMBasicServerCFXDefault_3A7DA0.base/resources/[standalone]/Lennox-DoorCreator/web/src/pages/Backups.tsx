import { useState, useEffect } from 'react';
import { Database, Plus, RotateCcw, Trash2, Eye } from 'lucide-react';
import type { Backup, ApiResponse, NotificationType } from '../types';
import Button from '../components/common/Button';
import Badge from '../components/common/Badge';
import { fetchNui } from '../utils/nui';
import { formatDate } from '../utils/misc';

interface BackupsProps {
  refresh: () => Promise<void>;
  addNotification: (type: NotificationType, msg: string) => void;
  showConfirm: (title: string, msg: string, onConfirm: () => void) => void;
}

export default function Backups({ refresh, addNotification, showConfirm }: BackupsProps) {
  const [backups, setBackups] = useState<Backup[]>([]);
  const [loading, setLoading] = useState(true);

  const loadBackups = async () => {
    setLoading(true);
    const result = await fetchNui<Backup[]>('getBackups');
    setBackups(result || []);
    setLoading(false);
  };

  useEffect(() => { loadBackups(); }, []);

  const createBackup = async () => {
    const result = await fetchNui<ApiResponse>('createBackup');
    if (result.ok) {
      addNotification('success', 'Backup created');
      await loadBackups();
    } else {
      addNotification('error', result.message || 'Backup failed');
    }
  };

  const restoreBackup = (b: Backup) => {
    showConfirm(
      'Restore Backup',
      `This will REPLACE all current doors with the backup "${b.name}" (${b.door_count} doors). A pre-restore backup will be created automatically. Continue?`,
      async () => {
        const result = await fetchNui<ApiResponse>('restoreBackup', { id: b.id });
        if (result.ok) {
          addNotification('success', result.message || 'Backup restored');
          await refresh();
          await loadBackups();
        } else {
          addNotification('error', result.message || 'Restore failed');
        }
      }
    );
  };

  const deleteBackup = (b: Backup) => {
    showConfirm('Delete Backup', `Delete backup "${b.name}"? This cannot be undone.`, async () => {
      const result = await fetchNui<ApiResponse>('deleteBackup', { id: b.id });
      if (result.ok) {
        addNotification('success', 'Backup deleted');
        await loadBackups();
      }
    });
  };

  return (
    <div className="space-y-5 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-white">Backups</h2>
          <p className="text-xs text-gray-500 mt-0.5">Manage door data backups and restore points</p>
        </div>
        <Button onClick={createBackup} icon={<Plus size={14} />}>
          Create Backup
        </Button>
      </div>

      {loading ? (
        <div className="space-y-2">
          {[1, 2, 3].map((i) => (
            <div key={i} className="skeleton h-16 rounded-xl" />
          ))}
        </div>
      ) : backups.length === 0 ? (
        <div className="flex items-center justify-center py-16 text-gray-600">
          <div className="text-center">
            <Database size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">No backups available</p>
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          {backups.map((b) => (
            <div key={b.id} className="glass-light rounded-xl p-4 flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <h4 className="text-sm font-medium text-white">{b.name}</h4>
                  <Badge text={b.type} variant={b.type === 'auto' ? 'neutral' : 'primary'} />
                </div>
                <div className="flex items-center gap-3 text-[10px] text-gray-500">
                  <span>{b.door_count} doors</span>
                  <span>{b.building_count} buildings</span>
                  <span>by {b.created_by}</span>
                  <span>{formatDate(b.created_at)}</span>
                </div>
              </div>
              <div className="flex gap-1">
                <button onClick={() => restoreBackup(b)} className="p-2 rounded hover:bg-emerald-500/10 text-gray-500 hover:text-emerald-400" title="Restore">
                  <RotateCcw size={14} />
                </button>
                <button onClick={() => deleteBackup(b)} className="p-2 rounded hover:bg-red-500/10 text-gray-500 hover:text-red-400" title="Delete">
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
