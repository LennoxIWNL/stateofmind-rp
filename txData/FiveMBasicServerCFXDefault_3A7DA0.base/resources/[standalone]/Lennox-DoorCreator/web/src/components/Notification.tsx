import { CheckCircle2, XCircle, AlertCircle, Info } from 'lucide-react';
import type { Notification as NotifType } from '../types';

const ICONS = {
  success: CheckCircle2,
  error: XCircle,
  warning: AlertCircle,
  info: Info,
};

const COLORS = {
  success: 'border-emerald-500/30 bg-emerald-500/10 text-emerald-300',
  error: 'border-red-500/30 bg-red-500/10 text-red-300',
  warning: 'border-amber-500/30 bg-amber-500/10 text-amber-300',
  info: 'border-blue-500/30 bg-blue-500/10 text-blue-300',
};

export default function NotificationContainer({
  notifications,
}: {
  notifications: NotifType[];
}) {
  return (
    <div className="fixed top-4 right-4 z-50 space-y-2 pointer-events-none">
      {notifications.map((n) => {
        const Icon = ICONS[n.type];
        return (
          <div
            key={n.id}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-lg border text-sm animate-slide-in pointer-events-auto ${COLORS[n.type]}`}
            style={{ backdropFilter: 'blur(12px)' }}
          >
            <Icon size={16} />
            <span>{n.message}</span>
          </div>
        );
      })}
    </div>
  );
}
