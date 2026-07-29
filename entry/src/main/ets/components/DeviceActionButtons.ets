import { SunshineState } from '../services/StreamingModels';
import { MediaProbeState } from '../services/MediaIntegrationModels';

@Component
export struct DeviceActionButtons {
  @Prop sunshineState: SunshineState = 'unknown';
  @Prop reachable: boolean = true;
  @Prop meshConnected: boolean = false;
  @Prop launching: boolean = false;
  @Prop showStreaming: boolean = true;
  @Prop mediaState: MediaProbeState = 'unknown';
  @Prop mediaCount: number = 0;
  @Prop mediaChecking: boolean = false;
  @Prop mediaLaunching: boolean = false;
  onStream: () => void = () => {};
  onDetectMedia: () => void = () => {};
  onMedia: () => void = () => {};
  onCopyIp: () => void = () => {};

  private canStream(): boolean {
    return this.meshConnected && this.reachable && this.sunshineState === 'available' && !this.launching;
  }

  private canUseMedia(): boolean {
    return this.meshConnected && this.reachable && !this.mediaChecking && !this.mediaLaunching;
  }

  build() {
    Row({ space: 0 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 5 }) {
          if (this.launching || this.sunshineState === 'checking') {
            LoadingProgress().width(14).height(14).color('#3C78C5')
          } else {
            SymbolGlyph($r('sys.symbol.rectangle_on_rectangle')).fontSize(15).fontColor(['#3C78C5'])
          }
          Text('远程串流')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#326DB4')
            .maxLines(1)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
      .layoutWeight(1)
      .height(40)
      .borderRadius(0)
      .backgroundColor(Color.Transparent)
      .enabled(this.showStreaming && this.canStream())
      .opacity(this.showStreaming && this.canStream() ? 1 : 0.42)
      .onClick(this.onStream)

      Divider()
        .vertical(true)
        .height(20)
        .color($r('sys.color.comp_divider'))

      Button({ type: ButtonType.Normal }) {
        Row({ space: 5 }) {
          if (this.mediaChecking || this.mediaLaunching) {
            LoadingProgress().width(14).height(14).color('#7A5AB5')
          } else {
            SymbolGlyph($r('sys.symbol.rectangle_on_rectangle')).fontSize(15).fontColor(['#7650AE'])
          }
          Text('影音服务')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#68439D')
            .maxLines(1)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
      .layoutWeight(1)
      .height(40)
      .borderRadius(0)
      .backgroundColor(Color.Transparent)
      .enabled(this.canUseMedia())
      .opacity(this.canUseMedia() ? 1 : 0.42)
      .onClick(() => {
        if (this.mediaCount > 0) {
          this.onMedia();
        } else {
          this.onDetectMedia();
        }
      })

      Divider()
        .vertical(true)
        .height(20)
        .color($r('sys.color.comp_divider'))

      Button({ type: ButtonType.Normal }) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.doc'))
            .fontSize(14)
            .fontColor([$r('sys.color.icon_secondary')])
          Text('复制 IP')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
      .layoutWeight(1)
      .height(40)
      .borderRadius(0)
      .backgroundColor(Color.Transparent)
      .onClick(this.onCopyIp)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#0D000000')
    .borderRadius(20)
    .clip(true)
  }
}
