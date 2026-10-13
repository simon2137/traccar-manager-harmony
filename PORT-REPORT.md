# Traccar Manager → HarmonyOS 移植报告

**目标**：把官方 Flutter 应用 [traccar/traccar-manager](https://github.com/traccar/traccar-manager) 移植为
HarmonyOS 7（API 26）原生 ArkTS 应用，做多端适配，并落地鸿蒙 7 的新特性，最后在本机构建出可分发的 HAP。

**结论**：移植完成，`BUILD SUCCESSFUL`，产物
`D:\dsh\Traccar\harmony\entry\build\default\outputs\default\entry-default-unsigned.hap`（381,350 字节，unsigned）；
纯逻辑层 23 个单元测试在本机直接跑通（无需设备）；界面按上游 Flutter 代码**1:1 复刻**（加载圈 / 错误页 /
全屏 Web 三态，无自绘标题栏与面板）；并已在**本机 HarmonyOS 7（API 26）模拟器**上装机跑通、逐项截图验证。

---

## 1. 交付物

| 交付物 | 路径 |
| --- | --- |
| 鸿蒙工程（可直接用 DevEco Studio 打开） | [`D:\dsh\Traccar\harmony`](harmony) |
| 应用 HAP（unsigned） | `D:\dsh\Traccar\harmony\entry\build\default\outputs\default\entry-default-unsigned.hap` |
| 端侧测试 HAP（hypium） | `D:\dsh\Traccar\harmony\entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap` |
| 工程说明 / 构建 / 验收清单 | [`harmony\README.md`](harmony/README.md) |
| 本机 SDK 能力清单（195 项 API 目录 + 关键签名） | [`SDK_API_INVENTORY.md`](SDK_API_INVENTORY.md) |
| API 26 新增能力全量扫描（4137 处 `@since 26`） | [`API26_WHAT_IS_NEW.md`](API26_WHAT_IS_NEW.md) |
| 上游源码（对照基准，depth 1，HEAD `af0bb3f`） | `D:\dsh\Traccar\upstream` |
| 模拟器验证截图（全屏 Web / 错误页 / 桌面图标） | [`shots`](shots)（`ui1.jpeg`、`ui3.jpeg`、`ui4.jpeg`、`home1.jpeg`） |
| 验证辅助工具（本地 Traccar 协议测试服务器、CDP 客户端） | [`tools`](tools)（`testserver.mjs`、`cdp.mjs`） |

源码规模：24 个 `.ets`、2562 行（不含测试）。

## 2. 完成了什么

**应用形态与上游一致**：原生外壳 + Traccar Web Manager 网页，外壳负责令牌加密存储、生物识别、
附件下载与分享、OAuth 深链回跳、地理定位/相机权限、推送令牌透传、返回键语义、错误页与服务器地址编辑。
包名与深链 scheme 沿用 `org.traccar.manager`，偏好键 `url` 与安全存储别名 `token` 也沿用以保证兼容。
**界面与上游 1:1**（详见 2.6）：界面里没有标题栏、没有刷新/菜单按钮、没有底部面板、没有宽屏分栏，
只有上游 `main_screen.dart` 的三种形态之一 —— 加载圈、错误页、全屏网页。

**逐条对齐的"必须等价"行为**（上游 `lib/main_screen.dart`）：

1. **JS↔原生协议**：网页侧仍是 `window.appInterface.postMessage('前缀|载荷')`，
   前缀 `login|` / `authentication` / `authenticated` / `logout` / `download|` / `server|` 一一对应；
   原生回调网页仍是 `updateNotificationToken` / `handleLoginToken` / `handleNativeNotification`。
   实现差异：原生代理注册名为 `__traccarNativeInterface`，注入脚本再把它包成网页侧稳定入口
   `window.appInterface`，从而保留上游那套"未就绪先入队、就绪后冲刷"的行为（否则脚本的懒解析会自环）。
2. **xlsx 导出拦截**：注入脚本同样改写 `URL.createObjectURL`，对
   `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` 的 Blob 用 FileReader 转
   base64 后发 `download|`，原生按上游固定文件名 `report.xlsx` 落盘并调分享面板。
3. **导航拦截四条规则（顺序即语义）**：OAuth 授权请求 → 跨站点外链 → 可下载附件（`xlsx/kml/csv/gpx`）
   → 放行；OAuth 那条把 redirect_uri 改写成自定义 scheme 后交外部浏览器，附件那条带
   `Authorization: Bearer <token>` 原生下载。
4. **深链回跳**：`host + pathSegments` 拼回服务器地址，带 `code` 时补 `redirect_uri`；
   返回键只在"服务器 origin 且路径是 `/` 或 `/login`"时退出应用。
5. **生物识别**：读取令牌前必须通过 UserAuthenticationKit（PIN/人脸/指纹，ATL2）；
   **取消或失败一律不放行**，不会把令牌交给网页。
6. **权限**：定位（精确+模糊同时申请）、相机（扫码/拍照上传）；网页申请任何非相机资源一律拒绝
   ——与上游一致（上游 Android manifest 里也没有麦克风权限）。
7. **错误页**：只在主框架加载失败时显示（忽略 CANCELLED 类错误码），可编辑服务器地址，
   提交前先删令牌、再重建 WebView；渲染进程崩溃自动重载。

**移植正确性护栏**：上述分支涉及的全部 URI 判断收敛进零依赖的
[`common/model/UriModel.ets`](harmony/entry/src/main/ets/common/model/UriModel.ets)，并由
[`entry/src/test/UriModel.test.ets`](harmony/entry/src/test/UriModel.test.ets) 的 13 个用例钉住，
其中包括"OAuth redirect 改写 → 深链回跳"的闭环不变量。另有 `BridgeScript.test.ets`（注入脚本的关键几行：
自环护栏、队列冲刷、xlsx 拦截）与 `Contract.test.ets`（与 Web 端/旧版 Flutter 之间的键名、消息前缀、
回调函数名契约），合计 23 个用例，全部在 PC 上运行，不需要设备。

## 2.5 静态审查与修正

移植完成后用子代理做了一轮逐行对照上游 Dart 的静态审查（30 条发现），严重与中等问题全部修掉，
其余作为"接受并记录的差异"写进 [`harmony\README.md`](harmony/README.md) 第 7 节。其中两条最值得记：

- **Web 组件曾写在 `if/else` 两个布局分支里**：ArkUI 的 `if/else` 是两棵子树，宽窄切换（旋转、折叠、
  分屏、2in1 拖窗口）会销毁并重建 Web，`onControllerAttached` 重跑、页面按陈旧的 `webSrc` 重新加载。
  已改为"左栏容器与 Web 兄弟顺序固定，只切换左栏宽度与可见性"。
- **跨站判定曾比较 origin（含 scheme）**：服务器填成 `http://…` 且 302 到 https 后，
  每个站内链接都会被判成跨站丢给系统浏览器。已改回上游语义，只比 authority（host:port）。

其余修正包括：错误页永不消失、`-10` 被误当用户取消、`onErrorReceive` 的 try 过宽、
桥消息异常重投（`server|` 有副作用）、生物识别无超时、输入框初值只取一次、推送令牌静默丢弃、
`DownloadHandler` 重复注册、下载只认 200、Asset 的 update/query 属性集、桥消息地址不校验等。

## 2.6 UI 1:1 复刻与图标修正

按需求「UI 界面需要 1:1 复刻原项目，图标底色应为白色」做了一轮**界面重做**（删掉的比加上的多）：

| 上游（Flutter） | 本轮改成 |
| --- | --- |
| `main_screen.dart` 的 `build` 三态：`!_settingsReady` → `Center(CircularProgressIndicator())`；`_loadingError != null` → `ErrorScreen`；否则 `PopScope → Scaffold(resizeToAvoidBottomInset:false) → SafeArea → InAppWebView` | `pages/Index.ets` 的 `build` 就是这三态（`Stack` + 三个 `@Builder`），**没有**自绘标题栏 / 刷新按钮 / ⋮ 菜单 / 底部操作面板 / 宽屏左栏 |
| `error_screen.dart`：`Icon(Icons.cloud_off, size: 96)` + `SizedBox(32)` + `Text(error, headlineSmall)` + `SizedBox(32)` + `TextField(OutlineInputBorder, suffixIcon: check)` | `views/components/ErrorScreen.ets`：`Image(cloud_off)` 96vp 染 `on_surface_variant` + `Text(24fp/行高32)` + `TextInput`（1vp `outline` 描边、4vp 圆角、`EnterKeyType.Go`）+ 内嵌 40vp 圆形 ✓ 按钮；非法地址 toast 文案就是上游那句 `Invalid URL` |
| `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue))` + `statusBarIconBrightness: dark ? light : dark` | `resources/base\|dark/element/color.json` 的 M3 blue-seed 11 色；`EntryAbility` 设窗口底色 `#F9F9FF/#1A1C1E` 与状态栏图标色 `#000000/#FFFFFF`，`onConfigurationUpdate` 跟随深浅色 |
| 图标：上游 `1024.png` 四角为**不透明白色**，主体是藏青圆盘（#1A237E） | `AppScope/.../background.png` 重生成为 1024×1024 纯白，`foreground.png` 保留原图圆盘（bbox (202,202,822,822)）⇒ 分层图标 = 白底 + 藏青圆盘 |

一并删除的旧实现：`ShellTitleBar.ets`、`ServerErrorView.ets`、`WideRail.ets`、`BreakpointManager.ets`、
`MaterialFx.ets`、`ImmersiveWindow.ets`，以及 `Keys.ets` / `ServerPrefs.ets` / `module.json5` 里只服务于
旧外壳的键与 metadata（`shareAfterDownload`、宽屏/插图键、`ohos.arkui.UIMaterial.state`）。
改造后 HAP 由 493,870 字节降到 **379,485 字节**（修掉 download 落盘缺陷后为 381,350 字节），本地单测 23 例仍全绿。

## 3. 用到的鸿蒙 7（API 26）新特性

| 特性 | 落地方式 |
| --- | --- |
| **沉浸键盘** ArkWeb `keyboardAppearance(WebKeyboardAppearanceMode.IMMERSIVE)`（26 新增枚举） | 网页内输入时键盘呈沉浸样式，不再把页面顶成两截 |
| **通知设置回读** `notificationManager.openNotificationSettingsWithResult()`（26 新增） | 跳系统通知设置并读回开关状态 |
| 构建基线 | `compatibleSdkVersion` / `targetSdkVersion` 均为 `26.0.0`、`runtimeOS: "HarmonyOS"`（HarmonyOS 7 = API 26） |

**刻意未用**（都核对过签名，但不合"1:1 复刻"或本机无法回归）：
`@ohos.arkui.uiMaterial` 沉浸光感与 HDS 材质（界面里已没有可承载材质的自绘面板；且 HDS 的
`TitleBarStyleOptions` 等类型在本机 SDK 没有 `.d.ts`，引用会编译失败）、`@ohos.window.floatView`
闪控窗/闪控球（上游没有常驻悬浮窗形态）、`webview.setErrorPageEnabled`（自绘错误页才保有"编辑服务器
地址"的能力；该方法实为实例方法且 `@since 20`）、`geoLocationManager` 26 新增函数、互动卡片（Form）。

## 4. 多端适配

界面与上游 1:1，因此多端适配落在窗口与系统栏这一层，同一份布局在手机 / 平板 / 2in1 通用：

- `deviceTypes: ["phone", "tablet", "2in1"]`（测试模块同）；`Web` 宽高 100%，加载圈与错误页屏幕居中；
- 不做沉浸式全屏，只设窗口底色 + 状态栏/导航条图标明暗（随系统深浅色，`onConfigurationUpdate` 同步）；
- 2in1 上跳过 `setWindowSystemBarProperties`（该 API 在 2in1 不可用），仅保留窗口底色；
- 深浅色两套颜色资源（`resources/base` 与 `resources/dark` 同名同集合）；
- 旋转 / 折叠 / 分屏 / 2in1 拖窗口都不重建页面（Web 是 build 树里的固定节点）。

## 5. 验证情况

**已在 HarmonyOS 7 模拟器（Mate 90 Pro，API 26，1280×2832）上实测**，未签名 HAP 直接
`hdc install -r` 即可安装：

- 全屏网页：无标题栏、无按钮，Web 从状态栏下方铺满，状态栏图标为深色（`shots/ui1.jpeg`）；
- 错误页：`cloud_off` 96 + 内核错误文本（`ERR_TIMED_OUT`）+ 预填当前地址的 Outlined 输入框 + ✓ 按钮（`shots/ui3.jpeg`）；点 ✓ 重新加载成功（`shots/ui4.jpeg`）；
- 桌面图标：白底 + 藏青圆盘（`shots/home1.jpeg`）；
- JS↔原生双向桥：页面探针 `native=object appInterface=object installed=true`；`server|<url>` 写盘生效
  （沙箱 preferences）、`logout` 清 cookie、`authentication` 在 23ms 后收到原生回调 `handleLoginToken("")`；
- 构建与单测：`assembleHap` 与 `hvigorw test` 均 `BUILD SUCCESSFUL`，23/23 通过；
- 令牌与导出：`login|<token>` 落 AssetStoreKit（`token updated` / `login token stored`）；
  `download|<base64>` 落盘 13 字节并弹出系统分享面板（`shots/ui10.jpeg`，含本节下载目录缺陷的修复）。

**模拟器上两条曾被误判为失败的路径，已查清**：早先"`login|`/`download|` 无任何日志与落盘痕迹"的结论是
**日志采集假象**——`hilog` 流式输出会丢行（连必然执行的 `bridge in` 都不出现），权威日志是设备上按分钟轮转的
`/data/log/hilog/hilog.*.gz`（用 `tools/hilogscan.mjs` 扫描）。据此复核后：

- `login|<token>` 正常：`bridge in` → `onLoginToken` → `token save start` → `token updated` / `login token stored`（AssetStoreKit）；
- `download|<base64>` 确有缺陷并**已修复**：`file write failed | path=…/cache/downloads/report.xlsx code=13900002
  msg=No such file or directory`，根因是 `fileIo.accessSync()` 对不存在的目录不抛异常，导致 `mkdirSync` 分支
  永不执行。现在改为「无条件 `mkdirSync`（忽略 EEXIST）→ `listFileSync` 复核 → 失败兜底 `cacheDir` 根」，
  实测 `file written | report.xlsx 13B` + `share panel shown | report.xlsx`，沙箱内文件 13 字节，
  系统分享面板见 `shots/ui10.jpeg`；含修复的 HAP 381,350 字节；
- 模拟器**没有 WebGL/WebGL2**，真实 Traccar Web 前端会停在自带 loader
  （`GPUInitializationError: WebGL2 is required to display this map`），所以壳层验证一律用
  `tools/testserver.mjs`（自带桥接探针）+ `tools/cdp.mjs` 驱动。用户指定的联调服务器是
  **`http://192.168.31.52:8082`**（Traccar 6.16.0，宿主 curl 200 / 模拟器 ping 通，应用内能取到页面与 JS，
  但渲染同样受模拟器无 WebGL 限制，见 `shots/ui11.jpeg`）。

其他已知限制：Push Kit 需要 AGC 项目（未配置，代码里静默降级，不影响登录等主流程）；上游的
`rate_my_app` 启动评分弹窗与 Firebase 埋点在鸿蒙没有对应实现；生物识别、相机/定位权限弹窗、
Share Kit 面板与"用其他应用打开"仍需真机回归（模拟器无生物识别硬件）。

## 6. 建议的下一步

1. 用 DevEco Studio 自动签名后装到手机/平板（如有 2in1 也各跑一遍），按 README 第 6 节的清单过一遍；
2. 真机回归模拟器无法覆盖的路径：生物识别成功（拿到真实令牌）、相机/定位权限弹窗、Share Kit 面板交互、
   2in1 与折叠屏窗口形态；
3. 接 AGC 项目，把 `client_id`/`app_id` 写进 `module.json5` metadata，打通推送（含点通知跳到 `event/<id>`）；
4. 若要"全场景"加分项，再补 `floatView` 闪控窗（实时显示设备在线状态）与互动卡片，
   两者都需要额外的模板/ExtensionAbility，且与"1:1 复刻上游界面"的目标相冲突，建议与需求方确认后再做。
