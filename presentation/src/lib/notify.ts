type Listener = (message: string) => void;

const listeners = new Set<Listener>();

export function onNotice(fn: Listener): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function notify(message: string): void {
  listeners.forEach((fn) => fn(message));
}

export async function run(action: () => Promise<unknown>): Promise<boolean> {
  try {
    await action();
    return true;
  } catch (e) {
    notify(e instanceof Error ? e.message : String(e));
    return false;
  }
}
