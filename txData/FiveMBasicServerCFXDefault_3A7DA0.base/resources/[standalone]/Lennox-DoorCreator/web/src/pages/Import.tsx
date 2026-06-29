import { useState } from 'react';
import { Download, Check, AlertTriangle, XCircle, ArrowRight } from 'lucide-react';
import type { DetectedDoor, ApiResponse, NotificationType } from '../types';
import Button from '../components/common/Button';
import Badge from '../components/common/Badge';
import { fetchNui } from '../utils/nui';

interface ImportProps {
  refresh: () => Promise<void>;
  addNotification: (type: NotificationType, msg: string) => void;
}

interface ImportDoor {
  name: string;
  data: Record<string, unknown>;
  valid: boolean;
  warnings: string[];
  source: string;
}

export default function Import({ refresh, addNotification }: ImportProps) {
  const [step, setStep] = useState<'source' | 'content' | 'preview' | 'result'>('source');
  const [source, setSource] = useState('');
  const [content, setContent] = useState('');
  const [doors, setDoors] = useState<ImportDoor[]>([]);
  const [importing, setImporting] = useState(false);
  const [result, setResult] = useState<{ success: number; failed: number } | null>(null);

  const sources = [
    { id: 'ox_doorlock', name: 'ox_doorlock', desc: 'Manage existing doors from database' },
    { id: 'qb-doorlock', name: 'qb-doorlock', desc: 'Import from qb-doorlock config files' },
    { id: 'nui_doorlock', name: 'nui_doorlock', desc: 'Import from nui_doorlock config' },
    { id: 'custom_json', name: 'Custom JSON', desc: 'Import from a JSON file/array' },
  ];

  const selectSource = (s: string) => {
    setSource(s);
    if (s === 'ox_doorlock') {
      loadPreview(s, '');
    } else {
      setStep('content');
    }
  };

  const loadPreview = async (src: string, cnt: string) => {
    const result = await fetchNui<ImportDoor[] | { error: string }>('importPreview', { source: src, content: cnt });
    if (result && 'error' in result) {
      addNotification('error', (result as { error: string }).error);
      return;
    }
    setDoors((result as ImportDoor[]) || []);
    setStep('preview');
  };

  const executeImport = async () => {
    const validDoors = doors.filter((d) => d.valid !== false);
    if (validDoors.length === 0) {
      addNotification('error', 'No valid doors to import');
      return;
    }

    setImporting(true);
    const res = await fetchNui<ApiResponse & { success?: number; failed?: number }>('importExecute', { doors: validDoors });
    setImporting(false);

    if (res.ok) {
      setResult({ success: res.success || 0, failed: res.failed || 0 });
      setStep('result');
      await refresh();
    } else {
      addNotification('error', res.message || 'Import failed');
    }
  };

  if (step === 'result' && result) {
    return (
      <div className="space-y-5 animate-fade-in">
        <div className="flex items-center justify-center py-16">
          <div className="text-center">
            <Check size={48} className="mx-auto mb-4 text-emerald-400" />
            <h2 className="text-lg font-semibold text-white mb-2">Import Complete</h2>
            <p className="text-sm text-gray-400">
              {result.success} doors imported successfully, {result.failed} failed
            </p>
            <Button className="mt-4" onClick={() => { setStep('source'); setSource(''); setDoors([]); setResult(null); }}>
              Import More
            </Button>
          </div>
        </div>
      </div>
    );
  }

  if (step === 'preview') {
    const valid = doors.filter((d) => d.valid !== false).length;
    const invalid = doors.length - valid;

    return (
      <div className="space-y-5 animate-fade-in">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-white">Import Preview</h2>
            <p className="text-xs text-gray-500 mt-0.5">
              {valid} valid, {invalid} invalid of {doors.length} total
            </p>
          </div>
          <div className="flex gap-2">
            <Button variant="secondary" onClick={() => setStep('source')}>
              Back
            </Button>
            <Button onClick={executeImport} disabled={importing || valid === 0}>
              {importing ? 'Importing...' : `Import ${valid} Doors`}
            </Button>
          </div>
        </div>

        <div className="max-h-[60vh] overflow-y-auto space-y-1">
          {doors.map((d, i) => (
            <div
              key={i}
              className={`flex items-center justify-between px-3 py-2 rounded-lg ${
                d.valid !== false ? 'bg-white/5' : 'bg-red-500/5'
              }`}
            >
              <div className="flex items-center gap-2">
                {d.valid !== false ? (
                  d.warnings?.length > 0 ? (
                    <AlertTriangle size={14} className="text-amber-400 flex-shrink-0" />
                  ) : (
                    <Check size={14} className="text-emerald-400 flex-shrink-0" />
                  )
                ) : (
                  <XCircle size={14} className="text-red-400 flex-shrink-0" />
                )}
                <span className="text-xs text-white">{d.name}</span>
                <Badge text={d.source} variant="neutral" />
              </div>
              {d.warnings?.length > 0 && (
                <span className="text-[10px] text-amber-400">{d.warnings.join(', ')}</span>
              )}
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (step === 'content') {
    return (
      <div className="space-y-5 animate-fade-in">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">Paste Config Content</h2>
          <Button variant="secondary" onClick={() => setStep('source')}>Back</Button>
        </div>

        <p className="text-xs text-gray-400">
          Paste the contents of your {source} config file below:
        </p>

        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder={source === 'custom_json' ? '[\n  { "name": "...", "model": 123, ... }\n]' : '-- Paste config file contents here...'}
          className="input-field h-64 resize-none font-mono text-xs"
        />

        <div className="flex justify-end">
          <Button onClick={() => loadPreview(source, content)} disabled={!content.trim()} icon={<ArrowRight size={14} />}>
            Preview Import
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-5 animate-fade-in">
      <div>
        <h2 className="text-lg font-semibold text-white">Import Doors</h2>
        <p className="text-xs text-gray-500 mt-0.5">Import doors from other doorlock systems</p>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {sources.map((s) => (
          <button
            key={s.id}
            onClick={() => selectSource(s.id)}
            className="glass-light rounded-xl p-4 text-left hover:bg-white/5 transition-all group"
          >
            <div className="flex items-center gap-3 mb-2">
              <Download size={18} className="text-gray-500 group-hover:text-primary transition-colors" />
              <h3 className="text-sm font-medium text-white">{s.name}</h3>
            </div>
            <p className="text-xs text-gray-500">{s.desc}</p>
          </button>
        ))}
      </div>
    </div>
  );
}
