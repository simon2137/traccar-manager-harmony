import { showToast } from '../../common/utils/Toast';
import { Log } from '../../common/utils/Log';
import { isValidServerUrl } from '../../common/model/UriModel';

/** 上游 SnackBar 的文案就是英文（lib/error_screen.dart 里写死 'Invalid URL'）。 */
const INVALID_URL_MESSAGE: string = 'Invalid URL';

/**
 * 加载失败页：1:1 复刻上游 `lib/error_screen.dart`。
 *
 * 上游结构是 `Scaffold → Center → Column(mainAxisAlignment: center)`，自上而下：
 *   Icon(Icons.cloud_off, size: 96)
 *   SizedBox(height: 32)
 *   Padding(horizontal: 24) → Text(error, style: headlineSmall, textAlign: center)
 *   SizedBox(height: 32)
 *   Padding(horizontal: 24) → TextField(border: OutlineInputBorder(),
 *                                        suffixIcon: InkWell(child: Icon(Icons.check)))
 *
 * M3 对应物：headlineSmall = 24sp/32 行高、OutlineInputBorder = 1vp 描边 + 4vp 圆角、
 * suffixIcon = 输入框右内侧 40×40 的图标按钮。
 */
@Component
export struct ErrorScreen {
  /** 加载失败信息（上游 `_loadingError`，来自 error.description）。 */
  @Prop errorMessage: string = '';
  /** 当前服务器地址，作为输入框初值（上游 `url` 参数）。 */
  @Prop @Watch('onServerUrlChanged') serverUrl: string = '';
  @State input: string = '';
  /** 上一次从 serverUrl 同步的值：用户正在输入时不要被覆盖。 */
  private lastSyncedUrl: string = '';
  onSubmit: (url: string) => void = (_url: string) => {
  };

  aboutToAppear(): void {
    this.input = this.serverUrl;
    this.lastSyncedUrl = this.serverUrl;
  }

  onServerUrlChanged(): void {
    if (this.input.length === 0 || this.input === this.lastSyncedUrl) {
      this.input = this.serverUrl;
    }
    this.lastSyncedUrl = this.serverUrl;
  }

  build() {
    Column() {
      Image($r('app.media.cloud_off'))
        .width($r('app.float.error_icon_size'))
        .height($r('app.float.error_icon_size'))
        .fillColor($r('app.color.on_surface_variant'))
        .objectFit(ImageFit.Contain)

      Text(this.errorMessage)
        .fontSize(24)
        .lineHeight(32)
        .fontColor($r('app.color.on_surface'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
        .margin({ top: 32 })

      // 输入框 + 内侧 check 按钮（M3 的 suffixIcon 位置：右端 8vp 处、垂直居中）。
      Stack({ alignContent: Alignment.End }) {
        TextInput({ text: this.input })
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 52 })
          .fontSize(16)
          .fontColor($r('app.color.on_surface'))
          .placeholderColor($r('app.color.on_surface_variant'))
          .caretColor($r('app.color.primary'))
          .backgroundColor(Color.Transparent)
          .borderWidth(1)
          .borderColor($r('app.color.outline'))
          .borderRadius($r('app.float.field_corner_radius'))
          .enterKeyType(EnterKeyType.Go)
          .onChange((value: string) => {
            this.input = value;
          })
          .onSubmit(() => {
            this.submit();
          })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('app.media.check'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.on_surface_variant'))
        }
        .width(40)
        .height(40)
        .margin({ right: 8 })
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.submit();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 24, right: 24 })
      .margin({ top: 32 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.surface'))
  }

  /** 上游校验：非空 + 绝对 URI + scheme 为 http/https + host 非空；否则弹 'Invalid URL'。 */
  private submit(): void {
    const text: string = this.input.trim();
    if (!isValidServerUrl(text)) {
      Log.info('invalid server url submitted');
      showToast(this.getUIContext(), INVALID_URL_MESSAGE);
      return;
    }
    this.onSubmit(text);
  }
}
