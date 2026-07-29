import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  ConnectedHomeLayoutMode,
  DEFAULT_CONNECTED_HOME_LAYOUT,
  HomeLayoutConfig
} from './HomeLayoutConfig';

const STORE_NAME: string = 'mesh_arc_home_layout';
const CONNECTED_LAYOUT_KEY: string = 'connected_home_layout_mode';

/** Persists a visual preference only; it never touches VPN or backend state. */
export class HomeLayoutPreferences {
  static async load(context: common.Context): Promise<ConnectedHomeLayoutMode> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME);
      const saved: string = store.getSync(CONNECTED_LAYOUT_KEY,
        HomeLayoutConfig.connectedHomeLayoutMode) as string;
      return HomeLayoutConfig.isValid(saved) ? saved as ConnectedHomeLayoutMode :
        DEFAULT_CONNECTED_HOME_LAYOUT;
    } catch (_error) {
      return DEFAULT_CONNECTED_HOME_LAYOUT;
    }
  }

  static async save(context: common.Context, mode: ConnectedHomeLayoutMode): Promise<void> {
    const store = await preferences.getPreferences(context, STORE_NAME);
    store.putSync(CONNECTED_LAYOUT_KEY, mode);
    await store.flush();
  }
}
