export enum ConnectedHomeLayoutMode {
  LEGACY = 'legacy',
  COMPACT = 'compact'
}

/** The single source of truth for the connected-home presentation. */
export const DEFAULT_CONNECTED_HOME_LAYOUT: ConnectedHomeLayoutMode =
  ConnectedHomeLayoutMode.COMPACT;

export class HomeLayoutConfig {
  static readonly connectedHomeLayoutMode: ConnectedHomeLayoutMode =
    DEFAULT_CONNECTED_HOME_LAYOUT;

  static isValid(mode: string): boolean {
    return mode === ConnectedHomeLayoutMode.LEGACY || mode === ConnectedHomeLayoutMode.COMPACT;
  }
}
