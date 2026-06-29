import { useState, useCallback } from 'react';
import type { DoorListItem, Building, InitData, JobInfo } from '../types';
import { fetchNui } from '../utils/nui';

export function useDoorData() {
  const [doors, setDoors] = useState<DoorListItem[]>([]);
  const [buildings, setBuildings] = useState<Building[]>([]);
  const [jobs, setJobs] = useState<JobInfo[]>([]);
  const [gangs, setGangs] = useState<JobInfo[]>([]);
  const [framework, setFramework] = useState('');
  const [loading, setLoading] = useState(false);

  const initialize = useCallback((data: InitData) => {
    setDoors(data.doors || []);
    setBuildings(data.buildings || []);
    setJobs(data.jobs || []);
    setGangs(data.gangs || []);
    setFramework(data.framework || '');
  }, []);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const data = await fetchNui<InitData>('refreshData');
      if (data) {
        initialize(data);
      }
    } finally {
      setLoading(false);
    }
  }, [initialize]);

  return {
    doors,
    buildings,
    jobs,
    gangs,
    framework,
    loading,
    setDoors,
    setBuildings,
    initialize,
    refresh,
  };
}
