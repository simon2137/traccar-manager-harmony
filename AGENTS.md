# Traccar Manager → HarmonyOS 移植项目说明（给后续会话）

## 测试服务器（用户指定，2026-10-12）

**本项目以后统一用 `http://192.168.31.52:8082` 做测试服务器。**

- 这是局域网里的一台真实 Traccar **6.16.0** 服务端（`/api/server` 返回 `map: bingRoad`、
  `timezone: Asia/Shanghai`、`forceSettings: true`、坐标约 29.5713/106.5105）。
- 连通性：宿主 `curl http://192.168.31.52:8082/` → HTTP 200（~7ms）；模拟器内 `ping` 通（~2ms）。
- 设置应用服务器地址的办法：应用内错误页输入框提交，或在 CDP 里执行
  `window.appInterface.postMessage('server|http://192.168.31.52:8082')`（会写进
  沙箱 `preferences/traccar_manager_settings` 的 `<string key="url">`）。
- **模拟器没有 WebGL/WebGL2（已定位根因，应用侧解决不了）**：真实 Traccar Web 前端因此停在自带
  loader，`assets/index-*.js` 抛 `GPUInitializationError: WebGL2 is required to display this map`。
  取证（CDP `Runtime.evaluate`）：`typeof WebGL2RenderingContext === 'function'`、`typeof WebAssembly
  === 'object'`（⇒ **不是**「坚盾守护模式」，该模式会同时禁掉 WebGL 与 WebAssembly/JIT），但
  `canvas.getContext('webgl2')` 与 `('webgl')` 都是 `null`。设备日志显示 ArkWeb 的 GL 上下文起不来：
  `C02515/DGLES: createimage with ctx null opengl_context`、`eglCreateSync ... 0x3009 (EGL_BAD_MATCH)`、
  `A04500/chromium: vulkan switch config is: 0, cmd is: false`；guest 内没有 GPU 设备节点
  （`/dev/dri`、`/dev/mali0`、`/dev/kgsl-3d0`、`/dev/gpu` 均不存在）。
  模拟器侧没有任何开关可开：`tools\emulator\emulator.json`（52 个机型只有分辨率/内存/磁盘/api）、
  `Emulator26.0\productConfig.json`、实例 `config.ini`/`hardware-qemu.ini`、`Emulator.exe -help`
  都没有 GPU/图形项；SDK 只有 `SecurityParams.disableWebGL`（默认 `false`＝开启，只能关不能开），
  没有传 Chromium 开关（如 `--enable-unsafe-swiftshader`）的 API。
  ⇒ **WebGL 只能上真机验证**；壳层/桥/下载仍用本地 `tools/testserver.mjs` 代理页。
  官方 FAQ（模拟器对宿主显卡的要求 OpenGL ≥ 4.1）：
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-faqs

## 构建 / 装机

```powershell
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$hw = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
cd D:\dsh\Traccar\harmony
& $hw assembleHap --mode module -p product=default --no-daemon        # 主 HAP（未签名）
& $hw --mode module -p module=entry@default -p product=default test --no-daemon   # 本地单测
```

- 以输出里的 `BUILD SUCCESSFUL` 为准；PowerShell 会把 hvigor 的彩色输出算成错误流，
  `[exit code: 1]` 不代表构建失败。
- 产物 `entry\build\default\outputs\default\entry-default-unsigned.hap`（当前 380,686 字节，未签名）。
- 模拟器（`Emulator.exe -start "Mate 90 Pro"`，HarmonyOS 7 / API 26，`127.0.0.1:5555`）
  **可直接 `hdc install -r` 未签名 HAP**：
  `hdc -t 127.0.0.1:5555 install -r <hap>`；启动 `aa force-stop org.traccar.manager` +
  `aa start -a EntryAbility -b org.traccar.manager`。
- 该模拟器实例大约每十几分钟会因 crash-client 心跳丢失被 `KillEmulator` 收走，且**不能用 harness
  后台 job 启动**（job 结束会把模拟器一起杀掉），要用 `Win32_Process.Create` 脱离 job 启动；
  验证要一次跑完。

## 取日志（关键经验）

- 应用的 `Log.*` 走 hilog，域 `0x0FFF`、tag `TraccarManager`（显示为 `A00fff/TraccarManager`）。
- **不要用流式 `hilog` 取证**：模拟器上它会丢行，连必然执行的行都可能缺失，"没日志"不等于"没执行"。
- 权威日志是设备上按分钟轮转的 `/data/log/hilog/hilog.*.gz`：

```powershell
hdc -t 127.0.0.1:5555 file recv /data/log/hilog/<file>.gz D:\dsh\Traccar\shots\
node D:\dsh\Traccar\tools\hilogscan.mjs D:\dsh\Traccar\shots\<file>.gz   # gunzip + 过滤应用域
```

## 界面基线（不要退回自绘外壳）

界面是上游 Flutter（`D:\dsh\Traccar\upstream`）的 1:1 复刻，只有三态：**加载圈 → 错误屏 → 全屏 Web**，
没有标题栏/按钮/底部面板/宽屏分栏。改 UI 前先读 `upstream\lib\main_screen.dart` 与
`upstream\lib\error_screen.dart`，并保持应用图标底色为白色。

图标本身：白底（`background.png`）+ 藏青圆盘（`foreground.png` 等三张派生图），圆盘占画布 **82%**
（840/1024），桌面实测占 tile 宽度 **0.71** —— 原素材只有 61%（tile 的 0.53），用户反馈"中间元素太小"
后才放大。改尺寸跑 `python tools\resize_icon.py`（Pillow，改 `DISC_NEW`），量比例跑
`python tools\measure_icon.py`（对比 `shots/home1.jpeg` 与 `shots/icon3.jpeg`）；改完必须重建 + 重装才看得到。
