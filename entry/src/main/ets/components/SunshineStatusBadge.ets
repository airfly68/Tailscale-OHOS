import { SunshineState } from '../services/StreamingModels';

@Component
export struct SunshineStatusBadge {
  @Prop @Watch('onStateChanged') state: SunshineState = 'unknown';
  @State badgeVisible: boolean = false;
  @State displayedState: SunshineState = 'unknown';

  aboutToAppear(): void {
    if (this.shouldShow(this.state)) {
      this.displayedState = this.state;
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.badgeVisible = true;
      });
    }
  }

  private shouldShow(state: SunshineState): boolean {
    return state === 'available' || state === 'checking';
  }

  private onStateChanged(): void {
    if (this.shouldShow(this.state)) {
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.displayedState = this.state;
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
      Text(this.displayedState === 'checking' ? 'Sunshine 检测中' : 'Sunshine 可用')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.displayedState === 'available' ? '#397A52' : '#667085')
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor(this.displayedState === 'available' ? '#EAF5ED' : '#EEF1F5')
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
