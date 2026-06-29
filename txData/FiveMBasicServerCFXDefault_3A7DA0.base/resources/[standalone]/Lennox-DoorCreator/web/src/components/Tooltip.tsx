import { useState } from 'react';
import type { ReactNode } from 'react';

interface TooltipProps {
  text: string;
  children: ReactNode;
}

export default function Tooltip({ text, children }: TooltipProps) {
  const [show, setShow] = useState(false);

  return (
    <div className="relative inline-flex" onMouseEnter={() => setShow(true)} onMouseLeave={() => setShow(false)}>
      {children}
      {show && (
        <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-2 py-1 rounded bg-gray-900 text-[10px] text-gray-300 whitespace-nowrap z-50 animate-fade-in pointer-events-none">
          {text}
        </div>
      )}
    </div>
  );
}
