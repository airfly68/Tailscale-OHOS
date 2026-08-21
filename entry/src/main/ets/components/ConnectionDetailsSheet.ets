@Component
export struct ConnectionDetailsSheet {
  @Prop tailnetName: string = '';
  @Prop deviceName: string = '';
  @Prop tailscaleAddress: string = '';
  @Prop duration: string = '';
  @Prop downloadRate: string = '';
  @Prop uploadRate: string = '';
  @Prop downloadTotal: string = '';
  @Prop uploadTotal: string = '';
  @Prop exitNodeName: string = '';
  @Prop allowLanAccess: boolean = false;
  @Prop disconnecting: boolean = false;
  onCopyAddress: () => void = () => {};
  onDisconnect: () => void = () => {};

  @Builder
  private SectionTitle(title: ResourceStr): void {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 2 })
  }

  @Builder
  private DetailRow(label: ResourceStr, value: ResourceStr, actionable: boolean = false,
    action: () => void = () => {}): void {
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
        SymbolGlyph($r('sys.symbol.doc'))
          .fontSize(15)
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
        Row({ space: 10 }) {
          Row()
            .width(9)
            .height(9)
            .borderRadius(5)
            .backgroundColor($r('app.color.status_success'))
          Column({ space: 2 }) {
            Text($r('app.string.connection_connected'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text(this.tailnetName.length > 0 ? this.tailnetName : this.deviceName)
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 4, right: 4, bottom: 4 })

        this.SectionTitle($r('app.string.network_sheet_network_title'))
        Column({ space: 0 }) {
          this.DetailRow($r('app.string.network_sheet_device_label'), this.deviceName)
          if (this.tailscaleAddress.length > 0) {
            Divider()
              .color($r('sys.color.comp_divider'))
              .margin({ left: 14, right: 14 })
            this.DetailRow($r('app.string.network_sheet_local_address'), this.tailscaleAddress,
              true, this.onCopyAddress)
          }
          Divider()
            .color($r('sys.color.comp_divider'))
            .margin({ left: 14, right: 14 })
          this.DetailRow($r('app.string.exit_node_title'),
            this.exitNodeName.length > 0 ? this.exitNodeName : $r('app.string.network_sheet_not_used'))
          Divider()
            .color($r('sys.color.comp_divider'))
            .margin({ left: 14, right: 14 })
          this.DetailRow('DNS', $r('app.string.network_sheet_tailnet_default'))
          Divider()
            .color($r('sys.color.comp_divider'))
            .margin({ left: 14, right: 14 })
          this.DetailRow($r('app.string.network_sheet_lan_access'), this.allowLanAccess ?
            $r('app.string.network_sheet_on') : $r('app.string.network_sheet_off'))
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)

        this.SectionTitle($r('app.string.network_sheet_traffic_title'))
        Column({ space: 0 }) {
          this.DetailRow($r('app.string.network_sheet_duration'), this.duration)
          Divider()
            .color($r('sys.color.comp_divider'))
            .margin({ left: 14, right: 14 })
          this.DetailRow($r('app.string.network_sheet_current_rate'),
            `\u2193 ${this.downloadRate}   \u2191 ${this.uploadRate}`)
          Divider()
            .color($r('sys.color.comp_divider'))
            .margin({ left: 14, right: 14 })
          this.DetailRow($r('app.string.network_sheet_session_traffic'),
            `\u2193 ${this.downloadTotal}   \u2191 ${this.uploadTotal}`)
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)

        Button({
          type: ButtonType.ROUNDED_RECTANGLE,
          stateEffect: true,
          buttonStyle: ButtonStyleMode.NORMAL
        }) {
          Row({ space: 8 }) {
            if (this.disconnecting) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color($r('app.color.status_error'))
            }
            Text($r('app.string.action_disconnect'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.status_error'))
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
        }
        .width('100%')
        .height(46)
        .enabled(!this.disconnecting)
        .opacity(this.disconnecting ? 0.55 : 1)
        .onClick(() => {
          if (!this.disconnecting) {
            this.onDisconnect();
          }
        })

        Blank()
          .width('100%')
          .height(24)
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
