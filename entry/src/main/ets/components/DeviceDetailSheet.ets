import { PeerPathResult } from '../services/StreamingModels';

@Component
export struct DeviceDetailSheet {
  @Prop osDescription: string = '';
  @Prop deviceModel: string = '';
  @Prop online: boolean = false;
  @Prop path: PeerPathResult = { type: 'unknown', checkedAt: 0 };
  @Prop tailscaleAddress: string = '';
  @Prop exitNodeCapable: boolean = false;
  @Prop servicesChecking: boolean = false;
  @Prop sunshineAvailable: boolean = false;
  @Prop sunshineLaunching: boolean = false;
  @Prop mediaServiceCount: number = 0;
  @Prop mediaServiceNames: string = '';
  @Prop mediaLaunching: boolean = false;
  @Prop localSendAvailable: boolean = false;
  @Prop taildropAvailable: boolean = false;
  @Prop taildropOnline: boolean = false;
  @Prop taildropReady: boolean = false;
  @Prop remoteFilesEnabled: boolean = false;
  onRefresh: () => void = () => {};
  onOpenStream: () => void = () => {};
  onOpenMedia: () => void = () => {};
  onOpenFileTransfer: () => void = () => {};
  onOpenRemoteFiles: () => void = () => {};
  onCopyIp: () => void = () => {};

  private hasAvailableServices(): boolean {
    return this.sunshineAvailable || this.mediaServiceCount > 0 || this.localSendAvailable ||
      this.taildropAvailable;
  }

  private fileTransferDescription(): ResourceStr {
    if (this.localSendAvailable && this.taildropReady) {
      return $r('app.string.device_detail_transfer_both_description');
    }
    if (this.localSendAvailable) {
      return $r('app.string.device_detail_transfer_localsend_description');
    }
    if (!this.taildropOnline) {
      return $r('app.string.device_detail_taildrop_offline');
    }
    if (!this.taildropReady) {
      return $r('app.string.device_detail_taildrop_connect');
    }
    return $r('app.string.device_detail_transfer_tailsend_description');
  }

  private pathLabel(): ResourceStr {
    if (!this.online) {
      return $r('app.string.peer_offline');
    }
    if (this.path.type === 'direct') {
      return $r('app.string.device_path_direct', this.path.latencyMs ?? 0);
    }
    if (this.path.type === 'peerRelay') {
      return $r('app.string.device_path_peer_relay', this.path.latencyMs ?? 0);
    }
    if (this.path.type === 'derp') {
      return $r('app.string.device_path_derp_relay', this.path.latencyMs ?? 0);
    }
    if (this.path.type === 'unreachable') {
      return $r('app.string.device_path_unreachable');
    }
    return $r('app.string.peer_online');
  }

  @Builder
  private SectionTitle(title: ResourceStr) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 2 })
  }

  @Builder
  private ServiceRow(icon: Resource, title: ResourceStr, description: ResourceStr,
    loading: boolean, enabled: boolean, action: () => void) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(40)
      .height(40)
      .borderRadius(12)
      .backgroundColor($r('sys.color.comp_background_tertiary'))

      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(description)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (loading) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color($r('app.color.emphasize'))
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(17)
          .fontColor([$r('sys.color.icon_secondary')])
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .enabled(enabled)
    .opacity(enabled ? 1 : 0.48)
    .onClick(() => {
      if (enabled) {
        action();
      }
    })
  }

  @Builder
  private InfoRow(label: ResourceStr, value: ResourceStr, actionable: boolean,
    action: () => void = () => {}) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      Text(value)
        .fontSize(13)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)
      if (actionable) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .onClick(() => {
      if (actionable) {
        action();
      }
    })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text(this.osDescription)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Row({ space: 7 }) {
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.online ? $r('app.color.status_success') :
                $r('app.color.status_offline'))
            Text(this.pathLabel())
              .fontSize(13)
              .fontColor($r('sys.color.font_primary'))
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 4, right: 4, bottom: 4 })

        Row() {
          Text($r('app.string.device_detail_services_title'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .padding({ left: 4, top: 8, bottom: 2 })
          Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.TEXTUAL }) {
            if (this.servicesChecking) {
              LoadingProgress()
                .width(17)
                .height(17)
                .color($r('app.color.emphasize'))
            } else {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(17)
                .fontColor([$r('sys.color.icon_secondary')])
            }
          }
          .width(36)
          .height(36)
          .enabled(this.online && !this.servicesChecking)
          .opacity(this.online ? 1 : 0.45)
          .accessibilityText($r('app.string.device_detail_refresh_services'))
          .onClick(() => {
            if (this.online && !this.servicesChecking) {
              this.onRefresh();
            }
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.sunshineAvailable) {
          this.ServiceRow($r('sys.symbol.rectangle_on_rectangle'),
            $r('app.string.device_detail_desktop_title'),
            $r('app.string.device_detail_desktop_description'),
            this.sunshineLaunching, !this.sunshineLaunching, this.onOpenStream)
        }
        if (this.mediaServiceCount > 0) {
          this.ServiceRow($r('sys.symbol.video'),
            $r('app.string.device_detail_media_title'),
            this.mediaServiceNames,
            this.mediaLaunching, !this.mediaLaunching, this.onOpenMedia)
        }
        if (this.servicesChecking) {
          Row({ space: 10 }) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color($r('app.color.emphasize'))
            Text($r('app.string.device_detail_services_checking'))
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
        } else if (!this.hasAvailableServices()) {
          Text(this.online ? $r('app.string.device_detail_services_empty') :
            $r('app.string.device_detail_services_offline'))
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .lineHeight(19)
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
        }

        if (this.localSendAvailable || this.taildropAvailable) {
          this.ServiceRow($r('sys.symbol.doc'),
            $r('app.string.device_detail_transfer_title'),
            this.fileTransferDescription(), false, this.localSendAvailable || this.taildropReady,
            this.onOpenFileTransfer)
        }

        this.SectionTitle($r('app.string.taildrive_title'))
        this.ServiceRow($r('sys.symbol.folder'), 'Taildrive',
          $r('app.string.taildrive_subtitle'), false, this.remoteFilesEnabled,
          this.onOpenRemoteFiles)

        this.SectionTitle($r('app.string.device_detail_network_title'))
        Column({ space: 0 }) {
          this.InfoRow($r('app.string.device_connection_path'), this.pathLabel(), false)
          if (this.tailscaleAddress.length > 0) {
            Divider()
              .color($r('sys.color.comp_divider'))
              .margin({ left: 14, right: 14 })
            this.InfoRow('Tailscale IP', this.tailscaleAddress, true, this.onCopyIp)
          }
          if (this.exitNodeCapable) {
            Divider()
              .color($r('sys.color.comp_divider'))
              .margin({ left: 14, right: 14 })
            this.InfoRow($r('app.string.exit_node_title'),
              $r('app.string.device_detail_exit_node_available'), false)
          }
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)

        this.SectionTitle($r('app.string.device_detail_device_title'))
        Column({ space: 0 }) {
          this.InfoRow($r('app.string.device_detail_system_label'), this.osDescription, false)
          if (this.deviceModel.length > 0) {
            Divider()
              .color($r('sys.color.comp_divider'))
              .margin({ left: 14, right: 14 })
            this.InfoRow($r('app.string.device_detail_model_label'), this.deviceModel, false)
          }
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)

        Blank()
          .width('100%')
          .height(28)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Auto)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
