import { MediaProbeState } from '../services/MediaIntegrationModels';

@Component
export struct MediaStatusBadge {
  @Prop state: MediaProbeState = 'unknown';
  @Prop serviceNames: string = '';

  build() {
    if (this.state === 'checking' || this.serviceNames.length > 0) {
      Text(this.state === 'checking' ? '影音服务检测中' : `${this.serviceNames} 可用`)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.serviceNames.length > 0 ? '#68439D' : '#667085')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor(this.serviceNames.length > 0 ? '#F3EDFF' : '#EEF1F5')
        .borderRadius(8)
    }
  }
}
