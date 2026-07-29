import { SunshineState } from '../services/StreamingModels';

@Component
export struct SunshineStatusBadge {
  @Prop state: SunshineState = 'unknown';

  build() {
    if (this.state === 'available' || this.state === 'checking') {
      Text(this.state === 'checking' ? 'Sunshine 检测中' : 'Sunshine 可用')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.state === 'available' ? '#397A52' : '#667085')
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor(this.state === 'available' ? '#EAF5ED' : '#EEF1F5')
        .borderRadius(8)
    }
  }
}
