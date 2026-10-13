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
- 产物 `entry\build\default\outputs\default\entry-default-unsigned.hap`（当前 384,973 字节，未签名）。
- 模拟器（`Emulator.exe -start "Mate 90 Pro"`，HarmonyOS 7 / API 26，`127.0.0.1:5555`）
  **可直接 `hdc install -r` 未签名 HAP**：
  `hdc -t 127.0.0.1:5555 install -r <hap>`；启动 `aa force-stop org.traccar.manager` +
  `aa start -a EntryAbility -b org.traccar.manager`。
- 该模拟器实例大约每十几分钟会因 crash-client 心跳丢失被 `KillEmulator` 收走，且**不能用 harness
  后台 job 启动**（job 结束会把模拟器一起杀掉），要用 `Win32_Process.Create` 脱离 job 启动；
  验证要一次跑完。

## 模拟器启动（2026-10-13 实测）

- 实例目录是 **`<instancePath>/<name>`**，所以要传**父目录**：
  `Emulator.exe -start "Mate 90 Pro" -instancePath "F:/Huawei" -imageRoot "F:/Huawei/Sdk"`
  （传实例目录本身会报 `"Mate 90 Pro"  is not found. Please create the device(folder): "…/Mate 90 Pro/Mate 90 Pro"`）。
- 设备名带空格时 `Start-Process -ArgumentList @('-start','Mate 90 Pro')` 会被拆成两个参数
  （`Invalid command: please attach - or -- before the option!`），要传**单个字符串并在内部加引号**。
- 启动器进程 ~15s 后自杀是**设计行为**，不是失败：`crash_server.log` 出现
  `[CrashReportCommon.cpp(KillEmulator:28)]KillEmulator …` +
  `[CrashReportServer.cpp(KillAndRebootBySnapshot:775)]Try to restart Emulator on new process get result  true`，
  新进程继续跑。
- **不要加 `-noWindow`**：无窗口时模拟器拿不到 GL，直接以 `ErrorCode: 00801013`
  （二进制里的键名 `gpu_driver_not_support_cause`：宿主显卡驱动不满足 OpenGL 4.1）退出。
- **当前阻塞（2026-10-13）**：带窗口启动时 guest 也只走到 `bootevent.bms.main.bundles.ready`，
  `launcher.ready`/`wms.ready`/`account.ready` 始终不出现，`hdc list targets` 一直 `[Empty]`，
  约 60s 后 init 自己走 `StopAllServices` → `DoUmount /data` → 写 `/proc/sysrq-trigger` 触发
  `Kernel panic - not syncing: sysrq triggered crash`，模拟器随后 `quit emulator`。
  已排除：宿主内存（55.8GB 空闲）、快照损坏（删 `ram.img` 强制冷启动）、userdata 损坏（换全新 overlay 试过）、
  hdc 服务假死（`hdc kill`/`hdc start` 过）、bootMode（`-bootMode` 传非法值只回
  `Command bootmode invalid! Use default.`，合法值取不到）。⇒ 怀疑是宿主图形栈问题
  （这台机器是远程/串流环境：有 Parsec Virtual Display、MuMu Virtual Display、Tesla V100、Radeon 780M 四块适配器），
  需从 DevEco Studio 的 Device Manager 启动、或整机重启/更新显卡驱动后再试。
- `F:\Huawei\Mate 90 Pro\config.ini` 可改 `isHotBoot`（`false` 强制冷启动，默认 `true`）；健康的冷启动约 23s
  （参考 2026-10-11 23:49 创建后的首次启动：镜像校验结束到 `Guest OS Boot Completed!!` 用 22.5s）。
- 镜像校验很慢（`system.img` 约 33s），启动到能用大约 1 分钟；`Emulator.exe -help` 里有
  `-instance <name> [-screenshot [-screenshotPath <path>]]` 等场景注入命令，可替代部分 hdc 操作。

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
