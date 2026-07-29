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

  @Builder
  private DetailRow(label: string, value: string): void {
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
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 4 }) {
          this.DetailRow('\u8FDE\u63A5\u72B6\u6001', '\u5DF2\u8FDE\u63A5')
          this.DetailRow('Tailnet', this.tailnetName)
          this.DetailRow('\u5F53\u524D\u8BBE\u5907', this.deviceName)
          this.DetailRow('Tailscale IP', this.tailscaleAddress)
          this.DetailRow('\u8FDE\u63A5\u65F6\u957F', this.duration)
          this.DetailRow('\u5F53\u524D\u4E0B\u8F7D', this.downloadRate)
          this.DetailRow('\u5F53\u524D\u4E0A\u4F20', this.uploadRate)
          this.DetailRow('\u672C\u6B21\u4E0B\u8F7D', this.downloadTotal)
          this.DetailRow('\u672C\u6B21\u4E0A\u4F20', this.uploadTotal)
          this.DetailRow('\u51FA\u53E3\u8282\u70B9',
            this.exitNodeName.length > 0 ? this.exitNodeName : '\u672A\u4F7F\u7528')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .padding({ left: 18, right: 18, top: 8, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}
