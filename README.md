# Traccar Manager for HarmonyOS

把 [traccar-manager](https://github.com/traccar/traccar-manager)（Flutter）移植成 **HarmonyOS 7 / API 26 原生 ArkTS 应用**，
界面与行为按上游 `lib/*.dart` **1:1 复刻**，并做了手机 / 平板 / 2in1 多端适配。仓库内是可直接构建、已在本机模拟器实测过的完整工程。

> **English summary** — A native ArkTS port of the Flutter *Traccar Manager* client for HarmonyOS 7 (API 26):
> ArkWeb + `javaScriptProxy` replaces `flutter_inappwebview`, AssetStoreKit replaces `flutter_secure_storage`,
> UserAuthenticationKit replaces `local_auth`, Push Kit replaces `firebase_messaging`, Share Kit replaces `share_plus`.
> The UI is a pixel-faithful reproduction of the upstream Flutter screens. Builds with DevEco/hvigor, tested on a
> HarmonyOS 7 emulator (see “验证记录”). Licensed Apache-2.0, same as upstream.

---

## 1. 这是什么

上游 Traccar Manager 是一个纯 Flutter 壳：内部只放一个 WebView 打开 Traccar 服务端的 Web 前端，
原生侧负责 **登录令牌存储、生物识别、文件下载/分享、外部链接、深链回跳、通知令牌** 这些 Web 做不到的事。

本移植保持同一套「原生壳 + Web 前端」架构与同一套桥协议，因此：

- 服务端仍是任意 Traccar（默认 `https://demo.traccar.org`，本项目测试用 `http://192.168.31.52:8082`）；
- Web 侧不需要改动（`window.appInterface.postMessage('prefix|payload')` 契约不变）。

| 上游 Flutter | 本工程（ArkTS / 系统能力） |
| --- | --- |
| `flutter_inappwebview` | ArkWeb `Web` 组件 + `javaScriptProxy` + `javaScriptOnDocumentStart` |
| `flutter_secure_storage` | AssetStoreKit（`@ohos.security.asset`） |
| `local_auth` | UserAuthenticationKit（`@ohos.userIAM.userAuth`） |
| `firebase_messaging` | Push Kit（`@hms.core.push.pushService`） |
| `share_plus` | Share Kit（`systemShare`） |
| `permission_handler` | `abilityAccessCtrl` + `onGeolocationShow` / `onPermissionRequest` |
| `shared_preferences` | `@ohos.data.preferences` |
| `url_launcher` | `@ohos.app.ability.common` `startAbility`（外部浏览器） |
| `http` | `@ohos.net.http`（带 `Authorization: Bearer <token>` 下载） |

## 2. HarmonyOS 侧的重点实现

- **桥注入时机**：`javaScriptOnDocumentStart` 注入脚本，先定义 `window.appInterface.postMessage`，
  原生代理未就绪时把消息压进 `__traccarMessageQueue`，`flutterInAppWebViewPlatformReady` 事件里补发；
  同时对「原生 postMessage 抛异常」只记日志不重投（否则 `server|`、`download|` 的副作用会重复执行）。
- **Blob 下载**：覆写 `URL.createObjectURL`，命中 xlsx MIME 时用 `FileReader` 读成 dataURL 再
  `postMessage('download|' + base64)`，对应上游同名注入脚本。
- **导航拦截顺序**（与上游 `shouldOverrideUrlLoading` 同序）：OAuth 四参数（`response_type,client_id,redirect_uri,scope`）
  → 改写 `redirect_uri` 为深链并交给系统浏览器 → 非本服务器 **authority** 的链接一律外部浏览器打开
  → 后缀白名单 `xlsx/kml/csv/gpx` 走带 token 的原生下载 → 其余放行。
- **深链回跳**：`org.traccar.manager://<host>/<path>` 还原到服务器 URL（`code` 存在时把 `redirect_uri` 指回该深链本身）。
- **返回键**：当前 URL 的 path 是 `/` 或 `/login`（或不可后退）时退出应用，否则 Web 后退 —— 与上游 `PopScope` 等价。
- **令牌**：AssetStoreKit 存储，`alias + 可访问性` 查询；`authentication` 分支先走生物识别（60s 超时按未通过，绝不放行）。
- **推送**：Push Kit 令牌回注 Web（`updateNotificationToken`），消息回注 `handleNativeNotification`；
  未接 AGC 时静默降级为空串，登录/下载/通知开关不受影响。

## 3. 目录结构

```
Traccar/
├── harmony/                       # 鸿蒙工程（用 DevEco Studio 打开这一层）
│   ├── AppScope/app.json5         # bundleName org.traccar.manager，versionName 6.1.2
│   ├── entry/src/main/ets/        # 24 个 .ets / 2802 行
│   │   ├── pages/Index.ets        # 三态 + Web + 桥回调 + 导航拦截
│   │   ├── views/components/ErrorScreen.ets
│   │   ├── services/web/          # BridgeScript / TraccarBridge / DownloadHandler / AppPermissions …
│   │   ├── services/storage/      # TokenStore（AssetStoreKit）/ ServerPrefs
│   │   ├── services/download/     # DownloadService / ShareService
│   │   ├── services/auth/BiometricGate.ets
│   │   ├── services/navigation/   # DeepLinkRouter / ExternalLinks
│   │   ├── services/notification/ # PushTokens / NotificationHelper
│   │   └── common/                # UriModel / TraccarConstants / Keys / Log / Toast
│   ├── entry/src/test/            # 23 个本地单测（hypium）
│   └── entry/src/ohosTest/        # 端侧测试
├── tools/                         # 调试与取证工具（CDP 客户端、测试服务器、日志扫描、图标生成）
├── shots/                         # 验证截图与日志取证
├── AGENTS.md                      # 给后续会话的项目须知（构建/装机/取日志/界面基线）
├── PORT-REPORT.md                 # 移植报告（逐项对照上游行为、缺陷修复、验证证据）
└── README.md
```

`upstream/`（上游 Flutter 源码，用于逐行对照）不入库，需要时自行克隆：
`git clone https://github.com/traccar/traccar-manager.git`，本移植对齐的提交是 **`af0bb3f`**（2026-10-05）。

## 4. 构建与运行

前置：DevEco Studio（hvigor `modelVersion` 6.0.2）+ HarmonyOS SDK **API 26**（`compatibleSdkVersion` / `targetSdkVersion` = `26.0.0`）。

```powershell
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$hw = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
cd harmony

& $hw assembleHap --mode module -p product=default --no-daemon      # 主 HAP（未签名）
& $hw --mode module -p module=entry@default -p product=default test --no-daemon   # 本地单测
& $hw assembleHap --mode module -p module=entry@ohosTest -p product=default --no-daemon  # 端侧测试包
```

产物：`harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`（当前 380,686 字节）。
以输出中的 `BUILD SUCCESSFUL` 为准；PowerShell 会把 hvigor 的彩色输出当作错误流，`[exit code: 1]` 不代表构建失败。

安装到模拟器（**未签名 HAP 可直接安装**）：

```powershell
hdc -t 127.0.0.1:5555 install -r harmony/entry/build/default/outputs/default/entry-default-unsigned.hap
hdc -t 127.0.0.1:5555 shell "aa force-stop org.traccar.manager"
hdc -t 127.0.0.1:5555 shell "aa start -a EntryAbility -b org.traccar.manager"
```

真机需要用自己的证书签名（`build-profile.json5` 的 `signingConfigs` 目前为空），
也可以用 DevEco Studio 的 *Automatic signing* 生成。

## 5. 测试

- **本地单测 23 例**（`entry/src/test`，hypium）：URL 规范化与后缀白名单、URI 解析/重建、注入脚本的队列与自环防护、桥协议契约。
- **端侧测试**（`entry/src/ohosTest`）：打包为 `entry-ohosTest-unsigned.hap`。
- **手工验收清单**见 [`harmony/README.md`](harmony/README.md) 第 6 节。

## 6. 验证记录（HarmonyOS 7 模拟器，API 26，`Mate 90 Pro`）

| 项 | 证据 |
| --- | --- |
| 装机与启动 | 未签名 HAP `install -r` 成功；`aa start` 后进程 `org.traccar.manager` + 渲染进程 |
| 三态界面 | `shots/ui1.jpeg`（全屏 Web）、`shots/ui3.jpeg`（错误屏）、`shots/ui8.jpeg`（键盘态） |
| 错误屏换地址 | 点 ✓ 后从新地址加载成功 `shots/ui4.jpeg` |
| 桥与令牌 | 持久化日志：`bridge in` → `onLoginToken` → `token updated` → `login token stored` |
| 导出下载 | `file written \| report.xlsx 13B` + `share panel shown`（`shots/ui10.jpeg`，沙箱内 13 字节文件） |
| 生物识别 | 模拟器无录入凭据 → `user auth rejected \| code=12500010` → 按未通过处理并回注空令牌（预期行为） |
| 桌面图标 | `shots/home1.jpeg` → `shots/icon3.jpeg`（圆盘由 tile 宽度 0.53 放大到 0.71） |

## 7. 已知限制

- **模拟器没有 WebGL/WebGL2**（已定位到 guest 侧根因，应用层解决不了）：真实 Traccar Web 前端会停在自带 loader
  （`GPUInitializationError: WebGL2 is required to display this map`，见 `shots/ui11.jpeg`）。
  证据：接口存在（`typeof WebGL2RenderingContext === 'function'`、`WebAssembly` 可用 ⇒ 不是坚盾模式）但
  `canvas.getContext('webgl2')` 返回 `null`；设备日志 `DGLES: createimage with ctx null opengl_context`、
  `eglCreateSync ... 0x3009 (EGL_BAD_MATCH)`、`chromium: vulkan switch config is: 0`；guest 无 GPU 设备节点。
  模拟器与 SDK 都没有开关（`SecurityParams.disableWebGL` 只能关）。**地图渲染必须在真机验证。**
- **Push Kit 未接 AGC**：无 AGC 项目时 `getToken()` 失败并降级为空串，收不到推送；要真正可用需在 AGC 建项目并把
  `client_id`/`app_id` 写进 `module.json5` metadata，然后重新打包。
- 仍需真机确认的运行时行为：内核 4xx/5xx 是否触发 `onErrorReceive`、重复 `setDownloadDelegate` 语义、
  Share Kit 未带读权限时接收方能否读到文件、生物识别成功路径、相机/定位授权弹窗。
- 上游的评分弹窗（`rate_my_app`）与 Firebase Analytics/Crashlytics 埋点没有对应实现。
- 有意保留的差异（详见 [`PORT-REPORT.md`](PORT-REPORT.md) §2.5）：下载目录用应用缓存目录（`cacheDir`）、
  新增「下载后自动分享」开关、不使用内核自带错误页而用自绘错误屏。

## 8. 文档索引

| 文档 | 内容 |
| --- | --- |
| [`PORT-REPORT.md`](PORT-REPORT.md) | 移植报告：逐项行为对照、修复过程、验证证据、剩余项 |
| [`harmony/README.md`](harmony/README.md) | 工程说明：目录、行为对照表、鸿蒙特性、验收清单、踩坑记录 |
| [`AGENTS.md`](AGENTS.md) | 给后续会话的须知：测试服务器、构建/装机命令、日志取证方法、界面基线 |
| [`API26_WHAT_IS_NEW.md`](API26_WHAT_IS_NEW.md) | API 26 新特性与本项目的取用情况 |

## 9. 许可证与致谢

本项目沿用上游的 **Apache-2.0**（见上游 `LICENSE.txt`），所有界面与交互设计均来自
[traccar/traccar-manager](https://github.com/traccar/traccar-manager)（`af0bb3f`）与
[Traccar](https://www.traccar.org/)。图标素材取自上游 iOS 资源，仅做了白底 + 圆盘比例调整。
