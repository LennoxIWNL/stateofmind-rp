import { useState, useEffect } from 'react';
import { FileBox, Download, Upload, Trash2, Copy, Plus } from 'lucide-react';
import type { Template, ApiResponse, NotificationType } from '../types';
import Button from '../components/common/Button';
import Input from '../components/common/Input';
import Badge from '../components/common/Badge';
import { fetchNui } from '../utils/nui';
import { formatDate } from '../utils/misc';

interface TemplatesProps {
  addNotification: (type: NotificationType, msg: string) => void;
}

export default function Templates({ addNotification }: TemplatesProps) {
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [importStr, setImportStr] = useState('');
  const [showImport, setShowImport] = useState(false);

  const loadTemplates = async () => {
    setLoading(true);
    const result = await fetchNui<Template[]>('getTemplates');
    setTemplates(result || []);
    setLoading(false);
  };

  useEffect(() => { loadTemplates(); }, []);

  const handleExport = async (id: number) => {
    const code = await fetchNui<string>('exportTemplate', { id });
    if (code) {
      navigator.clipboard.writeText(code).catch(() => {});
      addNotification('success', 'Template code copied to clipboard');
    }
  };

  const handleImport = async () => {
    if (!importStr.trim()) return;
    const result = await fetchNui<ApiResponse>('importTemplate', { importStr: importStr.trim() });
    if (result.ok) {
      addNotification('success', 'Template imported');
      setImportStr('');
      setShowImport(false);
      await loadTemplates();
    } else {
      addNotification('error', result.message || 'Import failed');
    }
  };

  const handleDelete = async (id: number) => {
    const result = await fetchNui<ApiResponse>('deleteTemplate', { id });
    if (result.ok) {
      addNotification('success', 'Template deleted');
      await loadTemplates();
    }
  };

  return (
    <div className="space-y-5 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-white">Templates</h2>
          <p className="text-xs text-gray-500 mt-0.5">Save and share door configurations</p>
        </div>
        <Button variant="secondary" onClick={() => setShowImport(!showImport)} icon={<Upload size={14} />}>
          Import Template
        </Button>
      </div>

      {showImport && (
        <div className="glass-light rounded-xl p-4 space-y-3">
          <h3 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">Import Template</h3>
          <textarea
            value={importStr}
            onChange={(e) => setImportStr(e.target.value)}
            placeholder="Paste template code here..."
            className="input-field h-24 resize-none font-mono text-xs"
          />
          <div className="flex justify-end gap-2">
            <Button variant="secondary" size="sm" onClick={() => setShowImport(false)}>
              Cancel
            </Button>
            <Button size="sm" onClick={handleImport} disabled={!importStr.trim()}>
              Import
            </Button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="space-y-2">
          {[1, 2, 3].map((i) => (
            <div key={i} className="skeleton h-20 rounded-xl" />
          ))}
        </div>
      ) : templates.length === 0 ? (
        <div className="flex items-center justify-center py-16 text-gray-600">
          <div className="text-center">
            <FileBox size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">No templates saved yet</p>
            <p className="text-xs mt-1 text-gray-700">Save a door configuration as a template to reuse it</p>
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          {templates.map((t) => (
            <div key={t.id} className="glass-light rounded-xl p-4 flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <h4 className="text-sm font-medium text-white">{t.name}</h4>
                  <Badge text={t.type} variant="primary" />
                </div>
                {t.description && <p className="text-xs text-gray-500">{t.description}</p>}
                <div className="flex items-center gap-3 text-[10px] text-gray-600 mt-1">
                  <span>by {t.author}</span>
                  <span>v{t.version}</span>
                  <span>{formatDate(t.created_at)}</span>
                  {t.export_code && (
                    <span className="font-mono text-gray-500">{t.export_code}</span>
                  )}
                </div>
              </div>
              <div className="flex gap-1">
                <button onClick={() => handleExport(t.id)} className="p-2 rounded hover:bg-white/5 text-gray-500 hover:text-gray-300" title="Export">
                  <Copy size={14} />
                </button>
                <button onClick={() => handleDelete(t.id)} className="p-2 rounded hover:bg-red-500/10 text-gray-500 hover:text-red-400" title="Delete">
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
