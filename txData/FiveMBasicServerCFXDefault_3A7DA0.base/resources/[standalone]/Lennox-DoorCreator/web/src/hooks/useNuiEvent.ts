import { useEffect, useRef } from 'react';

interface NuiMessage<T = unknown> {
  type: string;
  data: T;
}

export function useNuiEvent<T = unknown>(
  action: string,
  handler: (data: T) => void
) {
  const savedHandler = useRef(handler);

  useEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const eventListener = (event: MessageEvent<NuiMessage<T>>) => {
      const { type, data } = event.data;
      if (type === action) {
        savedHandler.current(data);
      }
    };

    window.addEventListener('message', eventListener);
    return () => window.removeEventListener('message', eventListener);
  }, [action]);
}
