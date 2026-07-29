import { ConnectedHomeLayoutMode } from './HomeLayoutConfig';

/** Selects one connected layout while leaving inactive/connecting/error UI unchanged. */
@Component
export struct HomeConnectionSection {
  @Prop connected: boolean = false;
  @Prop layoutMode: ConnectedHomeLayoutMode = ConnectedHomeLayoutMode.COMPACT;
  @BuilderParam inactiveHeader: () => void;
  @BuilderParam legacyHeader: () => void;
  @BuilderParam compactHeader: () => void;

  build() {
    if (!this.connected) {
      this.inactiveHeader()
    } else if (this.layoutMode === ConnectedHomeLayoutMode.LEGACY) {
      this.legacyHeader()
    } else {
      this.compactHeader()
    }
  }
}
