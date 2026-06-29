const isEnvBrowser = !(window as unknown as Record<string, unknown>).invokeNative;

export async function fetchNui<T = unknown>(
  eventName: string,
  data?: unknown
): Promise<T> {
  if (isEnvBrowser) {
    return new Promise((resolve) => {
      setTimeout(() => resolve({} as T), 200);
    });
  }

  const resourceName = (window as unknown as Record<string, unknown>).GetParentResourceName
    ? ((window as unknown as Record<string, unknown>).GetParentResourceName as () => string)()
    : 'Lennox-DoorCreator';

  const resp = await fetch(`https://${resourceName}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data ?? {}),
  });

  return resp.json() as Promise<T>;
}

export function isInGame(): boolean {
  return !isEnvBrowser;
}
