import { useState, useEffect } from 'react';
import { ScrollText, Search, ChevronLeft, ChevronRight } from 'lucide-react';
import type { LogEntry } from '../types';
import Badge from '../components/common/Badge';
import { fetchNui } from '../utils/nui';
import { formatDate } from '../utils/misc';

const ACTION_COLORS: Record<string, 'primary' | 'success' | 'warning' | 'danger' | 'neutral'> = {
  create: 'success',
  edit: 'primary',
  delete: 'danger',
  bulk_create: 'success',
  import: 'warning',
  restore: 'warning',
  permission_change: 'primary',
  building_create: 'success',
  building_edit: 'primary',
  building_delete: 'danger',
  template_create: 'success',
  template_delete: 'danger',
  backup_create: 'neutral',
  backup_restore: 'warning',
};

export default function Logs() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(true);
  const [actionFilter, setActionFilter] = useState('');
  const [playerFilter, setPlayerFilter] = useState('');

  const loadLogs = async (newOffset = 0) => {
    setLoading(true);
    const result = await fetchNui<{ logs: LogEntry[]; total: number }>('getLogs', {
      action: actionFilter,
      player: playerFilter,
      offset: newOffset,
      limit: 50,
    });
    if (result) {
      setLogs(result.logs || []);
      setTotal(result.total || 0);
      setOffset(newOffset);
    }
    setLoading(false);
  };

  useEffect(() => { loadLogs(0); }, [actionFilter, playerFilter]);

  const pageCount = Math.ceil(total / 50);
  const currentPage = Math.floor(offset / 50) + 1;

  return (
    <div className="space-y-5 animate-fade-in">
      <div>
        <h2 className="text-lg font-semibold text-white">Activity Logs</h2>
        <p className="text-xs text-gray-500 mt-0.5">Track all door management actions</p>
      </div>

      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500" />
          <input
            type="text"
            placeholder="Filter by player..."
            value={playerFilter}
            onChange={(e) => setPlayerFilter(e.target.value)}
            className="input-field pl-9"
          />
        </div>
        <select
          value={actionFilter}
          onChange={(e) => setActionFilter(e.target.value)}
          className="input-field w-48"
        >
          <option value="">All actions</option>
          <option value="create">Create</option>
          <option value="edit">Edit</option>
          <option value="delete">Delete</option>
          <option value="bulk_create">Bulk Create</option>
          <option value="import">Import</option>
          <option value="restore">Restore</option>
          <option value="permission_change">Permission Change</option>
          <option value="building_create">Building Create</option>
          <option value="building_delete">Building Delete</option>
        </select>
      </div>

      {loading ? (
        <div className="space-y-2">
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="skeleton h-12 rounded-lg" />
          ))}
        </div>
      ) : logs.length === 0 ? (
        <div className="flex items-center justify-center py-16 text-gray-600">
          <div className="text-center">
            <ScrollText size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">No logs found</p>
          </div>
        </div>
      ) : (
        <>
          <div className="space-y-1">
            {logs.map((log) => (
              <div key={log.id} className="flex items-center justify-between px-3 py-2.5 rounded-lg hover:bg-white/5 transition-colors">
                <div className="flex items-center gap-3">
                  <Badge text={log.action} variant={ACTION_COLORS[log.action] || 'neutral'} />
                  <div>
                    <span className="text-xs text-white">{log.player_name || 'System'}</span>
                    {log.door_id && (
                      <span className="text-[10px] text-gray-500 ml-2">Door #{log.door_id}</span>
                    )}
                    {log.building_id && (
                      <span className="text-[10px] text-gray-500 ml-2">Building #{log.building_id}</span>
                    )}
                  </div>
                </div>
                <span className="text-[10px] text-gray-600">{formatDate(log.created_at)}</span>
              </div>
            ))}
          </div>

          {pageCount > 1 && (
            <div className="flex items-center justify-center gap-3 pt-2">
              <button
                onClick={() => loadLogs(Math.max(0, offset - 50))}
                disabled={offset === 0}
                className="p-1.5 rounded hover:bg-white/5 text-gray-500 disabled:opacity-30"
              >
                <ChevronLeft size={14} />
              </button>
              <span className="text-xs text-gray-500">
                Page {currentPage} of {pageCount}
              </span>
              <button
                onClick={() => loadLogs(offset + 50)}
                disabled={currentPage >= pageCount}
                className="p-1.5 rounded hover:bg-white/5 text-gray-500 disabled:opacity-30"
              >
                <ChevronRight size={14} />
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
