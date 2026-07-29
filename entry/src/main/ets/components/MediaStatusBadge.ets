import { MediaProbeState } from '../services/MediaIntegrationModels';

@Component
export struct MediaStatusBadge {
  @Prop @Watch('onBadgeStateChanged') state: MediaProbeState = 'unknown';
  @Prop @Watch('onBadgeStateChanged') serviceNames: string = '';
  @State badgeVisible: boolean = false;
  @State displayedState: MediaProbeState = 'unknown';
  @State displayedServiceNames: string = '';

  aboutToAppear(): void {
    if (this.shouldShow()) {
      this.displayedState = this.state;
      this.displayedServiceNames = this.serviceNames;
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.badgeVisible = true;
      });
    }
  }

  private shouldShow(): boolean {
    return this.state === 'checking' || this.serviceNames.length > 0;
  }

  private onBadgeStateChanged(): void {
    if (this.shouldShow()) {
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.displayedState = this.state;
        this.displayedServiceNames = this.serviceNames;
        this.badgeVisible = true;
      });
      return;
    }
    if (this.badgeVisible) {
      this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseIn }, () => {
        this.badgeVisible = false;
      });
    }
  }

  build() {
    if (this.badgeVisible) {
      Text(this.displayedState === 'checking' ?
        '影音服务检测中' : `${this.displayedServiceNames} 可用`)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.displayedServiceNames.length > 0 ? '#68439D' : '#667085')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor(this.displayedServiceNames.length > 0 ? '#F3EDFF' : '#EEF1F5')
        .borderRadius(8)
        .transition(
          TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut })
              .combine(TransitionEffect.translate({ y: -4 })),
            TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseIn })
              .combine(TransitionEffect.translate({ y: -3 }))
          )
        )
    }
  }
}
