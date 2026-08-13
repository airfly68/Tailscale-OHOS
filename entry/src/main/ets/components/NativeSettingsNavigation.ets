import { curves } from '@kit.ArkUI';
import { MotionTokens } from './MotionTokens';

/**
 * Native settings surface used by the settings half-modal.
 *
 * Navigation owns the two detail pages while bindSheet owns presentation.
 * Keeping those responsibilities separate makes the sheet dismissible without
 * coupling the settings pages to the app's primary HdsNavigation stack.
 */
@Component
export struct NativeSettingsNavigation {
  @Prop glowLevel: number = 3;
  @Prop backgroundImageUri: string = '';
  @Prop profileName: string = '';
  @Prop storageAppDataBytes: number = 0;
  @Prop storageReceivedBytes: number = 0;
  @Prop storageTemporaryBytes: number = 0;
  @Prop storageClearEnabled: boolean = false;
  @Prop backgroundPickerInProgress: boolean = false;
  @Prop backgroundClearEnabled: boolean = false;
  @Prop immersiveColorEnabled: boolean = false;
  @Prop pageName: string = 'background';
  onGlowLevelChange: (level: number) => void = (_level: number) => {};
  onSelectBackground: () => void = () => {};
  onClearBackground: () => void = () => {};
  onImmersiveColorChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onSelectTransfer: () => void = () => {};
  onClearTemporaryStorage: () => void = () => {};
  onDismiss: () => void = () => {};

  @State hdrEnabled: boolean = false;
  @State floatingTabsEnabled: boolean = false;
  @State materialBrightness: number = 52;
  @State intelligentMaterialIndex: number = 0;
  @State animationDuration: number = 60;
  @State animationAmplitude: number = 56;
  @State animationDamping: number = 64;
  @State animationPreset: number = 1;
  @State previewActive: boolean = false;
  @State materialIndex: number = 3;

  private navPathStack: NavPathStack = new NavPathStack();
  private navigationLockUntilMs: number = 0;
  private previewAnimationLockUntilMs: number = 0;

  aboutToAppear(): void {
    this.materialIndex = this.glowLevel >= 0 && this.glowLevel <= 3 ? this.glowLevel : 3;
  }

  private materialLabel(): ResourceStr {
    switch (this.materialIndex) {
      case 0: return $r('app.string.native_settings_material_exquisite');
      case 1: return $r('app.string.native_settings_material_gentle');
      case 2: return $r('app.string.native_settings_material_smooth');
      default: return $r('app.string.native_settings_material_adaptive');
    }
  }

  private selectMaterial(index: number): void {
    if (index < 0 || index > 3) {
      return;
    }
    this.materialIndex = index;
    this.onGlowLevelChange(index);
  }

  private pushPage(name: string): void {
    const now: number = Date.now();
    if (name.length === 0 || now < this.navigationLockUntilMs) {
      return;
    }
    // Navigation already owns the page transition. Wrapping pushPath in a
    // second animateTo callback can defer several taps and replay them later.
    this.navigationLockUntilMs = now + MotionTokens.PAGE;
    this.navPathStack.pushPath({ name: name }, true);
  }

  private popPage(): void {
    const now: number = Date.now();
    if (now < this.navigationLockUntilMs) {
      return;
    }
    this.navigationLockUntilMs = now + MotionTokens.PAGE;
    this.navPathStack.pop();
  }

  private togglePreview(): void {
    const duration: number = this.animationDurationMs();
    const now: number = Date.now();
    if (now < this.previewAnimationLockUntilMs) {
      return;
    }
    // Do not enqueue another animateTo while the previous preview motion is
    // still running. Queued callbacks are perceived as delayed menu opens.
    this.previewAnimationLockUntilMs = now + duration + MotionTokens.FAST;
    this.getUIContext().animateTo({
      duration: duration,
      curve: this.previewCurve()
    }, () => {
      this.previewActive = !this.previewActive;
    });
  }

  private animationDurationMs(): number {
    return 100 + this.animationDuration * 5;
  }

  private storageMegabytes(bytes: number): string {
    const megabytes: number = Math.max(0, bytes) / (1024 * 1024);
    return `${megabytes.toFixed(1)} MB`;
  }

  private storageTotalBytes(): number {
    return Math.max(0, this.storageAppDataBytes) + Math.max(0, this.storageReceivedBytes) +
      Math.max(0, this.storageTemporaryBytes);
  }

  private storageTotalLabel(): string {
    return `${(this.storageTotalBytes() / (1024 * 1024)).toFixed(1)} MB`;
  }

  private springDamping(value: number = this.animationDamping): number {
    // Map the 0-100 UI control to a stable spring range. The raw control
    // value is intentionally not passed directly as physical damping.
    return 8 + value * 0.3;
  }

  private previewCurve(damping: number = this.animationDamping) {
    return curves.springCurve(0, 1, 220, this.springDamping(damping));
  }

  private previewProgress(): number {
    return this.animationAmplitude / 100;
  }

  private previewCircleX(): number {
    return this.previewActive ? -30 - this.previewProgress() * 18 : -30;
  }

  private previewCircleY(): number {
    return this.previewActive ? 14 - this.previewProgress() * 10 : 14;
  }

  private previewCircleScale(): number {
    return this.previewActive ? 1 + this.previewProgress() * 0.12 : 1;
  }

  private previewDiamondX(): number {
    return this.previewActive ? 28 + this.previewProgress() * 18 : 28;
  }

  private previewDiamondY(): number {
    return this.previewActive ? -12 - this.previewProgress() * 12 : -12;
  }

  private previewDiamondScale(): number {
    return this.previewActive ? 1 + this.previewProgress() * 0.08 : 1;
  }

  private previewDiamondRotation(): number {
    return this.previewActive ? 45 + this.previewProgress() * 14 : 45;
  }

  private applyPreset(index: number): void {
    let duration: number = 60;
    let amplitude: number = 56;
    let damping: number = 64;
    if (index === 0) {
      duration = 28;
      amplitude = 32;
      damping = 82;
    } else if (index === 2) {
      duration = 78;
      amplitude = 72;
      damping = 42;
    }

    const animationDurationMs: number = 100 + duration * 5;
    const now: number = Date.now();
    if (now < this.previewAnimationLockUntilMs) {
      return;
    }
    this.previewAnimationLockUntilMs = now + animationDurationMs + MotionTokens.FAST;
    this.getUIContext().animateTo({
      duration: animationDurationMs,
      curve: this.previewCurve(damping)
    }, () => {
      this.animationPreset = index;
      this.animationDuration = duration;
      this.animationAmplitude = amplitude;
      this.animationDamping = damping;
      this.previewActive = !this.previewActive;
    });
  }

  @Builder
  private IconButton(icon: Resource, label: Resource, action: () => void,
    rotation: number = 0): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([$r('app.color.emphasize')])
        .rotate({ angle: rotation })
    }
      .width(46)
      .height(46)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('sys.color.comp_divider'), radius: 23 })
      .accessibilityText(label)
      .onClick(action)
  }

  @Builder
  private TopBar(title: ResourceStr, showBack: boolean): void {
    Row({ space: 8 }) {
      if (showBack) {
        this.IconButton($r('sys.symbol.chevron_right'), $r('app.string.native_settings_back'),
          () => this.popPage(), 180)
      } else {
        Blank().width(46).height(46)
      }
      Text(title)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.IconButton($r('sys.symbol.xmark'), $r('app.string.native_settings_close'),
        () => this.onDismiss())
    }
      .width('100%')
      .padding({ left: 18, right: 18, top: 12, bottom: 8 })
  }

  @Builder
  private SectionTitle(title: ResourceStr): void {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 18, bottom: 8 })
  }

  @Builder
  private SettingsRow(icon: Resource, title: ResourceStr, subtitle: ResourceStr,
    trailing: ResourceStr, action: () => void, rowId: string): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 12 }) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([$r('app.color.emphasize')])
          .width(26)
        Column({ space: 3 }) {
          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (subtitle !== '') {
            Text(subtitle)
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        if (trailing !== '') {
          Text(trailing)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(17)
          .fontColor([$r('app.color.emphasize')])
      }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 14 })
    }
      .width('100%')
      .height(72)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .id(rowId)
      .onClick(action)
  }

  @Builder
  private TransferSpaceRow(icon: Resource, title: ResourceStr, action: () => void,
    rowId: string): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 18 }) {
        Image(icon)
          .width(48)
          .height(48)
          .objectFit(ImageFit.Contain)
        Text(title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(22)
          .fontColor([$r('app.color.emphasize')])
      }
        .width('100%')
        .height('100%')
        .padding({ left: 18, right: 18 })
    }
      .width('100%')
      .height(88)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .id(rowId)
      .onClick(action)
  }

  @Builder
  private ProfileHero(): void {
    Column({ space: 8 }) {
      Image($r('app.media.app_icon'))
        .width(84)
        .height(84)
        .borderRadius(42)
        .objectFit(ImageFit.Cover)
        .border({ width: 2, color: $r('sys.color.comp_background_primary'), radius: 42 })
        .shadow({ radius: 14, color: '#33000000', offsetY: 5 })
      Text(this.profileName.length > 0 ? this.profileName : $r('app.string.native_settings_profile_default'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 10 }) {
          Text('✦')
            .fontSize(25)
            .fontColor($r('app.color.emphasize'))
          Text($r('app.string.native_settings_vip'))
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          Text($r('app.string.native_settings_vip_action'))
            .fontSize(15)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_secondary')])
        }
          .width('100%')
          .height('100%')
          .padding({ left: 18, right: 16 })
      }
        .width('100%')
        .height(76)
        .padding(0)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(24)
        .id('native-settings-vip')
        .onClick(() => {})
    }
      .width('100%')
      .padding({ left: 18, right: 18, top: 8, bottom: 8 })
      .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private SettingsHome(): void {
    Scroll() {
      Column({ space: 14 }) {
        this.TopBar($r('app.string.native_settings_title'), false)
        this.ProfileHero()

        this.SectionTitle($r('app.string.native_settings_transfer_section'))
        Column({ space: 2 }) {
          this.TransferSpaceRow($r('app.media.native_transfer_entry'),
            $r('app.string.native_settings_transfer'), () => this.onSelectTransfer(),
            'native-settings-transfer')
          this.TransferSpaceRow($r('app.media.native_storage_entry'),
            $r('app.string.native_settings_storage'), () => this.pushPage('storage'),
            'native-settings-storage')
        }
          .width('calc(100% - 36vp)')
          .margin({ left: 18, right: 18 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(28)
          .clip(true)

        this.SectionTitle($r('app.string.native_settings_appearance_section'))
        Column({ space: 0 }) {
          this.SettingsRow($r('sys.symbol.doc'), $r('app.string.native_settings_theme'),
            '', '', () => {}, 'native-settings-theme')
          Divider().color($r('sys.color.comp_divider')).margin({ left: 54, right: 16 })
          this.SettingsRow($r('sys.symbol.eye'), $r('app.string.native_settings_color_mode'),
            '', $r('app.string.native_settings_system_follow'), () => {},
            'native-settings-color-mode')
          Divider().color($r('sys.color.comp_divider')).margin({ left: 54, right: 16 })
          this.SettingsRow($r('sys.symbol.picture'),
            $r('app.string.native_settings_background_material'), '', '',
            () => this.pushPage('background'), 'native-settings-background-material')
          Divider().color($r('sys.color.comp_divider')).margin({ left: 54, right: 16 })
          this.SettingsRow($r('sys.symbol.arrow_clockwise'),
            $r('app.string.native_settings_animation'), '', '',
            () => this.pushPage('animation'), 'native-settings-animation')
        }
          .width('calc(100% - 36vp)')
          .margin({ left: 18, right: 18 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(22)
          .clip(true)

        this.SectionTitle($r('app.string.native_settings_help_section'))
        Column({ space: 0 }) {
          this.SettingsRow($r('sys.symbol.doc'), $r('app.string.native_settings_usage'),
            '', '', () => {}, 'native-settings-usage')
        }
          .width('calc(100% - 36vp)')
          .margin({ left: 18, right: 18, bottom: 24 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(22)
          .clip(true)
      }
        .width('100%')
        .padding({ top: 4, bottom: 16 })
    }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
  }

  @Builder
  private PreviewCard(): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.backgroundImageUri.length > 0) {
          Image(this.backgroundImageUri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        } else {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('#F0F1F5')
        }
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(116)
            .height(116)
            .borderRadius(58)
            .backgroundColor('#2A0B73')
            .shadow({ radius: 18, color: '#33000000', offsetY: 7 })
            .scale({ x: this.previewCircleScale(), y: this.previewCircleScale() })
            .translate({ x: this.previewCircleX(), y: this.previewCircleY() })
          Row()
            .width(116)
            .height(116)
            .borderRadius(24)
            .backgroundColor('#321181')
            .shadow({ radius: 18, color: '#33000000', offsetY: 7 })
            .scale({ x: this.previewDiamondScale(), y: this.previewDiamondScale() })
            .rotate({ angle: this.previewDiamondRotation() })
            .translate({ x: this.previewDiamondX(), y: this.previewDiamondY() })
        }
      }
        .width('100%')
        .height('100%')
        .backgroundColor('#D9D7E5')
        .borderRadius(24)
        .clip(true)
    }
      .width('100%')
      .height(240)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('sys.color.comp_divider'), radius: 24 })
      .id('native-settings-preview')
      .onClick(() => this.togglePreview())
  }

  @Builder
  private BackgroundPreviewCard(): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.backgroundImageUri.length > 0) {
        Image(this.backgroundImageUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Row()
          .width(278)
          .height(278)
          .borderRadius(139)
          .backgroundColor('#D9D7E5')
        Row()
          .width(196)
          .height(196)
          .borderRadius(98)
          .backgroundColor('#A9A3BF')
          .opacity(0.8)
        Row()
          .width(112)
          .height(112)
          .borderRadius(56)
          .backgroundColor($r('app.color.emphasize'))
          .shadow({ radius: 18, color: '#55000000', offsetY: 7 })
      }
    }
      .borderRadius(24)
      .clip(true)
      .width('100%')
      .height(260)
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('sys.color.comp_divider'), radius: 24 })
      .id('native-settings-background-preview')
  }

  @Builder
  private ToggleRow(title: ResourceStr, description: ResourceStr, isOn: boolean,
    onChange: (value: boolean) => void): void {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
        Text(description)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .maxLines(2)
      }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.emphasize'))
        .onChange(onChange)
    }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  @Builder
  private SliderRow(title: ResourceStr, value: number, onChange: (value: number) => void): void {
    Row({ space: 12 }) {
      Text(title)
        .fontSize(15)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Slider({ value: value, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
        .layoutWeight(1.15)
        .onChange(onChange)
    }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  private BackgroundPage(): void {
    Column() {
      this.TopBar($r('app.string.native_settings_background_material'), false)
      Scroll() {
        Column({ space: 14 }) {
          this.BackgroundPreviewCard()
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.picture'))
                .fontSize(22)
                .fontColor([$r('app.color.emphasize')])
              Text($r('app.string.native_settings_choose_background'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(17)
                .fontColor([$r('sys.color.icon_secondary')])
            }
              .width('100%')
              .height('100%')
              .padding({ left: 16, right: 14 })
          }
            .width('100%')
            .height(66)
            .padding(0)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)
            .enabled(!this.backgroundPickerInProgress)
            .id('native-settings-choose-background')
            .onClick(() => this.onSelectBackground())

          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(21)
                .fontColor([$r('app.color.status_error')])
              Text($r('app.string.native_settings_clear_background'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.status_error'))
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
            }
              .width('100%')
              .height('100%')
              .padding({ left: 16, right: 14 })
          }
            .width('100%')
            .height(58)
            .padding(0)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)
            .enabled(this.backgroundClearEnabled)
            .opacity(this.backgroundClearEnabled ? 1 : 0.42)
            .id('native-settings-clear-background')
            .onClick(() => this.onClearBackground())

          Column({ space: 0 }) {
            this.ToggleRow($r('app.string.native_settings_immersive_color'),
              $r('app.string.native_settings_immersive_color_desc'), this.immersiveColorEnabled,
              (value: boolean) => this.onImmersiveColorChange(value))
          }
            .width('100%')
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)
            .clip(true)

          Column({ space: 0 }) {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Text($r('app.string.native_settings_material'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text($r('app.string.native_settings_material_desc'))
                  .fontSize(12)
                  .fontColor($r('sys.color.font_secondary'))
              }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              Select([
                { value: $r('app.string.native_settings_material_exquisite') },
                { value: $r('app.string.native_settings_material_gentle') },
                { value: $r('app.string.native_settings_material_smooth') },
                { value: $r('app.string.native_settings_material_adaptive') }
              ])
                .selected(this.materialIndex)
                .value(this.materialLabel())
                .font({ size: 14 })
                .optionFont({ size: 14 })
                .controlSize(ControlSize.SMALL)
                .constraintSize({ minWidth: 104, maxWidth: 128 })
                .onSelect((index: number) => this.selectMaterial(index))
            }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            Divider().color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })
            this.SliderRow($r('app.string.native_settings_brightness'), this.materialBrightness,
              (value: number) => this.materialBrightness = value)
            Divider().color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Text($r('app.string.native_settings_intelligent_material'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text($r('app.string.native_settings_intelligent_material_desc'))
                  .fontSize(12)
                  .fontColor($r('sys.color.font_secondary'))
                  .width('100%')
                  .maxLines(2)
              }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              Select([{ value: $r('app.string.native_settings_material_adaptive') },
                { value: $r('app.string.native_settings_material_smooth') }])
                .selected(this.intelligentMaterialIndex)
                .value(this.intelligentMaterialIndex === 0 ?
                  $r('app.string.native_settings_material_adaptive') :
                  $r('app.string.native_settings_material_smooth'))
                .font({ size: 14 })
                .optionFont({ size: 14 })
                .controlSize(ControlSize.SMALL)
                .constraintSize({ minWidth: 104, maxWidth: 128 })
                .onSelect((index: number) => this.intelligentMaterialIndex = index)
            }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          }
            .width('100%')
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)
            .clip(true)

        }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 28 })
      }
        .width('100%')
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
    }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private AnimationPage(): void {
    Column() {
      this.TopBar($r('app.string.native_settings_animation'), false)
      Scroll() {
        Column({ space: 14 }) {
          this.PreviewCard()
          Column({ space: 0 }) {
            this.SliderRow($r('app.string.native_settings_animation_duration'),
              this.animationDuration, (value: number) => this.animationDuration = value)
            Divider().color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })
            this.SliderRow($r('app.string.native_settings_animation_amplitude'),
              this.animationAmplitude, (value: number) => this.animationAmplitude = value)
            Divider().color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })
            this.SliderRow($r('app.string.native_settings_animation_damping'),
              this.animationDamping, (value: number) => this.animationDamping = value)
          }
            .width('100%')
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)
            .clip(true)

          Row({ space: 10 }) {
            this.PresetButton(0, $r('app.string.native_settings_preset_efficiency'))
            this.PresetButton(1, $r('app.string.native_settings_preset_default'))
            this.PresetButton(2, $r('app.string.native_settings_preset_lively'))
          }
            .width('100%')
            .height(54)
            .justifyContent(FlexAlign.SpaceBetween)
        }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 28 })
      }
        .width('100%')
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
    }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private StorageSummaryRow(color: ResourceColor, title: ResourceStr, bytes: number,
    rowId: string): void {
    Row({ space: 14 }) {
      Circle()
        .width(14)
        .height(14)
        .fill(color)
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.storageMegabytes(bytes))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
      .width('100%')
      .height(74)
      .padding({ left: 22, right: 22 })
      .id(rowId)
  }

  @Builder
  private StoragePage(): void {
    Column() {
      this.TopBar($r('app.string.native_settings_storage'), true)
      Scroll() {
        Column({ space: 22 }) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(278)
              .height(278)
              .borderRadius(139)
              .border({ width: 24, color: '#21005D', radius: 139 })
              .shadow({ radius: 22, color: '#35000000', offsetY: 8 })
            Column({ space: 8 }) {
              Text(this.storageTotalLabel())
                .fontSize(46)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              Text($r('app.string.native_settings_storage_total'))
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_secondary'))
            }
          }
            .width('100%')
            .height(328)

          Column({ space: 0 }) {
            this.StorageSummaryRow($r('app.color.emphasize'),
              $r('app.string.native_settings_storage_app_data'), this.storageAppDataBytes,
              'native-settings-storage-app-data')
            Divider().color($r('sys.color.comp_divider')).margin({ left: 22, right: 22 })
            this.StorageSummaryRow($r('app.color.emphasize'),
              $r('app.string.native_settings_storage_received'), this.storageReceivedBytes,
              'native-settings-storage-received')
            Divider().color($r('sys.color.comp_divider')).margin({ left: 22, right: 22 })
            this.StorageSummaryRow('#FFB43B',
              $r('app.string.native_settings_storage_temporary'), this.storageTemporaryBytes,
              'native-settings-storage-temporary')
          }
            .width('100%')
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(26)
            .clip(true)

          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 12 }) {
              Text($r('app.string.native_settings_storage_clear'))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
              Text($r('app.string.native_settings_storage_clear_action'))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.emphasize'))
            }
              .width('100%')
              .height('100%')
              .padding({ left: 22, right: 22 })
          }
            .width('100%')
            .height(78)
            .padding(0)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(26)
            .enabled(this.storageClearEnabled)
            .id('native-settings-storage-clear')
            .onClick(() => this.onClearTemporaryStorage())
        }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 28 })
      }
        .width('100%')
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
    }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private PresetButton(index: number, title: ResourceStr): void {
    Button({ type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true }) {
      Text(title)
        .fontSize(15)
        .fontColor(this.animationPreset === index ? $r('app.color.emphasize') :
          $r('sys.color.font_primary'))
    }
      .layoutWeight(1)
      .height(54)
      .padding(0)
      .backgroundColor(this.animationPreset === index ? '#E7E1FF' :
        $r('sys.color.comp_background_primary'))
      .onClick(() => this.applyPreset(index))
  }

  @Builder
  private PageMap(name: string): void {
    if (name === 'background') {
      NavDestination() {
        this.BackgroundPage()
      }
        .hideTitleBar(true)
    } else if (name === 'animation') {
      NavDestination() {
        this.AnimationPage()
      }
        .hideTitleBar(true)
    } else if (name === 'storage') {
      NavDestination() {
        this.StoragePage()
      }
        .hideTitleBar(true)
    }
  }

  build() {
    Column() {
      if (this.pageName === 'animation') {
        this.AnimationPage()
      } else {
        this.BackgroundPage()
      }
    }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
      .id(this.pageName === 'animation' ?
        'native-animation-settings' : 'native-background-material-settings')
  }
}
