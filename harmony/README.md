# Traccar Manager · HarmonyOS 版

Flutter 版 [traccar-manager](https://github.com/traccar/traccar-manager)（上游 HEAD `af0bb3f`，version 6.1.2+82）
到 **HarmonyOS 7（API 26）原生 ArkTS** 的移植。应用形态与上游一致：一个加载 Traccar Web Manager 的
原生外壳，负责令牌安全存储、生物识别、附件下载与分享、深链回跳、地理定位/相机权限、推送令牌透传。

- 包名 / deep link scheme：`org.traccar.manager`（与上游一致，保证 Web 端跳转配置不用改）
- 偏好键：`url`（服务器地址）；安全存储别名：`token`（与上游一致，从 Flutter 版升级不丢配置）
- 默认服务器：`https://demo.traccar.org`

## 1. 目录结构

```
entry/src/main/ets/
├── common/
│   ├── constants/TraccarConstants.ets   上游常量集中处（默认服务器、消息前缀、JS 函数名、可下载后缀、OAuth 参数）
│   ├── model/UriModel.ets               URI 解析/拼接纯函数层（零依赖，可无设备单测）——替代 Dart 的 Uri
│   └── utils/                           Keys(存储键) / Log / Toast
├── entryability/EntryAbility.ets        UIAbility：初始化 Web 内核、窗口底色与状态栏明暗、注入深链、接续(continuation)
├── entrybackupability/                 备份扩展
├── pages/Index.ets                      唯一页面：加载圈 → 错误页 → 全屏 Web（与上游三态 1:1，无任何自绘栏）
├── services/
│   ├── auth/BiometricGate.ets           UserAuthenticationKit，读令牌前做生物识别
│   ├── download/DownloadService.ets     带 Bearer 令牌下载、base64 落盘、缓存清理
│   ├── download/ShareService.ets        Share Kit 分享面板 / viewData 打开
│   ├── navigation/ExternalLinks.ets     外链交给系统浏览器（openLink → viewData → 复制链接兜底）
│   ├── navigation/DeepLinkRouter.ets    深链"邮箱"：Ability 收到 → AppStorage 传 → 页面消费
│   ├── notification/NotificationHelper.ets  通知开关查询/请求/跳设置
│   ├── notification/PushTokens.ets      Push Kit 令牌与消息（无 AGC 凭据时静默降级）
│   ├── storage/ServerPrefs.ets          preferences 封装
│   ├── storage/TokenStore.ets           AssetStoreKit 封装（令牌加密存储）
│   └── web/                             AppPermissions / WebSessionManager / BridgeScript /
│                                        TraccarBridge / BridgeHostAdapter / DownloadHandler
└── views/components/ErrorScreen.ets     错误页（cloud_off 图标 + 错误文本 + Outlined 地址输入框 + ✓ 提交）
```

24 个 `.ets` 源文件、2802 行（不含测试）。**界面是上游 `lib/*.dart` 的逐像素复刻**：
没有标题栏、没有刷新/菜单按钮、没有底部面板、没有宽屏分栏 —— 上游 `main_screen.dart` 的 `build`
只有「加载圈 / ErrorScreen / 全屏 InAppWebView」三态，本工程照此实现（见第 4 节）。

## 2. 构建

```powershell
$env:DEVECO_SDK_HOME = "C:\Program Files\Huawei\DevEco Studio\sdk"
$hw = "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat"
Set-Location D:\dsh\Traccar\harmony

# 主应用（release 加 -p buildMode=release）
& $hw assembleHap --mode module -p product=default --no-daemon
# → entry\build\default\outputs\default\entry-default-unsigned.hap

# 本地单元测试（在 PC 上跑，不需要设备/模拟器）
& $hw --mode module -p module=entry@default -p product=default test --no-daemon
# → 每个 .test.ets 的用例逐个执行并产出 html 报告

# 端侧测试包（装到设备上跑 hypium，需要签名）
& $hw --mode module -p module=entry@ohosTest -p product=default assembleHap --no-daemon
# → entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap
```

关键工程约定（照抄自同机可用的 `D:\dsh\ArkDO`，踩过的坑见文末）：

- `build-profile.json5`：`targetSdkVersion` / `compatibleSdkVersion` 必须是**纯点分串 `"26.0.0"`**
  （API 26 起写 `"26.0.0(26)"` 会报 `api version parameter is illegal`）；`signingConfigs` 留空，
  产物即 `*-unsigned.hap`；`runtimeOS: "HarmonyOS"`。
- `oh-package.json5` / `hvigor/hvigor-config.json5`：`modelVersion: "6.0.2"`（hvigor 6.26.8）。
- `entry/oh-package.json5` **必须存在**：缺它会让 hvigor 在写模块依赖映射时抛
  `ERR_INVALID_ARG_TYPE ... Received undefined`（错误码 00308018）。
- hvigor 的彩色输出会被 PowerShell 当成错误流，看到 `[exit code: 1]` 不代表失败，
  要看 `BUILD SUCCESSFUL` 与产物时间戳。

### 装到设备上

本机没有签名证书，因此只能产出 unsigned HAP。装机走 DevEco Studio 自动签名：

1. DevEco Studio 打开 `D:\dsh\Traccar\harmony`；
2. `File > Project Structure > Signing Configs` 勾选 **Automatically generate signature**（需登录华为账号）；
3. 直接 Run 到手机 / 平板 / 2in1，或 `Build > Build Hap(s)` 后 `hdc install`。

## 3. 与上游的行为对照

| 上游（Flutter） | 本工程实现 |
| --- | --- |
| `flutter_inappwebview` | ArkWeb `Web` + `WebviewController`（`pages/Index.ets`） |
| 注入脚本 `AT_DOCUMENT_START` | `javaScriptOnDocumentStart` + `services/web/BridgeScript.ets` |
| `callHandler('appInterface')` | `javaScriptProxy` 注册 `__traccarNativeInterface`，注入脚本再把它包成网页侧稳定入口 `window.appInterface` |
| `SharedPreferences('url')` | `preferences`（`ServerPrefs`，键名保持一致） |
| `FlutterSecureStorage('token')` | AssetStoreKit `asset`（`TokenStore`，别名保持一致） |
| `local_auth` | UserAuthenticationKit `userAuth`（`BiometricGate`）+ `ohos.permission.ACCESS_BIOMETRIC` |
| `firebase_messaging` | Push Kit `pushService`（令牌 + 消息）与 `notificationManager` |
| `url_launcher(externalApplication)` | `UIAbilityContext.openLink` → viewData want → 复制链接兜底 |
| `share_plus` | Share Kit `systemShare.ShareController` |
| `http` + `path_provider` | `@ohos.net.http` + `context.cacheDir/downloads` |
| `permission_handler` | `abilityAccessCtrl.requestPermissionsFromUser`（定位必须同时申请精确+模糊） |
| `app_links` 深链 | ability `skills` 注册 scheme + `want.uri` → `DeepLinkRouter` → 页面加载 |
| WebView 文件选择 | `onShowFileSelector` + `PhotoViewPicker` / `DocumentViewPicker` |
| `PopScope(canPop:false)` | `onBackPress(): boolean`（true = 自己消费） |
| `SafeArea(maintainBottomViewPadding:true)` | 不设沉浸式全屏、不加自绘安全区：`Web` 直接铺满窗口内容区，系统栏照常占位（与上游一致） |
| `Icon(Icons.cloud_off, size:96)` | `Image($r('app.media.cloud_off')).width/height(96vp).fillColor(on_surface_variant)` |
| `TextField(border: OutlineInputBorder)` | `TextInput` + `borderWidth(1)` + `borderRadius(4vp)`，`outline` 描边 |
| `Icon(Icons.check)` 作为 `suffixIcon` | `Stack(alignContent: End)` 里的 40vp 圆形按钮 + `check.svg`（24vp，`on_surface_variant` 染色） |
| `ColorScheme.fromSeed(Colors.blue)` | `resources/base|dark/element/color.json` 的 M3 blue-seed 11 色（surface / primary / outline / error…） |
| `rate_my_app` | **未实现**：鸿蒙没有等价的应用内评分弹窗 API |

移植正确性的基准是上游 `lib/main_screen.dart` 的四个分支，全部收敛进 `UriModel` 并有单测钉住：

- `shouldOverrideUrlLoading` 的四条规则（**顺序即语义**）：OAuth 授权请求 → 跨站点外链 → 可下载附件 → 放行；
- `_launchAuthorizeRequest`：丢掉 redirect_uri 的原 host，把**第一段路径**当作自定义 scheme 的 host，query 原样搬；
- `uriLinkStream`：`host + pathSegments` 拼回服务器地址，带 `code` 时补 `redirect_uri`；
- `PopScope`：只有"仍在服务器 origin 且路径是 `/` 或 `/login`"时才退出应用。

## 4. 用到的 HarmonyOS 7（API 26）新特性

| 特性 | 用法 | 位置 |
| --- | --- | --- |
| 沉浸键盘 | ArkWeb `keyboardAppearance(WebKeyboardAppearanceMode.IMMERSIVE)`（26 新增枚举） | `pages/Index.ets` |
| 通知设置回读 | `notificationManager.openNotificationSettingsWithResult(context)`（26 新增） | `services/notification/NotificationHelper.ets` |
| 全局最小 API | `compatibleSdkVersion` / `targetSdkVersion` 都是 `26.0.0`，`runtimeOS: "HarmonyOS"` | `build-profile.json5` |

UI 层面**只用了一个** 7.0 新特性：沉浸键盘。原因是 7.0 的空间化/沉浸光感（`@ohos.arkui.uiMaterial`、
HDS 材质）都要挂在自绘材质面板上，而「1:1 复刻上游」要求界面里根本没有这类面板——所以沉浸光感的
`.systemMaterial()` 与 `module.json5` 的 `ohos.arkui.UIMaterial.state` metadata 都已随自绘外壳一起删除
（保留反而会让 Web 之外的空白区域出现上游没有的材质）。

**刻意没用的 26 新能力**（都核对过签名，但不落进这份移植里）：

- `@ohos.arkui.uiMaterial` / `HdsNavigation` 沉浸光感：界面已 1:1 复刻上游，没有可承载材质的自绘面板；
  另外 `TitleBarStyleOptions` 等 HDS 类型在本机 SDK 里没有 `.d.ts`（只有编译期组件描述），引用会编译失败；
- `@ohos.window.floatView` 闪控窗/闪控球：上游没有常驻悬浮窗形态，加了就是新增功能而非移植；
- `webview.setErrorPageEnabled(enable, includeSubframe)`：本工程要的是上游那套自绘 ErrorScreen，
  用内核错误页会把"可编辑服务器地址"的能力丢掉（该方法其实是 `WebviewController` 的实例方法、`@since 20`）；
- `geoLocationManager` 26 新增函数：Web 端定位由 ArkWeb 的 `onGeolocationShow` 驱动，够用；
- 互动卡片（Form）：API 26 对 Form 无任何新增，且卡片需要独立的 FormExtensionAbility，本轮不做
  （已删除上一轮遗留的 `form_config.json`，避免留下未被引用的资源）。

## 5. 多端适配

界面既然与上游 1:1，就没有断点/分栏可言——多端适配落在"窗口与系统栏"这一层：

- `module.json5` 的 `deviceTypes: ["phone", "tablet", "2in1"]`（`ohosTest/module.json5` 同），
  同一份布局在三端通用：`Web` 宽高 100%，加载圈与错误页都是屏幕居中；
- `EntryAbility` 不做沉浸式全屏，只设窗口底色 + 系统栏图标明暗，跟随系统深浅色：
  `setWindowBackgroundColor('#F9F9FF' | '#1A1C1E')` 与 `setWindowSystemBarProperties({statusBarContentColor,
  navigationBarContentColor})`（暗色 `#FFFFFF` / 亮色 `#000000`，对应上游 `statusBarIconBrightness: dark?light:dark`），
  并在 `onConfigurationUpdate` 里跟随深浅色切换；
- 2in1 上跳过 `setWindowSystemBarProperties`（该 API 在 2in1 不可用），只保留窗口底色；
- 深浅色两套 `color.json`（`resources/base` 与 `resources/dark` 同名同集合），取值即 Flutter M3
  `ColorScheme.fromSeed(Colors.blue)` 的 token；
- 旋转/折叠/分屏/2in1 拖窗口都不触发页面重建（Web 是 build 树里的固定节点，不受尺寸变化影响）。

## 6. 测试与验证

- 本地单测（不需要设备，`hvigorw ... test` 直接跑；1:1 改造后仍全绿：`BUILD SUCCESSFUL`、无 `ERROR: Error in`）：
  - `entry/src/test/UriModel.test.ets`（13 例）：URI 解析、服务器地址校验、下载后缀白名单、
    OAuth redirect 改写与**改写-回跳闭环**、深链拼回服务器地址、返回键退出判定；
  - `entry/src/test/BridgeScript.test.ets`（5 例）：注入脚本幂等安装、自环护栏、队列冲刷、
    xlsx Blob 拦截、代理方法名；
  - `entry/src/test/Contract.test.ets`（5 例）：`url`/`token` 键名、默认服务器、六个消息前缀、
    三个 JS 回调名、OAuth 参数、30s 超时；
- 端侧测试包：`entry/src/ohosTest`（常量契约），需签名与设备；
- **模拟器实机验证**见第 10 节（已在本机 HarmonyOS 7 模拟器上跑通并留了截图）。

### 手工验收清单（拿到真机后按序走一遍）

1. 首启加载 `demo.traccar.org`：先是屏幕中央的系统加载圈，随后**直接**是全屏 Web —— 没有标题栏、
   没有刷新/菜单按钮、没有底部面板；
2. 登录成功后 Web 端写入令牌 → 重启应用仍免登录；
3. 需要令牌时弹生物识别（指纹/人脸/PIN），**取消后不得自动登录**；
4. 报表导出 xlsx → 原生下载 → 系统分享面板弹出（文件名 `<时间戳>.xlsx`）；Web 端 `download|<base64>`
   走同一路径，文件名固定 `report.xlsx`；
5. 外部浏览器完成 OAuth 后经 `org.traccar.manager://…` 回跳，落地路径与授权前一致（不进入死循环）；
6. 返回键：服务器首页/登录页退出应用，其它页面回退；
7. 权限：地图显示当前位置（定位弹窗）；扫码/拍照上传走相机权限；网页申请麦克风应被拒绝
   （上游只放行 `VIDEO_CAPTURE`/`CAMERA`）；
8. 错误页：服务器不可达 → `cloud_off` 图标 + 内核错误文本 + 地址输入框（预填当前地址）；点 ✓ 重新加载，
   填非法地址提示 `Invalid URL`；
9. 多端：平板横竖屏、折叠展开、2in1 拖窗口 —— Web 不重载、不出现分栏；
10. 通知：首次登录后请求通知开关，"通知设置"能跳到系统设置并读回结果；
11. 深色/浅色切换：窗口底色与状态栏图标明暗跟随（界面本身不含自绘材质）。

## 7. 静态审查与修正

移植完成后做了一轮逐行对照上游的静态审查（30 条发现），严重/中等问题已全部修掉：

| 问题 | 处理 |
| --- | --- |
| **Web 组件写在 `if/else` 两个分支里**：宽窄切换（旋转、折叠、分屏、2in1 拖窗口）会销毁重建 Web，整页跳回初始地址 | 1:1 复刻后该结构已不存在：build 树里 Web 是固定节点，只在「加载圈 / 错误页 / Web」之间切换三态 |
| **`loadingError` 一旦置位永不清除**：错误页永久盖住 Web | `onPageBegin` 里清空（对应上游 `onLoadStart` 清 `_loadingError`） |
| **跨站判定比 origin（含 scheme）**：服务器填成 `http://` 且 302 到 https 后，站内链接全被丢给外部浏览器 | 改回上游语义：只比 authority（host:port） |
| `-10`（ERR_ACCESS_DENIED）被当成"用户取消"而忽略 | 从忽略列表移除，只留 -3 / -999 / 102 |
| `onErrorReceive` 的 try 过宽，异常被吞导致错误页永不出现 | 拆开异常处理；取不到错误信息也给出通用错误页 |
| 桥接消息在原生 `postMessage` 抛异常时重投，最多重复 40 次（`server|` 有清令牌等副作用） | 异常不再重投（只记录）；队列只负责"原生未就绪"这一种情况，宽限期 4s → 30s |
| 生物识别 Promise 无超时，系统不回调就永久挂起 | 加 60s 超时兜底，超时按未通过处理（绝不放行） |
| `ServerErrorView` 的输入框初值只取一次，编辑器可能显示旧地址 | `@Prop @Watch` 同步（用户已编辑时不覆盖输入）——该组件现为 `views/components/ErrorScreen.ets` |
| 推送令牌在 controller 未附着时被静默丢弃 | 加 `pendingPushToken`，`onControllerAttached` 后补发 |
| 推送令牌/事件/消息三个 sink 只清了一个 | 加 `detachSinks()`，`aboutToDisappear` 统一清理 |
| `DownloadHandler` 每次附着都新建（叠加 Web 重建会重复注册 delegate） | 复用单实例；并在附着时先确保下载目录存在 |
| 下载只认 200，带 `Accept: */*` 时 206/304 被判失败 | 接受 2xx |
| 下载后缀从整个 URL 取（`?deviceId=1.5` 会被当后缀） | 改用 `UriModel.lastPathSegment` |
| 桥消息 `server|` 不校验地址合法性（与错误页路径不一致） | 非法地址只提示、不切换 |
| 错误页与服务器编辑器可能同时叠加 | 三态互斥渲染：`loadingError` 非空时只渲染 `ErrorScreen` |
| `TokenStore` 的 `update` 把 ALIAS 混进更新集、查询条件带 ACCESSIBILITY | 更新集只放 SECRET；查询/删除只按 ALIAS 定位 |
| `progressLabel` 死代码 | 删除 |
| 冷启动点通知无路由、`handleNativeNotification` 从未被调用 | `EntryAbility` 解析 `want.parameters['eventId']` 跳 `<服务器>/event/<id>`；前台推送把整条数据交给 Web 的 `handleNativeNotification` 并 toast 正文 |

**接受并记录的差异**（不修，理由如下）：

- 注入规则仍为 `'*'`（覆盖所有 frame）：跨域 iframe 里拿不到原生代理，只会在 4 秒后静默丢弃自己的消息，对主框架无影响；若限制成主框架，同源 iframe 内的桥会一起失效，风险更大。
- 下载目录用 `cacheDir/downloads`（上游用文档目录/外部存储）：系统低存储时可能清理；分享期间清缓存确实可能删掉正在分享的文件，需要真机验证后再决定是否改到 `filesDir`。
- 分享与"用其他应用打开"两条路径的授权模型不同（前者靠 Share Kit 授权，后者显式带 `FLAG_AUTH_READ_URI_PERMISSION`），需真机确认被拉起方能读到文件。
- `ExternalLinks` 的兜底会写系统剪贴板（上游只记日志）：更主动但有副作用（覆盖用户剪贴板），保留但在验收清单里确认。
- 宽屏设备不再有"首帧先按窄屏渲染再切宽屏"的问题（自绘断点系统 `BreakpointManager` 已随 1:1 复刻删除）。
- `AUTHENTICATED_TIMEOUT_MS`（上游等 `authenticated` 的 30s 超时）未使用：本工程的推送注册不依赖 Web 的 `authenticated`，令牌回填由 `pendingPushToken` 兜住。
- Push Kit 只声明了 `off('tokenUpdate')`，`receiveMessage` 没有对应 off，消息订阅无法解绑；因此 `PushTokens.attach` 用「同一 ability 实例只注册一次」的守卫。
- `authenticated` 在本工程是可复位的状态（上游是一次性 Completer）：登出会置 false，语义差异已知。

## 8. 已知限制

- **无签名证书**：本机只能产出 `entry-default-unsigned.hap`（构建日志里的
  `WARN: No signingConfig found for product default` 是预期）；
- **只有模拟器，没有真机**：HAP 已装机跑通（见第 10 节），但以下仍需真机各花几分钟确认 ——
  生物识别（模拟器无指纹/人脸/锁屏口令）、推送（需 AGC 与真机）、Share Kit 面板与"用其他应用打开"的
  授权结果、相机/定位的运行时权限弹窗、内核 4xx/5xx 是否触发 `onErrorReceive`、
  重复 `setDownloadDelegate` 的实际语义；
- **模拟器没有 WebGL/WebGL2（根因已定位，应用侧无法解决）**：真正的 Traccar Web 前端（含地图）在
  模拟器上必然停在它自带的 loader（控制台抛 `GPUInitializationError: WebGL2 is required to display
  this map`）。CDP 探针显示 `WebGLRenderingContext`/`WebGL2RenderingContext` 构造函数存在、
  `WebAssembly` 也可用（⇒ 不是「坚盾守护模式」——该模式会同时禁掉 WebGL 与 WebAssembly/JIT），
  但 `canvas.getContext('webgl')`/`('webgl2')` 都返回 `null`；hilog 里 ArkWeb 的 GL 上下文起不来
  （`C02515/DGLES: createimage with ctx null opengl_context`、`eglCreateSync ... 0x3009
  (EGL_BAD_MATCH)`、`A04500/chromium: vulkan switch config is: 0, cmd is: false`），guest 内也没有
  GPU 设备节点（`/dev/dri`、`/dev/mali0`、`/dev/kgsl-3d0`、`/dev/gpu` 均不存在）。模拟器与 SDK 都没有
  开 WebGL 的开关（`emulator.json`/`productConfig.json`/实例 `config.ini`/`Emulator.exe -help` 无图形项；
  SDK 只有 `SecurityParams.disableWebGL`，默认已是开启）。⇒ **地图必须在真机验证**，壳层验证一律
  用 `tools/testserver.mjs`（见第 10 节）；
- **Push Kit 未接 AGC**：`pushService.getToken()` 在没有 AGC 项目时失败，代码里静默降级为空串
  （登录、下载、通知开关都不受影响，只是收不到推送）；要真正收推送需在 AGC 建项目并把
  `client_id`/`app_id` 写进 `module.json5` 的 metadata；
- **应用图标**取上游 iOS 的 1024 素材：`foreground.png` 是原图圆盘（透明底），`background.png` 是**纯白**
  1024×1024 —— 合成结果与上游一致（白底 + 藏青圆盘）。原素材圆盘只有 620/1024（占画布 61%），
  桌面渲染出来只有 tile 宽度的 **0.53**、明显偏小；现按 82% 重排（圆盘 840/1024，bbox (92,92,932,932)），
  桌面实测 tile 宽度的 **0.71**（用 `tools/measure_icon.py` 量 `shots/home1.jpeg` 与 `shots/icon3.jpeg`：
  圆盘 99px → 133px）。三张派生图同比例重生成：`AppScope/.../foreground.png`（1024）、
  `entry/.../media/app_icon.png`（216，白底，圆盘 177）、`base|dark/media/startIcon.png`（512，白底，圆盘 420），
  都由 `tools/resize_icon.py`（Pillow，改 `DISC_NEW` 即可换尺寸）生成，改完须重建重装才生效；
- 上游的启动评分弹窗（`rate_my_app`）与 Firebase Analytics/Crashlytics 埋点没有对应实现。

## 9. 踩过的坑（避免重复排查）

- 缺 `entry/oh-package.json5` → hvigor 报 `00308018 ... Received undefined`；
- `/oh-package.json5` 的 `modelVersion` 与 hvigor 版本不匹配会在依赖解析阶段就失败；
- `asset.update()` 是 `(query, attributesToUpdate)` 两个参数；`Tag.SECRET`/`Tag.ALIAS` 只能传
  `Uint8Array`（`Value = boolean | number | Uint8Array`，没有 string）；
- `userAuth` 的 `on('result', …)` 只接受 `IAuthCallback` **对象**，传函数会报
  `No overload matches this call`；
- `PermissionRequestResult` 是 `@ohos.abilityAccessCtrl` 内部的类型别名，@kit barrel 取不到，
  显式标注会报 `Cannot find name`，交给类型推断即可；
- `HDS Navigation`（`@kit.UIDesignKit`）在本机 SDK 只有编译期组件描述、没有 `.d.ts`，
  引用 `TitleBarStyleOptions` 之类类型会直接编译失败（1:1 复刻后本工程不再需要 HDS）；
- **ArkWeb `Web({src})` 的 `src` 只在组件创建时生效**：切服务器必须 `controller.loadUrl()`，
  改 `@State webSrc` 不会重新加载（`handleServerChange` 因此显式调 `loadUrl`，失败才回落改 `src` 重建）；
- PowerShell 默认按 GBK 解码，用 `Get-Content` 读 UTF-8 的 `.ets` 会把中文注释显示成乱码
  （文件没坏，用编辑器/read 工具看）。

## 10. 模拟器验证记录（HarmonyOS 7 / API 26 手机镜像）

环境：`Emulator.exe -start "Mate 90 Pro"`（HarmonyOS 7.0.0.107(SP8)，apiVersion 26，1280×2832）；
**未签名 HAP 可直接 `hdc install -r`**，无需证书。启动方式要注意：用 harness 的后台 job 启动模拟器，
job 结束会被一起杀掉（`crash_server.log` 里 `KillEmulator`），要用 `Win32_Process.Create` 脱离 job 启动。

**测试服务器（用户指定）**：本项目统一用 **`http://192.168.31.52:8082`**（局域网真实 Traccar 6.16.0，
`forceSettings: true`，`map: bingRoad`）。宿主 `curl` 200（~7ms）、模拟器 `ping` 通（~2ms），应用内
设置该地址后 Web 能从服务器取到页面与 JS（`location.href` 与 `assets/index-CkawVTbO.js` 均已加载）。
但真实 Traccar Web 前端在模拟器上仍会停在自带 loader：ArkWeb 没有 WebGL/WebGL2，主 bundle 抛
`GPUInitializationError: WebGL2 is required to display this map`（截图 `shots/ui11.jpeg` 即该 loader）。
因此**壳层/桥接/下载**类验证继续用本地 `tools/testserver.mjs` 代理页（`shots/ui4.jpeg` 等），
真实前端的渲染与登录需要真机。

| # | 截图（相对 `D:\dsh\Traccar`） | 验证到的行为 |
| --- | --- | --- |
| 1 | `shots/tc6.jpeg`（1:1 改造**前**） | 那时是自绘外壳：标题栏 `Traccar Harmony Test / 未登录 · <url>` + 返回/刷新/⋮ 按钮 |
| 2 | `shots/ui1.jpeg`（改造**后**） | 全屏 Web：**没有标题栏、没有任何按钮**，Web 从状态栏下方直接铺满；状态栏图标为深色（浅色底） |
| 3 | `shots/ui3.jpeg` | 错误页 = 上游 `error_screen.dart`：居中 `cloud_off` 96 + 错误文本（内核原文 `ERR_TIMED_OUT`） + Outlined 地址框（预填当前地址） + 内嵌 ✓ 按钮 |
| 4 | `shots/ui4.jpeg` | 错误页点 ✓ → 重新加载成功（测试服务器换到 9999 端口后页面正常渲染） |
| 5 | `shots/home1.jpeg` → `shots/icon3.jpeg` | 桌面图标：**白底** + 藏青圆盘；圆盘已从 tile 宽度的 0.53 放大到 0.71（840/1024 画布），与系统图标的内圈比例相当 |

同一轮验证还确认了（无截图，靠日志/沙箱取证）：

- **JS → 原生**：`window.appInterface.postMessage('server|http://10.0.2.2:8899')` 生效并写盘
  （沙箱 `preferences/traccar_manager_settings` 里 `<string key="url">…8899</string>`），
  `logout` 触发 cookie 清理，`authentication` 让原生在 23ms 后回调 `window.handleLoginToken("")`；
- **原生 → JS**：注入脚本与 `javaScriptProxy` 双双生效（页面内探针 `native=object appInterface=object
  installed=true`，UA 里带 `TraccarManagerHarmony/1.0.1`）；
- **模拟器限制**：真实 Traccar Web 前端因 `WebGL2 is required to display this map` 停在自带 loader
  （模拟器无 GPU/WebGL），因此壳层验证一律改用 `tools/testserver.mjs`（自带探针 + 8 个桥接按钮 +
  `/report` 回传），宿主侧用 `tools/cdp.mjs`（CDP over `hdc fport tcp:9224
  localabstract:webview_devtools_remote_<apppid>`）驱动页面；
- **原生侧取证方法（重要教训）**：`hilog` 的流式输出（`hilog -D 0x0FFF -L D > file`）在模拟器上**会丢行**
  ——连 `bridge in`、`onControllerAttached` 这类必然执行的行也经常不出现，据此判断"处理器没跑"是错的。
  权威日志是设备上按分钟轮转的 `/data/log/hilog/hilog.*.gz`：`hdc file recv` 拉回来，
  `node tools/hilogscan.mjs <file.gz…>`（自动 gunzip + 过滤 `A00fff/TraccarManager`）才能看到全量。
- **`login|<token>`（AssetStoreKit 落盘）已验证**：`bridge in | len=18` → `onLoginToken | len=12` →
  `token save start | len=12` → `token updated` / `login token stored`（`TokenStore` 首次 `asset.add`，
  已存在走 `DUPLICATED` → `asset.update`）。
- **`download|<base64>` 落盘 + 分享已修复并验证**：
  - 修复前现场：`E TraccarManager: file write failed | path=/data/storage/el2/base/haps/entry/cache/downloads/report.xlsx code=13900002 msg=No such file or directory`——下载目录从未被创建；
  - 根因：`DownloadService.downloadDir()` 用 `fileIo.accessSync(dir)` 判断目录是否存在，而在这台设备上
    **`accessSync` 对不存在的目录不抛异常**，于是 `mkdirSync` 分支永不执行，`openSync(..., CREATE)` 直接 ENOENT；
  - 修复（`entry/src/main/ets/services/download/DownloadService.ets`）：改为「无条件 `mkdirSync(dir, true)`
    （已存在抛 `13900015 File exists`，忽略）→ `listFileSync(dir)` 复核」，复核仍失败再兜底写 `context.cacheDir` 根；
  - 修复后日志：`download dir mkdir skipped | code=13900015 msg=File exists` → `file written | report.xlsx 13B`
    → `share panel shown | report.xlsx`；沙箱内确有
    `/data/app/el2/100/base/org.traccar.manager/haps/entry/cache/downloads/report.xlsx`（13 字节 = `hello,traccar`）；
    系统分享面板见 `shots/ui10.jpeg`（`report.xlsx 13 B` + 华为分享/复制/另存为/打印/添加到中转站）；
  - 含此修复的 HAP 381,350 字节（10-12 18:56:27）；再经静态审查修正、图标重排与窗口全屏布局后为当前
    **385,961 字节**（10-13 14:49，`BUILD SUCCESSFUL`，单测 23 例全绿；应用版本已统一为
    `versionName 1.0.1` / `versionCode 10001`，见 `AppScope/app.json5`）。
- **`authentication`（读令牌 + 生物识别）在模拟器上的正确表现**：`user auth rejected | code=12500010`
  （`UserAuthResultCode.NOT_ENROLLED`，模拟器没有录入锁屏凭据）→ `biometric verification rejected` → 原生回
  `handleLoginToken("")`。真机录入指纹/人脸后应返回真实令牌，这条路径待真机确认。
- **仍待真机**：生物识别成功路径（拿到真实令牌）、相机/定位权限弹窗、Share Kit 面板的完整交互、
  2in1 与折叠屏的窗口形态。
