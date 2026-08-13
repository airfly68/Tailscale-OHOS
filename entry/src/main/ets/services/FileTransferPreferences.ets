import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export type FileTransferTransport = 'tailsend' | 'localsend';

export interface LocalSendPortOverride {
  peerKey: string;
  port: number;
}

const STORE_NAME: string = 'mesh_arc_file_transfer';
const PREFERRED_TRANSPORT_KEY: string = 'preferred_transport';
const LOCAL_SEND_PORT_OVERRIDES_KEY: string = 'localsend_port_overrides';

/** Persists the user's default MeshSend transport choice. */
export class FileTransferPreferences {
  static async load(context: common.Context): Promise<FileTransferTransport | undefined> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME);
      const value: string = store.getSync(PREFERRED_TRANSPORT_KEY, '') as string;
      return FileTransferPreferences.normalize(value);
    } catch (_error) {
      return undefined;
    }
  }

  static async save(context: common.Context, transport: FileTransferTransport): Promise<void> {
    const store = await preferences.getPreferences(context, STORE_NAME);
    store.putSync(PREFERRED_TRANSPORT_KEY, transport);
    await store.flush();
  }

  static async loadLocalSendPortOverrides(context: common.Context): Promise<LocalSendPortOverride[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME);
      const value: string = store.getSync(LOCAL_SEND_PORT_OVERRIDES_KEY, '[]') as string;
      return FileTransferPreferences.normalizePortOverrides(value);
    } catch (_error) {
      return [];
    }
  }

  static async saveLocalSendPortOverride(context: common.Context, peerKey: string,
    port: number): Promise<void> {
    const normalizedKey: string = peerKey.trim();
    if (normalizedKey.length === 0 || !Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('Invalid LocalSend port override.');
    }
    const store = await preferences.getPreferences(context, STORE_NAME);
    const value: string = store.getSync(LOCAL_SEND_PORT_OVERRIDES_KEY, '[]') as string;
    const overrides: LocalSendPortOverride[] = FileTransferPreferences.normalizePortOverrides(value)
      .filter((item: LocalSendPortOverride) => item.peerKey !== normalizedKey);
    overrides.push({ peerKey: normalizedKey, port: port });
    store.putSync(LOCAL_SEND_PORT_OVERRIDES_KEY, JSON.stringify(overrides));
    await store.flush();
  }

  private static normalize(value: string): FileTransferTransport | undefined {
    if (value === 'tailsend' || value === 'localsend') {
      return value;
    }
    return undefined;
  }

  private static normalizePortOverrides(value: string): LocalSendPortOverride[] {
    try {
      const parsed: LocalSendPortOverride[] = JSON.parse(value) as LocalSendPortOverride[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      const result: LocalSendPortOverride[] = [];
      parsed.forEach((item: LocalSendPortOverride) => {
        if (item !== undefined && typeof item.peerKey === 'string' && item.peerKey.trim().length > 0 &&
          Number.isInteger(item.port) && item.port >= 1 && item.port <= 65535) {
          result.push({ peerKey: item.peerKey.trim(), port: item.port });
        }
      });
      return result;
    } catch (_error) {
      return [];
    }
  }
}
