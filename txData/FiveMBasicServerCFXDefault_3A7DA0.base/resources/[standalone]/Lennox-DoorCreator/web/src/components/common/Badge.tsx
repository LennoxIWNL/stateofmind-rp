import { cn } from '../../utils/misc';

interface BadgeProps {
  text: string;
  variant?: 'primary' | 'success' | 'warning' | 'danger' | 'neutral';
}

const variants: Record<string, string> = {
  primary: 'text-indigo-300 bg-indigo-500/15',
  success: 'text-emerald-300 bg-emerald-500/15',
  warning: 'text-amber-300 bg-amber-500/15',
  danger: 'text-red-300 bg-red-500/15',
  neutral: 'text-gray-300 bg-gray-500/15',
};

export default function Badge({ text, variant = 'neutral' }: BadgeProps) {
  return (
    <span className={cn('inline-flex items-center px-2 py-0.5 rounded text-[10px] font-medium uppercase tracking-wider', variants[variant])}>
      {text}
    </span>
  );
}
