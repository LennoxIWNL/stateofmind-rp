import type { InputHTMLAttributes } from 'react';
import { cn } from '../../utils/misc';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export default function Input({ label, error, className, ...props }: InputProps) {
  return (
    <div className="space-y-1">
      {label && <label className="text-xs text-gray-400 font-medium">{label}</label>}
      <input className={cn('input-field', error && 'border-red-500/50', className)} {...props} />
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  );
}
