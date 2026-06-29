import { createContext, useContext, useState, useCallback, useEffect } from 'react';
import type { ReactNode } from 'react';
import { generateThemeVars } from '../utils/misc';

interface ThemeContextType {
  themeColor: string;
  setThemeColor: (hex: string) => void;
}

const ThemeContext = createContext<ThemeContextType>({
  themeColor: '#6366f1',
  setThemeColor: () => {},
});

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [themeColor, setThemeColorState] = useState('#6366f1');

  const applyTheme = useCallback((hex: string) => {
    const vars = generateThemeVars(hex);
    const root = document.documentElement;
    Object.entries(vars).forEach(([key, value]) => {
      root.style.setProperty(key, value);
    });
  }, []);

  const setThemeColor = useCallback(
    (hex: string) => {
      setThemeColorState(hex);
      applyTheme(hex);
    },
    [applyTheme]
  );

  useEffect(() => {
    applyTheme(themeColor);
  }, []);

  return (
    <ThemeContext.Provider value={{ themeColor, setThemeColor }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  return useContext(ThemeContext);
}
