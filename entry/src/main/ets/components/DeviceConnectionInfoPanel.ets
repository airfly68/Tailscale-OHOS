import { PeerPathResult, SunshineProbeResult } from '../services/StreamingModels';
import { MediaProbeResult } from '../services/MediaIntegrationModels';

@Component
export struct DeviceConnectionInfoPanel {
  @Prop path: PeerPathResult = { type: 'unknown', checkedAt: 0 };
  @Prop sunshine: SunshineProbeResult = { state: 'unknown', checkedAt: 0 };
  @Prop media: MediaProbeResult = { state: 'unknown', checkedAt: 0, services: [] };
  @Prop checking: boolean = false;
  onRefresh: () => void = () => {};

  private pathLabel(): string {
    if (this.checking) return '正在检测';
    if (this.path.type === 'direct') return `直连 · ${this.path.latencyMs ?? 0} ms`;
    if (this.path.type === 'peerRelay') return `点对点中继 · ${this.path.latencyMs ?? 0} ms`;
    if (this.path.type === 'derp') return `DERP 中继 · ${this.path.latencyMs ?? 0} ms`;
    if (this.path.type === 'unreachable') return '当前不可达';
    return '尚未确认';
  }

  private pathColor(): string {
    if (this.checking) return '#8A8A8A';
    if (this.path.type === 'direct') return '#45A267';
    if (this.path.type === 'peerRelay' || this.path.type === 'derp') return '#D9933B';
    return '#9A9A9A';
  }

  private sunshineLabel(): string {
    if (this.sunshine.state === 'checking') return '正在检测';
    if (this.sunshine.state === 'available') return 'Sunshine 可用';
    if (this.sunshine.state === 'timeout') return 'Sunshine 检测超时';
    if (this.sunshine.state === 'unavailable') return '未检测到 Sunshine';
    if (this.sunshine.state === 'error') return 'Sunshine 检测失败';
    return '尚未确认';
  }

  private mediaLabel(): string {
    if (this.media.state === 'checking') return '正在检测';
    if (this.media.services.length > 0) {
      return this.media.services.map((service) => {
        if (service.type === 'jellyfin') return 'Jellyfin';
        if (service.type === 'emby') return 'Emby';
        if (service.type === 'plex') return 'Plex';
        if (service.type === 'webdav') return 'WebDAV';
        return 'SMB';
      }).join(' · ');
    }
    if (this.media.state === 'unavailable') return '未发现支持的影音服务';
    if (this.media.state === 'timeout') return '检测超时';
    if (this.media.state === 'error') return '检测失败';
    return '尚未确认';
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Text('连接状态').fontSize(12).fontColor($r('sys.color.font_secondary'))
        Blank()
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(15)
          .fontColor([$r('sys.color.icon_secondary')])
          .padding({ left: 10, right: 4, top: 4, bottom: 4 })
          .onClick(this.onRefresh)
      }
      .width('100%')
      .padding({ left: 12, right: 8, top: 10, bottom: 9 })
      Divider().color('#14000000')
      Row() {
        Text('连接方式').fontSize(12).fontColor($r('sys.color.font_secondary'))
        Row({ space: 6 }) {
          if (this.checking) {
            LoadingProgress().width(12).height(12).color('#7B8EA8')
          } else {
            Row().width(7).height(7).borderRadius(4).backgroundColor(this.pathColor())
          }
          Text(this.pathLabel()).fontSize(12).fontColor($r('sys.color.font_primary'))
        }
          .layoutWeight(1)
          .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 9, bottom: 10 })
      Divider().color('#14000000')
      Row() {
        Text('远程串流').fontSize(12).fontColor($r('sys.color.font_secondary'))
        Text(this.sunshineLabel())
          .fontSize(12)
          .fontColor(this.sunshine.state === 'available' ? '#397A52' : $r('sys.color.font_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 9, bottom: 10 })
      Divider().color('#14000000')
      Row() {
        Text('影音服务').fontSize(12).fontColor($r('sys.color.font_secondary'))
        Text(this.mediaLabel())
          .fontSize(12)
          .fontColor(this.media.services.length > 0 ? '#68439D' : $r('sys.color.font_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 9, bottom: 10 })
    }
    .width('100%')
    .backgroundColor('#0D000000')
    .borderRadius(12)
  }
}
