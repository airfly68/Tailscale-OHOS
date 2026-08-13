import { AppShell } from '../components/AppShell';

@Entry
@Component
struct Index {
  @StorageLink('taildriveFilesTabActive') filesTabActive: boolean = false;
  @StorageLink('taildriveCurrentPath') taildrivePath: string = '/';
  @StorageLink('taildriveUiBackActive') taildriveUiBackActive: boolean = false;

  onBackPress(): boolean {
    if (!this.filesTabActive || (this.taildrivePath === '/' && !this.taildriveUiBackActive)) {
      return false;
    }
    AppStorage.setOrCreate('taildriveBackRequest', Date.now());
    return true;
  }

  build() {
    Column() {
      AppShell()
    }
    .id('shell-window-host')
    .width('100%')
    .height('100%')
  }
}
