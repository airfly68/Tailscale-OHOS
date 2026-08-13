import { MotionTokens } from './MotionTokens';

export interface UpdateChangelogEntry {
  versionName: string;
  versionCode: number;
  releaseDate: string;
  changes: string[];
  current: boolean;
}

/**
 * Release notes presented as a large, non-destructive bottom sheet.  The
 * parent owns visibility and persistence so this component remains a pure UI
 * surface that can be reused for later release-note entries.
 */
@Component
export struct UpdateChangelogSheet {
  @Prop entries: UpdateChangelogEntry[] = [];
  @Prop appName: string = 'MeshArc';
  @Link actionRequest: string;

  @Builder
  private Header() {
    Row({ space: 12 }) {
      Text($r('app.string.update_changelog_title'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Button({ type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true }) {
        Text($r('app.string.update_changelog_dont_show'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .id('update-changelog-dont-show')
      .height(48)
      .constraintSize({ minWidth: 132 })
      .padding({ left: 18, right: 18 })
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .borderRadius(24)
      .onClick(() => this.actionRequest = 'disable')

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('\u00D7')
          .fontSize(31)
          .fontWeight(FontWeight.Normal)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Center)
      }
      .id('update-changelog-close')
      .width(52)
      .height(52)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .onClick(() => this.actionRequest = 'dismiss')
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private VersionTimeline() {
    Row({ space: 6 }) {
      ForEach(this.entries, (entry: UpdateChangelogEntry) => {
        Column({ space: 7 }) {
          Stack() {
            Row()
              .width('100%')
              .height(2)
              .backgroundColor($r('sys.color.comp_divider'))
            Row()
              .width(14)
              .height(14)
              .borderRadius(7)
              .backgroundColor(entry.current ? $r('app.color.emphasize') :
                $r('sys.color.icon_secondary'))
              .align(Alignment.Start)
          }
          .width('100%')
          .height(18)

          Text(`v${entry.versionName}`)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(entry.current ? Color.White : $r('sys.color.font_primary'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: 8, right: 8, top: 8, bottom: 8 })
            .backgroundColor(entry.current ? $r('app.color.emphasize') :
              $r('sys.color.background_primary'))
            .borderRadius(20)

          Text(`versionCode ${entry.versionCode}`)
            .fontSize(12)
            .fontColor(entry.current ? $r('app.color.emphasize') :
              $r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(entry.releaseDate)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .padding({ left: 3, right: 3 })
      }, (entry: UpdateChangelogEntry) => `${entry.versionCode}`)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface_subtle'))
    .borderRadius(24)
  }

  @Builder
  private ChangeRow(change: string) {
    Row({ space: 12 }) {
      Text('\u2022')
        .fontSize(21)
        .fontColor($r('app.color.emphasize'))
        .width(14)
        .textAlign(TextAlign.Center)
      Text(change)
        .fontSize(17)
        .lineHeight(26)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private ChangelogDetails() {
    if (this.entries.length > 0) {
      Column({ space: 14 }) {
        Text(`${this.appName} ${this.entries[0].versionName}`)
          .fontSize(31)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')

        Text(`VersionCode: ${this.entries[0].versionCode}`)
          .fontSize(18)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')

        Text(this.entries[0].releaseDate)
          .fontSize(18)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')

        Text($r('app.string.update_changelog_section'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
          .margin({ top: 4 })

        ForEach(this.entries[0].changes, (change: string, index: number) => {
          this.ChangeRow(change);
        }, (_change: string, index: number) => `${index}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column() {
      this.Header()
      this.VersionTimeline()
      Scroll() {
        this.ChangelogDetails()
      }
      .id('update-changelog-content')
      .layoutWeight(1)
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 26, bottom: 20 })
    .backgroundColor($r('sys.color.background_primary'))
    .borderRadius({ topLeft: 30, topRight: 30 })
    .shadow({ radius: 24, color: '#33000000', offsetY: -8, offsetX: 0 })
    .transition(TransitionEffect.OPACITY.animation({
      duration: MotionTokens.NORMAL,
      curve: Curve.EaseOut
    }))
  }
}
