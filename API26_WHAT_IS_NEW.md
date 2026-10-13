# HarmonyOS 7 / API 26 — what is genuinely NEW in the local SDK

**Roots scanned (read-only):**
- `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets` (2173 `.d.ts`) — referred to below as `OH/`
- `C:\Program Files\Huawei\DevEco Studio\sdk\default\hms\ets` (220 `.d.ts`) — referred to below as `HMS/`

**Method:** parsed every JSDoc block; kept blocks whose body matches `@since\s+26(?!\d)` (so `26.0.0` matches, `260` does not). **4137 raw `@since 26` occurrences in 299 OH files**, 72 HMS files; 4739 rows after dropping the duplicated `build-tools/ets-loader/declarations/*` mirror.
**Caveat used throughout:** many files carry a *file-level* `@since 26`, so a big count can mean "whole module is new in 26", not N new members. Those files are marked **[module-new]**.
**Negative result already excluded from counts:** `api/permissions.d.ts` holds 141 new permission strings, most of them system/CLI/TV/automotive — only the app-usable ones are listed in §5.

---

## 0. Kit barrels available (`@kit.*` imports)

**`OH/ets/kits/` = 47 files:** AbilityKit, AccessibilityKit, AdsKit, ArkData, ArkGraphics2D, ArkGraphics3D, ArkTS, ArkUI, ArkWeb, AssetStoreKit, AudioKit, AVSessionKit, BackgroundTasksKit, BasicServicesKit, CalendarKit, CameraKit, ConnectivityKit, ContactsKit, CoreFileKit, CryptoArchitectureKit, DataLossPreventionKit, DataProtectionKit, DeviceCertificateKit, DistributedServiceKit, DriverDevelopmentKit, DrmKit, FormKit, ImageKit, IMEKit, InputKit, IPCKit, LocalizationKit, LocationKit, MDMKit, MechanicKit, MediaKit, MediaLibraryKit, MindSporeLiteKit, MultimodalAwarenessKit, NetworkKit, NotificationKit, PerformanceAnalysisKit, SensorServiceKit, TelephonyKit, TestKit, UniversalKeystoreKit, UserAuthenticationKit.
> No `@kit.WindowKit` and no `@kit.WebKit` — `window`/`floatView`/`floatingBall` come from `@kit.ArkUI`; the web component + `webview` from `@kit.ArkWeb`.

**`HMS/ets/kits/` = 56 files:** AccessoryKit, AccountKit, AgentFrameworkKit, AODNavigationKit, AppGalleryKit, AppLinkingKit, AREngine, CallKit, CallServiceKit, CarKit, CloudFoundationKit, ConfidentialSpaceKit, CoreSpeechKit, CoreVisionKit, DataAugmentationKit, DeskTopExtensionKit, DeviceSecurityKit, EnterpriseDataGuardKit, EnterpriseSpaceKit, EnterpriseThreatProtectionKit, FASTKit, FileManagerServiceKit, GameServiceKit, GraphicsAccelerateKit, HealthServiceKit, IAPKit, IntentsKit, LiveViewKit, MapKit, NaturalLanguageKit, NearLinkKit, NetworkBoostKit, OnlineAuthenticationKit, PaymentKit, PDFKit, Penkit, PreviewKit, PushKit, ReaderKit, RemoteCommunicationKit, RingtoneKit, ScanKit, ScenarioFusionKit, ScreenTimeGuardKit, ServiceCollaborationKit, ServiceSupportKit, ShareKit, SpatialReconKit, SpeechKit, StatusBarExtensionKit, StoreKit, UIDesignKit, VisionKit, WalletKit, WearEngine, WeatherServiceKit.
> `@kit.LiveViewKit` **exists**. `@kit.LocationKit` exists **only** on the OH side (not HMS).

---

## 1. ArkWeb (deep dive)

`OH/component/web.d.ts`
- `@since 26` | `OH/component/web.d.ts:244` | `enum WebKeyboardAppearanceMode {NONE_IMMERSIVE=0, IMMERSIVE=1, LIGHT_IMMERSIVE=2, DARK_IMMERSIVE=3}` — soft-keyboard immersive skin over web content.
- `@since 26` | `OH/component/web.d.ts:376` | `type OnInputmethodAttachedCallback = () => void`.
- `@since 26` | `OH/component/web.d.ts:8101` | `scrollbarLayoutPolicy(policy: ScrollbarLayoutPolicy): WebAttribute` — new `:8662 enum ScrollbarLayoutPolicy {CONTENT=0 (W3C), SYSTEM=1 (system UI conventions)}`.
- `@since 26` | `OH/component/web.d.ts:8111` | `enableDrag(value: boolean): WebAttribute`.
- `@since 26` | `OH/component/web.d.ts:8122` | `enableScrollDirectionalLock(value: boolean, type: ScrollDirectionalLockType): WebAttribute`; `:8687 ScrollDirectionalLockType {ALL=0, NESTED_SCROLL=1}` — keeps a horizontal map/swipe inside the page from stealing vertical scroll.
- `@since 26` | `OH/component/web.d.ts:8139` | `aiSessionOptions(aiSessions: Array<AISessionEvent>): WebAttribute`; `:8751 interface AISessionEvent {aiSessionType, onCreateAISession, onExecuteAIAction, onDestroyAISession}` — let page JS call out to an on-device AI session. `:8798 AISessionType {TRANSLATOR=1, LANGUAGE_DETECTOR=2, SUMMARIZER=3, WRITER=4, REWRITER=5, PROMPT=6, PROOFREADER=7}`; `:8863 AISessionResultType {SUCCESS=0, FAILURE=1, RUNNING=2}`; `:8896 type OnAISessionCallback = (state: AISessionResultType, content: string) => void`; `:8714 OnCreateAISession = (id: string, params: string, result: OnAISessionCallback) => boolean`; `:8729 OnExecuteAIAction = (id, params, result) => void`; `:8741 OnDestroyAISession = (id: string) => void`.
- `@since 26` | `OH/component/web.d.ts:8150` | `onInputmethodAttached(callback: OnInputmethodAttachedCallback): WebAttribute`.
- `@since 26` | `OH/component/web.d.ts:8161` | `keyboardAppearance(mode: WebKeyboardAppearanceMode): WebAttribute`.
- `@since 26` | `OH/component/web.d.ts:8171` | `enableFullscreenVideoOverlay(enabled: boolean): WebAttribute`.
- `@since 26` | `OH/component/web.d.ts:8183` | `enableMediaNetworkProxy(enabled: boolean): WebAttribute` — route HLS/media requests through the system web net stack (per-app proxy/cert policy applies).

`OH/api/@ohos.web.webview.d.ts`
- `@since 26` | `OH/api/@ohos.web.webview.d.ts:204` | `M144 = 3` — ArkWeb engine baseline is now Chromium M144.
- `@since 26` | `OH/api/@ohos.web.webview.d.ts:2635` | `interface SecurityParams {disableJITCompilation?, disableWebAssembly?, disableWebGL?, disablePDFViewer?, disableMathML?, disableServiceWorker?, disableNonProxyUDP?}` (all optional booleans, default `false`; docs name the attack class each one closes — V8 type confusion, WASM memory, GPU-driver sandbox escape, PDF parser, MathML, SW request interception, WebRTC UDP bypassing a proxy).
- `@since 26` | `OH/api/@ohos.web.webview.d.ts:5163` | `static enableAdvancedSecurityMode(securityParams: SecurityParams): void`.
- `@since 26` | `OH/api/@ohos.web.webview.d.ts:5022` | `setErrorPageEnabled(enable: boolean, includeSubframe: boolean): void` — **iframe sub-frame error handling**; `:5035 getSubframeErrorPageEnabled(): boolean`.
- `@since 26` | `OH/api/@ohos.web.webview.d.ts:5198` | `executeAIPageCommand(command: string): Promise<string>`.
- `@since 26` | `OH/api/@ohos.web.webview.d.ts:1493` | `static fetchCookie(url: string, incognito: boolean, includePartitionedCookies: boolean): Promise<string>`; `:1506 fetchCookieSync(url, incognito?, includePartitionedCookies?): string` — `includePartitionedCookies` (CHIPS) is the **only 26 delta** on the cookie path.
- `@since 26` | `OH/api/@ohos.web.webview.d.ts:7691` | `OVERLAY_VISUAL_SCROLLBAR = 2` — overlay VisualViewport scrollbar: appears on scroll, hides when idle, not draggable.
- `@since 26` | `OH/api/@ohos.web.WebNativeMessagingExtensionContext.d.ts:68` | `startAbilityForResult(want: Want, options?: StartOptions): Promise<AbilityResult>` — native-messaging extension can now launch-and-await a UIAbility.
- **Privacy/incognito — NEGATIVE:** there is **no** `privacyMode` / `PrivacyConfig` symbol anywhere in the SDK. Incognito is only the pre-26 surface: `OH/component/web.d.ts:3492 incognitoMode?: boolean` (in `WebOptions`) plus the pre-26 `incognito?` params on `deleteAllData/allowGeolocation/deleteGeolocation/deleteAllGeolocation/getAccessibleGeolocation/getStoredGeolocation/fetchCookie/configCookie`. So "privacy mode" in 26 = partitioned cookies + `SecurityParams` + new sub-frame error page. Do not claim a new incognito API.

---

## 2. window / multi-window / 闪控球 (floating ball)

`OH/api/@ohos.window.d.ts` (51 tags)
- `@since 26` | `OH/api/@ohos.window.d.ts:70` | `declare type WindowEventListener = (windowId: number, event: window.WindowEventType) => void`.
- `@since 26` | `OH/api/@ohos.window.d.ts:207` | `AvoidAreaType.TYPE_FLOAT_NAVIGATION = 5` — "Area for float navigation"; syscap `Window.SessionManager`; `:4366 setFloatNavigationAvoidAreaEnabled(enabled: boolean): Promise<void>`; `:4387 isFloatNavigationAvoidAreaEnabled(): boolean`.
- `@since 26` | `OH/api/@ohos.window.d.ts:209` | `enum SplitRatioPreference {EQUAL=0, PRIMARY_DOMINANT=1, SECONDARY_DOMINANT=2}`.
- `@since 26` | `OH/api/@ohos.window.d.ts:2272` | `function getAllWindowLayoutInfo(displayId: number, option?: WindowInfoOptions): Promise<Array<WindowLayoutInfo>>` — sorted by z-level, index 0 = topmost; drives your own per-window overlays/watermarks.
- `@since 26` | `OH/api/@ohos.window.d.ts:999/:1007/:1098` | new `WindowLayoutInfo` fields `displayId?: number`, `globalRect?: Rect`, `windowType?: WindowType`.
- `@since 26` | `OH/api/@ohos.window.d.ts:2318` | `onApplicationFocusStateChange(callback: Callback<boolean>)`; `:2328 offApplicationFocusStateChange` — whole-app focus, not just one window.
- `@since 26` | `OH/api/@ohos.window.d.ts:2594` | `enum OrientationExecutionResult {ORIENTATION_APPLIED=0, ORIENTATION_IGNORED=1, ORIENTATION_PENDING=2}`; `:2631 interface OrientationResult {executionResult}`; `:5077 setPreferredOrientationWithResult(orientation: Orientation): Promise<OrientationResult>` (no effect on 2in1 or child windows).
- `@since 26` | `OH/api/@ohos.window.d.ts:3034` | `enum AcrossDisplayPresentation {FOLLOW_ACROSS_DISPLAY_SETTING=0, ENTER_ACROSS_DISPLAY_MODE=1, EXIT_ACROSS_DISPLAY_MODE=2}`; `:3075 interface MaximizeOptions {maximizePresentation?, acrossDisplayPresentation?, snapshotAnimationConfig?}`; `:7407 maximizeWithOptions(maximizeOptions?: MaximizeOptions): Promise<void>` — half-folded foldable / 2in1 spanning both displays.
- `@since 26` | `OH/api/@ohos.window.d.ts:3188` | `interface WindowSnapshotAnimationConfig {duration? (default 400 ms FLOATING↔FULLSCREEN), delay? (default 350 ms)}`; `:7617 recover(snapshotAnimationConfig: WindowSnapshotAnimationConfig): Promise<void>`.
- `@since 26` | `OH/api/@ohos.window.d.ts:7465` | `setSupportedWindowModes(supportedWindowModes: Array<bundleManager.SupportWindowMode>): Promise<void>` — runtime free-form/fullscreen policy.
- `@since 26` | `OH/api/@ohos.window.d.ts:7915` | `setTouchableAreas(rects: Array<Rect>): Promise<void>` — perm `ohos.permission.SET_WINDOW_TOUCH_AREAS`; touches outside the rects pass through to what is beneath; invalidated when the window rect changes.
- `@since 26` | `OH/api/@ohos.window.d.ts:8194` | `setWindowMaskWithAlpha(windowMask: Uint8Array, maskWidth: number, maskHeight: number): Promise<void>` — per-pixel alpha mask (non-rectangular window).
- `@since 26` | `OH/api/@ohos.window.d.ts:6560` | `setWindowContainerModalColor(activeColor: string, inactiveColor: string): void` — perm `ohos.permission.SET_WINDOW_ALPHA`.
- `@since 26` | `OH/api/@ohos.window.d.ts:9885` | `enum WindowPostureMode {DESKTOP_MODE = 0}` (half-folded, `creaseRects` width > height); `:8834 isInWindowPostureMode(mode)`; `:8851 onWindowPostureModeChange(mode, callback: Callback<boolean>)`; `:8867 offWindowPostureModeChange`.
- `@since 26` | `OH/api/@ohos.window.d.ts:9832` | `setImageForRecent(imageResource: number | image.PixelMap, value: ImageFit): Promise<void>`; `:9864 removeImageForRecent(): Promise<void>` — perm `ohos.permission.MANAGE_RECENT_SNAPSHOT`; image shown in multitasking / dock hover.
- `@since 26` | `OH/api/@ohos.window.d.ts:9227` | `zLevelAboveParentLoosened?: boolean`; `:9922 windowAlpha?: number` (0.0–1.0); `:9933 interface WindowInfoOptions {excludeSystemWindows?, foregroundAboveWindow?: number, foregroundBelowWindow?: number}`.
- **`WindowType` — NEGATIVE:** `enum WindowType` at `OH/api/@ohos.window.d.ts:96` has **no** 26 member: `TYPE_APP=0` (@since 7), `TYPE_SYSTEM_ALERT=1` (7), `TYPE_FLOAT=8` (9), `TYPE_DIALOG=16` (10), `TYPE_MAIN=32` (18).

`OH/api/@ohos.window.floatView.d.ts` — **[module-new]** `declare namespace floatView`, syscap `Window.SessionManager`, 61 tags. This *is* the floating-window / 闪控球 story in 26.
- `@since 26` | `OH/api/@ohos.window.floatView.d.ts:75` | `isFloatViewEnabled(): boolean`; `:88 create(config: FloatViewConfiguration): Promise<FloatViewController>`.
- `@since 26` | `OH/api/@ohos.window.floatView.d.ts:106` | `bind(floatViewController, floatingBallController: floatingBall.FloatingBallController, floatingBallParams: floatingBall.FloatingBallParams): Promise<void>` — perms `ohos.permission.USE_FLOAT_BALL` + `ohos.permission.FLOAT_VIEW`; `:151 unbind(...)`.
- `@since 26` | `OH/api/@ohos.window.floatView.d.ts:174` | `getFloatViewLimits(templateType: FloatViewTemplateType): FloatViewLimits` (px).
- `@since 26` | `OH/api/@ohos.window.floatView.d.ts:191` | `FloatViewConfiguration {context: BaseContext, templateType, isConfirmOnClose?}`.
- `@since 26` | `OH/api/@ohos.window.floatView.d.ts:252` | `FloatViewController {setUIContext(path, storage?), setUIContextByName(name, storage?), setWindowSize(size), switchTemplate(templateProperty), start() [perm FLOAT_VIEW], stop(), setFloatViewVisibilityInApp(isVisible), restoreMainWindow(wantParameters?), getWindowProperties(), onStateChange/offStateChange, onRectChange/offRectChange, onLimitsChange/offLimitsChange}`.
- `@since 26` | `OH/api/@ohos.window.floatView.d.ts:538` | `FloatViewTemplateType {ROUNDED_RECTANGLE=0, HORIZONTAL_BAR=1}`; `:563 FloatViewProperties {windowId, displayId, windowRect, windowScale, avoidArea, inSidebar}`; `:660 FloatViewLimits {minSize, maxSize, ratioLimits}`; `:634 RatioLimit {minRatio, maxRatio}`.
- `@since 26` | `OH/api/@ohos.window.floatView.d.ts:735` | `FloatViewState {STARTED=1, HIDDEN=2, STOPPED=3, IN_SIDEBAR=4, IN_FLOATING_BALL=5, ERROR=6}`; `:693 FloatViewStateChangeInfo {state, stopReason}`; `:794 FloatViewRectChangeInfo {..., reason}` — **floating-ball state is reported here (`IN_FLOATING_BALL`)**, not in `@ohos.window.d.ts`.

`OH/api/@ohos.window.floatingBall.d.ts` (new 26 members)
- `@since 26` | `OH/api/@ohos.window.floatingBall.d.ts:195` | `onDestroy(callback: Callback<string>)`; `:211 offDestroy`.
- `@since 26` | `OH/api/@ohos.window.floatingBall.d.ts:323` | `titleColor?: string`; `:337 contentColor?: string`.
- `@since 26` | `OH/api/@ohos.window.floatingBall.d.ts:369` | `textUpdateAnimationType?: FloatingBallTextUpdateAnimationType`; `:458 enum FloatingBallTextUpdateAnimationType {ANIMATION_NONE=0, ANIMATION_OPACITY=1}`.

---

## 3. ArkUI in 26

### 3.1 Immersive light material (`@ohos.arkui.uiMaterial` + `systemMaterial`)
`OH/api/@ohos.arkui.uiMaterial.d.ts` (37 tags)
- `@since 26` | `OH/api/@ohos.arkui.uiMaterial.d.ts:19` | `declare namespace uiMaterial`; `:33 MaterialType {IMMERSIVE = 2}` — the immersive light material type.
- `@since 26` | `OH/api/@ohos.arkui.uiMaterial.d.ts:58` | `MaterialState {DEFAULT=0, ENABLE=1, DISABLE=2}` — app-level switch; docs say **on by default for Dialog/Toast/AlphabetIndexer/ChipGroup**.
- `@since 26` | `OH/api/@ohos.arkui.uiMaterial.d.ts:116` | `MaterialInfo {state, type}`; `:150 getMaterialInfo(): MaterialInfo` — reads the `materialInfo` metadata from the app's `module.json5`.
- `@since 26` | `OH/api/@ohos.arkui.uiMaterial.d.ts:164` | `ImmersiveStyle {ULTRA_THIN=0, THIN=1, REGULAR=2, THICK=3, ULTRA_THICK=4}` — the 5 thickness levels.
- `@since 26` | `OH/api/@ohos.arkui.uiMaterial.d.ts:226` | `MaterialLevel {EXQUISITE=0, GENTLE=1, SMOOTH=2}`; `:269 getGlobalMaterialLevel(): MaterialLevel`; `:281 isImmersiveMaterialSupported(): boolean` — **always feature-detect, level differs per device**.
- `@since 26` | `OH/api/@ohos.arkui.uiMaterial.d.ts:297` | `ImmersiveOptions {style?, materialColor?: ResourceColor, colorInvert?: boolean, applyShadow?: boolean, interactive?: boolean, lightEffect?: LightEffectOptions | null}`; `:430 LightEffectOptions {color?: ResourceColor}` (light-sensing interaction feedback).
- `@since 26` | `OH/api/@ohos.arkui.uiMaterial.d.ts:455` | `class Material {static get empty(): Material}`; `:483 class ImmersiveMaterial extends Material {constructor(options?: ImmersiveOptions)}` — nothing happens until you pass a non-`empty` Material.
- `@since 26` | `OH/component/common.d.ts:16954` | `declare type SystemUiMaterial = import('../api/@ohos.arkui.uiMaterial').default.Material`.
- `@since 26` | `OH/component/common.d.ts:22624` | `systemMaterial(material: SystemUiMaterial | undefined): T` — universal attribute; also available on **sheet** (`common.d.ts:12145`), **popup** (`:12956`), **tips** (`:13157`), **menu** (`:15582`).

### 3.2 New components / container readers (all **[module-new]**)
- `@since 26` | `OH/api/@ohos.arkui.components.ArkLazyWaterFlowLayout.d.ts` | lazy water-flow layout container (13 tags).
- `@since 26` | `OH/api/@ohos.arkui.components.ArkLazyColumnLayout.d.ts` | lazy column layout (11 tags).
- `@since 26` | `OH/api/@ohos.arkui.components.ArkLazyDynamicLayout.d.ts` | lazy dynamic layout (4 tags).
- `@since 26` | `OH/api/arkui/LazyLayoutAlgorithm.d.ts` | the shared lazy-layout algorithm contract (16 tags).
- `@since 26` | `OH/api/@ohos.arkui.components.SelectionContainer.d.ts` | selection container (33 tags) + `OH/api/arkui/SelectionContainerModifier.d.ts`, exported at `OH/api/@ohos.arkui.modifier.d.ts:655`.
- `@since 26` | `OH/api/@ohos.arkui.components.ContainerReader.d.ts` | container reader (13 tags) + `OH/api/arkui/ContainerReaderModifier.d.ts`, exported at `OH/api/@ohos.arkui.modifier.d.ts:637`.
- `@since 26` | `OH/api/@ohos.arkui.modifier.d.ts:647` | `ModifierUtils` — utility methods for modifier/attribute operations.

### 3.3 Universal-attribute additions (`OH/component/common.d.ts`, 129 tags)
- `@since 26` | `OH/component/common.d.ts:73/:85/:97/:107/:136` | global reuse pool: `reusePool?: ReusePoolOwnership`, `poolAccepts?: Function[]`, `type ReusePoolOwnership = 'shared' | 'perInstance'`, `enum ReusableMemOptStrategy {DEFAULT=0, ENABLE_AUTO_CACHE_OPTIMIZATION=1<<0}`, `interface ReusableOptions {memoryOptimizationStrategy?}`.
- `@since 26` | `OH/component/common.d.ts:578–850` | **Environment API**: `class SystemEnvKey<T>`, `WritableSystemEnvKey<T>`, `ReadonlySystemEnvKey<T>`, `CustomEnvKey<S>`; `WritableEnvKey {DIRECTION, FONT_SCALE}`; `ReadonlyEnvKey {WINDOW_AVOID_AREA, WINDOW_AVOID_AREA_PX, WINDOW_SIZE, WINDOW_SIZE_PX, WINDOW_DISPLAY_ID, WINDOW_SYSTEM_DENSITY, WINDOW_IS_FOCUSED, WINDOW_IS_HIGHLIGHTED}`; `CustomEnv<T>(key): PropertyDecorator`; string keys `'system.window.avoidarea'`, `'system.window.avoidarea.px'`, `'system.window.size'`, `'system.window.size.px'`. Declarative replacement for `on('avoidAreaChange')` — big win for arrow/map inset handling.
- `@since 26` | `OH/api/@ohos.arkui.WithEnv.d.ts:19` | `class WithEnvAttribute {env<T>(key: WritableSystemEnvKey<T>, value: T), customEnv<T>(key: CustomEnvKey<T>, value: T)}`; `:68 export declare const WithEnv: WithEnvInterface` — the in-build component form of the same.
- `@since 26` | `OH/component/common.d.ts:1056` | `MonitorDecoratorOptions {enableWildcard?}`.
- `@since 26` | `OH/component/common.d.ts:272` | text decoration `thicknessScale?: number`.
- `@since 26` | `OH/component/common.d.ts:6840` | `enum AnchoredColorMode {FOLLOW_SYSTEM=0, FOLLOW_TARGET=1}`; popup `:12945 colorMode?: AnchoredColorMode`, menu `:15345`.
- `@since 26` | `OH/component/common.d.ts:8705/:9067` | `getCurrentLocalPosition?(): Coordinate2D`; `getHistoricalPoints?(): Array<MouseHistoricalPoint>`; `:9087 MouseHistoricalPoint {x, y, displayX, displayY, windowX, windowY, globalDisplayX, globalDisplayY, timestamp}` — real pen/mouse stroke history.
- `@since 26` | `OH/component/common.d.ts:10038/:22577` | `GestureCollectInterceptCallback = (recognizers, touchRecognizers?) => GestureCollectIntervention`; `onGestureCollectIntercept(callback): T` — one node can arbitrate the whole gesture recognizer set.
- `@since 26` | `OH/component/common.d.ts:22476` | `shouldRecognizerParallelWith(callback)`; `:9979 ShouldRecognizerParallelWithCallback`.
- `@since 26` | `OH/component/common.d.ts:10762` | `autoHideComponentUniqueIds?: number | number[]` (drag); mirrored at `OH/api/@ohos.arkui.dragController.d.ts:225`.
- `@since 26` | `OH/component/common.d.ts:14851/:14882/:15616` | menu grid: `enum MenuGridPosition {TOP=0, BOTTOM=1}`, `interface MenuGridStyleOptions {count?, horizontalSize?, position?}`, `gridStyle?: MenuGridStyleOptions`; plus `:15570 targetSpace?: LengthMetrics`, `:15595 maxHeight?: LengthMetrics`, `:15605 scrollBar?: BarState`.
- `@since 26` | `OH/component/common.d.ts:21496/:21527/:21563` | `bindContextMenuByResponseType(content, responseType: ResponseType, options?): T`; `bindContextMenuWithResponse(content: CustomBuilderT<ResponseType> \| Array<MenuElement> \| undefined, options?): T`; `bindContextMenuByIsShow(isShow, content, options?): T` — programmatic, long-press-free context menus.
- `@since 26` | `OH/component/common.d.ts:22689/:22705` | `accessibilityNextFocusId(nextId, nextFocusParams: AccessibilityNextFocusParams \| undefined): T`; `accessibilityCustomActions(actions: Array<AccessibilityCustomAction> \| undefined): T`.
- `@since 26` | `OH/component/common.d.ts:22718/:27180` | `smartGestureShortcut(options?: SmartGestureShortcutOptions): T`; `SmartGestureShortcutOptions {action?: GestureShortcut (only PRIMARY), enabled?, selectable?}`.
- `@since 26` | `OH/component/common.d.ts:22734/:22746` | `inspectorLabel(label: string \| undefined): T` (DevEco Studio only); `doubleSided(value: Optional<boolean>): T`.
- `@since 26` | `OH/component/common.d.ts:20063/:23950` | `onAreaChange(event: AreaChangeCallback, options?: AreaChangeOptions): T`; `AreaChangeOptions {expectedUpdateInterval?: number}` (ms) — throttle the layout thrash when a map panel resizes.
- `@since 26` | `OH/component/common.d.ts:25245/:25273/:25383/:25601/:25719` | `scrollBarWidth(value: number \| string \| Resource): T`; `autoAdjustScrollBarMargin(enable)`; `enableScrollWithMouse(enabled)`; `scrollBarHeight(height: LengthMetrics \| undefined)`; `OnVisibleIndexesChangeCallback = (start: number, end: number) => void`.
- `@since 26` | `OH/component/common.d.ts:26053/:26068` | `useDefaultMultiSelectStyle?: boolean`; `enableTwoFingerMultiSelect?: boolean` — desktop-grade two-finger text selection on 2in1.
- `@since 26` | `OH/component/common.d.ts:27006–27149` | raw input monitor: `InputEventInterceptResult {action: InputEventInterceptAction}`, `InputEventMonitor`, `abstract class RawInputEventWrapper {isMouseEvent(), isTouchEvent(), isKeyEvent(), asMouseEvent(), asTouchEvent(), asKeyEvent()}`, `type InputEventListener = (event: RawInputEventWrapper) => InputEventInterceptResult`.

### 3.4 `@ohos.arkui.UIContext.d.ts` (48 tags)
- `@since 26` | `OH/api/@ohos.arkui.UIContext.d.ts:1335/:1384/:1403/:2648` | `type OnOverlayBackPressCallback = () => boolean`; `onBackPress?`; `interface OrderOverlayOptions {levelOrder?, levelMode?, levelUniqueId?}`; `openOrderOverlay(content: ComponentContent, options?: OrderOverlayOptions): Promise<void>`.
- `@since 26` | `OH/api/@ohos.arkui.UIContext.d.ts:2809` | `onBarRectChange(callback: Callback<Frame>): void`.
- `@since 26` | `OH/api/@ohos.arkui.UIContext.d.ts:3373` | `setCustomCursor(value: image.PixelMap, focusX?: number, focusY?: number): void` — custom cursor for a map drag handle.
- `@since 26` | `OH/api/@ohos.arkui.UIContext.d.ts:3782` | `getSizeLimitation(): componentSnapshot.SnapshotSizeLimitation`.
- `@since 26` | `OH/api/@ohos.arkui.UIContext.d.ts:4069` | `class SmartGestureController {enableSmartTapAndSlideGestures(enabled), registerMonitor(monitorCallback: Callback<BaseGestureHandlingProposal, GestureHandlingResolution>), unregisterMonitor, clearMonitors, requestSelected(id), clearSelected()}`; `:5625 getSmartGestureController(): SmartGestureController`; `:3794 BaseGestureHandlingProposal {action: SmartGestureAction, operateIntention: OperateIntention}`; `:3824 TargetedGestureProposal {node: FrameNode}`; subclasses `:3843 ClickActionProposal`, `:3873 SelectActionProposal`, `:3896 NoneActionProposal`, `:3918 BackPressActionProposal`, `:3940 PageSwitchActionProposal {pageCount}`, `:3979 ScrollActionProposal {distance?}`; `:4018 GestureHandlingResolution {constructor(isConsumed: boolean), isConsumed: boolean, selectedProposal?}`.
- `@since 26` | `OH/api/@ohos.arkui.UIContext.d.ts:5036/:5091` | `addLocalInputEventMonitor(eventMask: number, listener: InputEventListener): InputEventMonitor`; `removeLocalInputEventMonitor(monitor: InputEventMonitor): void`.
- `@since 26` | `OH/api/@ohos.arkui.UIContext.d.ts:5602/:5613/:5692` | `enableEventPassthrough(enabled: boolean, eventType: RawInputEventType): void`; `setTextSelectionClearPolicy(policy: TextSelectionClearPolicy): void`; `enum TextSelectionClearPolicy {KEEP_SELECTED_TEXT_ON_EXTERNAL_TOUCH=0, CLEAR_SELECTED_TEXT_ON_EXTERNAL_TOUCH=1}`.

### 3.5 `OH/component/enums.d.ts` (43 tags)
- `@since 26` | `OH/component/enums.d.ts:5383` | `DialogDisplayMode {SCREEN_BASED=0, WINDOW_BASED=1}`.
- `@since 26` | `OH/component/enums.d.ts:5585` | `InputEventSubTypeMask` — bitmask `LEFT_MOUSE_DOWN=1<<0 … MIDDLE_MOUSE_DRAGGING=1<<8, TOUCH_DOWN=1<<9, TOUCH_UP=1<<10, KEY_DOWN=1<<11, KEY_UP=1<<12`.
- `@since 26` | `OH/component/enums.d.ts:5726` | `InputEventInterceptAction {CONTINUE=0, BLOCK=1}`.
- `@since 26` | `OH/component/enums.d.ts:5789` | `GestureCollectIntervention {CONTINUE=0, DISCARD_LOWER=1, DISCARD_HIGHER=2, DISCARD_SELF=3, DISCARD_LOWER_PRIORITY_SIBLINGS=4}`.
- `@since 26` | `OH/component/enums.d.ts:5858` | `RawInputEventType {TOUCH=0, MOUSE=1}`.
- `@since 26` | `OH/component/enums.d.ts:5889/:5908/:5972` | `GestureShortcut {PRIMARY=0}`; `SmartGestureAction {NONE=0, PAGE_FORWARD=1, SCROLL_FORWARD=2, SELECT=3, CLICK=4, BACK_PRESS=5}`; `OperateIntention {TAP=0, SLIDE_FORWARD=1, BACK_PRESS=2}`.
- `@since 26` | `OH/component/enums.d.ts:1192` | `CANCEL = 3` (key event).

### 3.6 State management, graphics, theme, advanced V2 components
- `@since 26` | `OH/api/@ohos.arkui.StateManagement.d.ts:591` | `static getCustomComponentContext<T extends BaseCustomComponent>(customComponent: T): CustomComponentContext` (on `UIUtils`); `:652 enableWildcard?` on `addMonitor`; `:1192 export declare const ComponentActive: MethodDecorator`; `:1202 ComponentInactive: MethodDecorator`.
- `@since 26` | `OH/api/@ohos.arkui.StateManagement.d.ts:1224/:1235/:1251/:1301/:1348` | `interface CustomComponentContext {getReusePool(): IReusePool \| undefined}`; `interface IReusePool {getReusableInfo(constructor, reuseId?), preRender(builder)}`; `interface IReusableInfo {count, maxCount (default 100, max 200), reuseId?}`; `type ReusableComponentConstructor = Function`.
- `@since 26` | `OH/api/@ohos.arkui.drawableDescriptor.d.ts:116/:131/:148` | `release(): void`; `isReleased(): boolean`; `invalidate(): void`.
- `@since 26` | `OH/api/@ohos.arkui.drawableDescriptor.d.ts:278/:541/:560` | `PixelMapDrawableDescriptor` constructor; `interface HdrCompositionConfig {rect: Rectangle}`; `class PictureDrawableDescriptor extends DrawableDescriptor {constructor(src: image.Picture), setHdrComposition(config)}` — HDR map tiles / photos.
- `@since 26` | `OH/api/@ohos.arkui.node.d.ts:82/:121` | exports `ChildrenCountMode`; exports `BackgroundBlur, ContentBlur, ForegroundBlur` from `./arkui/Graphics`.
- `@since 26` | `OH/api/@ohos.arkui.theme.d.ts:64/:75/:86` | `primary?: ResourceColor`; `onPrimary?`; `container?` — the new system color roles.
- **Advanced "V2" components (all new in 26; file-level tags inflate the counts):** `ChipV2.d.ets` (143), `ComposeListItemV2.d.ets` (91), `ChipGroupV2.d.ets` (84), `EditableTitleBarV2.d.ets` (72), `TreeViewV2.d.ets` (46), `CounterV2.d.ets` (44), `DatePickerComponent.d.ets` (38), `ExceptionPromptV2.d.ets` (26), `ComposeTitleBarV2.d.ets` (25), `PopupV2.d.ets` (17), `SwipeRefresherV2.d.ets` (3), `ChipGroup.d.ets` (3), `Chip.d.ets` (2), `SegmentButton/SegmentButtonV2.d.ets` (2). Full V2 set under `OH/api/`: ChipGroupV2, ChipV2, ComposeListItemV2, ComposeTitleBarV2, CounterV2, DialogV2, EditableTitleBarV2, ExceptionPromptV2, PopupV2, ProgressButtonV2, SegmentButtonV2, SubHeaderV2, SwipeRefresherV2, ToolBarV2, TreeViewV2.

---

## 4. Notification

- `@since 26` | `OH/api/@ohos.notificationManager.d.ts:921` | `function openNotificationSettingsWithResult(context: UIAbilityContext): Promise<NotificationSetting>` — opens the semi-modal notification settings page **and returns what the user chose**; the first API that lets you read back the per-app switches.
- `@since 26` | `OH/api/@ohos.notificationManager.d.ts:995/:1006/:1017/:1028` | new `NotificationSetting` fields `lockScreenEnabled?: boolean`, `bannerEnabled?: boolean`, `badgeNumberEnabled?: boolean`, `notificationEnabled?: boolean` — drive your own "why am I not seeing alerts" onboarding instead of guessing.
- `@since 26` | `OH/api/@ohos.notificationExtensionSubscription.d.ts:48` | `openSubscriptionSettingsWithResult(context: UIAbilityContext): Promise<UserGrantSetting>` — perm `ohos.permission.SUBSCRIBE_NOTIFICATION`; `:166 export type UserGrantSetting = _UserGrantSetting`.
- `@since 26` | `OH/api/notification/NotificationCommonDef.d.ts:74` | `interface UserGrantSetting {userGrantEnabled: boolean, grantedBundleInfos?: Array<GrantedBundleInfo>}`.

---

## 5. Security / permissions

- `@since 26` | `OH/api/permissions.d.ts` (141 new strings) | app-usable ones: `ohos.permission.FLOAT_VIEW` (:2747) — floating window / 闪控球; `ohos.permission.ONSCREEN_AWARENESS` (:2827); `ohos.permission.SET_WINDOW_TOUCH_AREAS` (:3175); `ohos.permission.MANAGE_RECENT_SNAPSHOT` (:196); `ohos.permission.SET_WINDOW_ALPHA` (:200); `ohos.permission.CAMERA_SHARED` (:35); `ohos.permission.ACCESS_SHARED_FILE` (:3147); `ohos.permission.AGENT_FILE_ACCESS` (:3531); `ohos.permission.EXECUTE_DISTRIBUTED_INTENT` (:3235); `ohos.permission.ACCESS_DIGITAL_IDENTITY_ABILITY` (:3259); `ohos.permission.SUBSCRIBE_OUTDOOR_EXPLORATION_SERVICE` (:3475); `ohos.permission.KNOCK_COLLABORATION` (:3287); `ohos.permission.SUPPORT_CROSS_APP_EMBED_FOR_OA` (:3263); `ohos.permission.ACCESS_SUPPORT_FEEDBACK`/`ACCESS_SUPPORT_HELP` (:3243/:3247); `ohos.permission.NOTIFICATION_SYSTEM_SUBSCRIBER` (:3223); `ohos.permission.MANAGE_AOD` (:3251); `ohos.permission.ARKWEBCORE_SYS_CAP` (:3471); `ohos.permission.kernel.LOAD_CERTSIGN_LIBRARY_FOR_WEB` (:3275); `ohos.permission.SUPPORT_NP_PLUGIN_FOR_WEB` (:3279); `ohos.permission.MANAGE_SKILL` / `MANAGE_SKILL_PRIVILEGE` (:3299/:3303). The remainder are `ohos.permission.cli.*`, enterprise, TV, automotive and other system-only strings.

---

## 6. Form / 互动卡片 (互动卡片) — **NEGATIVE**

- `@since 26` | **none.** A regex pass over the whole 26-set for `FormKit|formHost|FormComponent|formInfo|formAgent|formProvider|formObserver|formEditExtension` returns **0 rows**; the only `@since 26` hits inside files matching `*form*` are unrelated (`OH/api/@ohos.data.uniformDataStruct.d.ts:198` and `:457`, `OH/api/application/ProcessInformation.d.ts:104`).
- For reference, the form surface that *exists* (all pre-26): `OH/api/@ohos.app.form.formInfo.d.ts`, `formProvider.d.ts`, `FormExtensionAbility.d.ts`, `FormEditExtensionAbility.d.ts`, `LiveFormExtensionAbility.d.ts`, `OH/api/@ohos.arkui.advanced.FormMenu.d.ets`, `OH/api/application/FormEditExtensionContext.d.ts`. **Do not claim new 互动卡片 APIs in 26.**

---

## 7. Media

- `@since 26` | `OH/api/@ohos.multimedia.image.d.ts` (210 tags — largest file) | pixel formats added: `:266 Y8 = 14`, `:274 ALPHA_U8 = 15`, `:285 ALPHA_F16 = 16` (FP16 alpha).
- `@since 26` | `OH/api/@ohos.multimedia.image.d.ts:2925` | `interface PackingOptionsForTiff {compression?: number (3 CCITT G3 / 4 CCITT G4 / 5 LZW), orientation?, xResolution?, yResolution?, resolutionUnit?}`; `:3087 tiffPackingOptions?: PackingOptionsForTiff` — **TIFF encode** for scanned/handwritten forms.
- `@since 26` | `OH/api/@ohos.multimedia.image.d.ts:2980/:3075` | `interface PackingSizeLimit {maxSize: Size, level: AntiAliasingLevel}`; `maxEmbedThumbnailDimension?: number`.
- Also high-count in 26: `OH/api/@ohos.multimedia.media.d.ts` (124), `OH/api/@ohos.multimedia.camera.d.ts` (84), `OH/api/@ohos.multimedia.audio.d.ts` (57), `OH/api/@ohos.multimedia.avsession.d.ts` (25).

---

## 8. AI / vision / agent / intents

**OpenHarmony side**
- `@since 26` | `OH/api/@ohos.app.ability.insightIntent.d.ts:144` | `enum QueryType {ALL='all', BY_PROPERTY='byProperty'}`; `:172 interface QueryEntityParam {queryType: QueryType, parameters?: Record<string, Object>}`.
- `@since 26` | `OH/api/@ohos.app.ability.insightIntent.d.ts:200` | `abstract class AppIntentEntity<T> implements IntentEntity {abstract onQueryEntity(params: QueryEntityParam): Promise<Array<T>>; displayName: string}` — an intent can now be **queried** for entities, not just executed; decorator field at `OH/api/@ohos.app.ability.InsightIntentDecorator.d.ts:540 supportedQueryProperties?: string[]`.
- `@since 26` | `OH/api/@ohos.app.agent.agentConstant.d.ts:19` | `declare namespace agentConstant {export enum AgentCardType {APP=0, ATOMIC_SERVICE=1}}` — syscap `Ability.AgentRuntime.Core`.
- `@since 26` | `OH/api/@ohos.bundle.skillManager.d.ts` **[module-new]** | `SkillInfoFlag {GET_SKILL_INFO_DEFAULT=0x0, WITH_DESCRIPTION=0x1, WITH_SRC_ENTRIES=0x2, WITH_PERMISSIONS=0x4, WITH_REQUEST_PERMISSIONS=0x8}`; `getSkillInfoForSelf(moduleName, skillName, flags): Promise<SkillInfo>`; `getSkillInfosForSelf(flags)`; `getSkillInfo(bundleName, moduleName, skillName, flags, userId?)`; `getSkillInfos(bundleName, flags, userId?)`; `getAllSkillInfos(flags, userId?)` — perms `ohos.permission.MANAGE_SKILL_PRIVILEGE` or `ohos.permission.MANAGE_SKILL`.
- `@since 26` | `OH/api/bundleManager/SkillInfo.d.ts:19` | "A skill is an independent functional unit that can be called by an agent application"; fields `bundleName, moduleName, skillName, skillType, skillPath, abilityName, versionCode, version?, visibility?, description?, srcEntries?, permissions?, requestPermissions?`; `enum SkillType {APP_SKILL=0, INDEPENDENT_SKILL=1}`.
- `@since 26` | `OH/api/@ohos.data.intelligence.d.ts:53` | `interface CloudModelInfo {modelType: string, modelVersionCode?}`; `:78 enum NetworkPolicy {WIFI_ONLY=0, WIFI_AND_CELLULAR=1}`; `:136 modelInfo?`; `:144 networkPolicy?`; `:292 function getSupportedCloudModel(): Promise<Array<CloudModelInfo>>` — on-device vs cloud model routing you can gate on Wi-Fi.
- `@since 26` | `OH/api/application/AgentCard.d.ts:60` | `type?: agentConstant.AgentCardType` (LOW_CODE variant is system-app only).
- `@since 26` | `OH/api/@ohos.app.ability.scriptManager.d.ts` **[module-new]** (10 tags, not detailed).

**HMS side**
- `@since 26` | `HMS/api/@hms.ai.A2A.d.ts` **[module-new]** (76 tags), syscap `AI.Agent.AgentKit` | `enum Role {AGENT=0, USER=1, UNSPECIFIED=2}`; `enum TaskState {SUBMITTED=0, WORKING=1, INPUT_REQUIRED=2, COMPLETED=3, CANCELED=4, FAILED=5, REJECTED=6, AUTH_REQUIRED=7, UNSPECIFIED=8}`; `interface Part {text?, raw?, url?, data?, mediaType?, filename?, metadata?}`; `interface Message {messageId, role, parts, contextId?, extensions?, referenceTaskIds?, taskId?}`; `interface Artifact {artifactId, parts, description?, extensions?, name?}`; `interface TaskStatus {state, timestamp?, message?}`; `interface Task {id, contextId, status, artifacts?, history?}`; `createA2AServer(agentCard: common.AgentCard, onData: OnDataCallback, want?: Want): Server`; `interface Server {start(), stop(), onMessage(data, sender), onAuth(data): string, updateStatus(taskId, status), addArtifact(taskId, taskArtifactParam)}`; `interface RequestContext {getAgentId, getUserInput, getMessage, getRelatedTasks, getCurrentTask, getTaskId, getContextId, getMetadata}`; `type OnDataCallback = (method: string, context: RequestContext) => void`. → your app can act as an **A2A agent server**.
- `@since 26` | `HMS/api/@hms.ai.vision.imageSuperResolution.d.ts:10` **[module-new]** | `declare namespace imageSuperResolution`; `:18 class ISPResponse extends visionBase.Response {pixelMap: image.PixelMap}`; `:35 class ImageSRAnalyzer extends visionBase.Analyzer` — super-resolve a low-res snapshot.
- `@since 26` | `HMS/api/@hms.ai.AICaption.d.ets:152` | `isCapabilitySupported(): boolean`.
- `@since 26` | `HMS/api/@hms.ai.DocumentScanner.d.ets:45` | `declare class DocumentScannerController`; `:54 isSheetDetectionSupported(): boolean`.
- Other HMS AI modules present: `HMS/api/@hms.ai.vision.{objectDetection, skeletonDetection, subjectSegmentation, textSearchImage (11 tags), visionBase}`, `HMS/api/@hms.ai.nlp.textProcessing` (`timestamp?`), `HMS/api/@hms.security.businessRiskIntelligentDetection`.

---

## 9. Map Kit (HMS)

- `@since 26` | `HMS/api/@hms.core.map.map.d.ts:1909` | `setSphereMapEnabled(enabled: boolean, params?: mapCommon.SphereParams): Promise<void>` — **3D globe** view.
- `@since 26` | `HMS/api/@hms.core.map.map.d.ts:1922` | `addSignalLine(signalParams: mapCommon.MapSignalParams): Promise<MapSignalLine>`; `:1939 removeSignalLineCache(signalLineId?: string): void`; `:5966 interface MapSignalLine extends BaseOverlay {setColors(colors: number[]), getColors(), setWidth(width), getWidth()}` — **traffic-congestion-style coloured route segments**, directly usable to paint vehicle speed/health along a track.
- `@since 26` | `HMS/api/@hms.core.map.mapCommon.d.ts:3995` | `interface MapSignalParams extends BaseOverlayOptions {signalId: string, points?: LatLng[] (0–10000; route must be ≥200 km), colors?: number[] (length must be 3 = weak/medium/strong, default [0xFFFC3C11, 0xFFFFDF42, 0xFF42B0FF]), width? (0–512, default 10), coordinateType?}`.
- `@since 26` | `HMS/api/@hms.core.map.map.d.ts:2737` | `addLineText(lineText: mapCommon.LineText): void`; `:2748 removeLineText(): void`; `HMS/api/@hms.core.map.mapCommon.d.ts:3904 interface LineText {lineNames: string[], lineNameIndexes: number[], nameOnRight?, color?, fontSize? (0–100, default 15px), strokeColor?, fontStyle?}` — **always-visible labels per polyline** (route names).
- `@since 26` | `HMS/api/@hms.core.map.map.d.ts:3544` | `fromScreenLocation(point: mapCommon.MapPoint, altitude: number): mapCommon.LatLng`; `:3573 toScreenLocation(position: mapCommon.LatLng, altitude: number): mapCommon.MapPoint` — screen↔geo that accounts for altitude (3D buildings/globe).
- `@since 26` | `HMS/api/@hms.core.map.mapCommon.d.ts` | `LocationMode MAP_ROTATE = 5` (camera centered, map rotates with the device), `MAP_ROTATE_NO_CENTER = 6`.
- `@since 26` | `HMS/api/@hms.core.map.mapCommon.d.ts:3831` | `interface SphereParams {sunLightEnabled?, cityLightEnabled?, animateDuration?, backgroundImage?: ResourceStr \| image.PixelMap, coverageImage?}`.
- `@since 26` | `HMS/api/@hms.core.map.offlineMapData.d.ts:10` **[module-new]** | `declare namespace offlineMapData` (syscap `Map.Core.OfflineMapData`); `:19 getRecommendedCityIdsByLatLngs(context: common.Context, latlngs: mapCommon.LatLng[]): Promise<string[]>` — **"download the offline map covering this route"**, exactly the fleet-tracking primitive.
- `@since 26` | `HMS/ets/kits/@kit.MapKit.d.ts` | barrel exports `mapCommon, map, MapComponent, staticMap, site, navi, sceneMap, petalMaps, offlineMapData, customInfoWindowCallback`.

---

## 10. Live View / 实况窗 (HMS LiveView Kit)

- `@since 26` | `HMS/api/@hms.core.liveview.liveViewManager.d.ts:1922` | `export interface CustomLayout extends LayoutData {abilityName: string, abilityParameters?: Record<string,string> (≤50 pairs)}`; `:801 LAYOUT_TYPE_CUSTOM = 100` — **the live-view content is now a real page of your ability**, not a fixed template.
- `@since 26` | `HMS/api/@hms.core.liveview.LiveViewCardExtensionAbility.d.ts` **[module-new]** | `export interface CardInfo {pagePath: string, storage?: LocalStorage}`; `export default class LiveViewCardExtensionAbility` (inherits `UIExtensionAbility`); `public onRender(param: Record<string, string>): CardInfo` — this is how the custom layout is rendered.
- `@since 26` | `HMS/api/@hms.core.liveview.LiveViewCardExtensionContext.d.ts` **[module-new]** | `LiveViewCardExtensionContext extends ExtensionContext`.
- `@since 26` | `HMS/api/@hms.core.liveview.liveViewManager.d.ts:896` | `progress?: number` (0–100); `:2029 EXTENSION_TYPE_PROGRESS = 5` (progress ring in the auxiliary area); `:480 lifeCycleMode?: LifeCycleMode`; `:2968 enum LifeCycleMode {STOP_BY_APP=0, AUTO_STOP_WHEN_APP_TERMINATE=1}` — keeps the 实况窗 alive after your process dies.
- `@since 26` | `HMS/api/@hms.core.liveview.liveViewManager.d.ts:501` | `subEvent?: string`; `:543 shareUrl?: string` (HTTPS only, non-empty) — send the tracking link straight from the live view.
- `@since 26` | `HMS/ets/kits/@kit.LiveViewKit.d.ts` | barrel exports `liveViewManager, LiveViewLockScreenExtensionAbility, LiveViewLockScreenExtensionContext, LiveViewCardExtensionAbility, LiveViewCardExtensionContext, CardInfo`.

---

## 11. File

- `@since 26` | `OH/api/@ohos.file.fs.d.ts` | 33 tags (file I/O additions).
- `@since 26` | `OH/api/@ohos.file.photoAccessHelper.d.ts` | 29 tags (photo/media-library additions).
- `@since 26` | `OH/api/permissions.d.ts:3147` | `ohos.permission.ACCESS_SHARED_FILE` — the sandbox-crossing file grant that pairs with the new `CAMERA_SHARED`/`ACCESS_SHARED_FILE` family.

---

## 12. Network

`OH/api/@ohos.net.connection.d.ts`
- `@since 26` | `:777` | `function refreshGlobalHttpProxy(): Promise<HttpProxy>`.
- `@since 26` | `:1143` | `function queryTraceRoute(destination: string, option?: TraceRouteOptions): Promise<TraceRouteInfo[]>` — perms `INTERNET` + `ACCESS_NET_TRACE_INFO`; `:2507 TraceRouteInfo {jumpNo, address, rtt: number[]}`; `:2482 TraceRouteOptions {maxJumpNumber? (1–30, default 30), packetsType?}`; `:2457 PacketsType {NETCONN_PACKETS_ICMP=0, NETCONN_PACKETS_UDP=1}`.
- `@since 26` | `:1167` | `function queryProbeResult(destination: string, duration: number): Promise<ProbeResultInfo>`; `:2541 ProbeResultInfo {lossRate (0–100), rtt: number[]}` — the app can now prove whether it is the network or the backend.
- `@since 26` | `:2063/:2348` | `enum Socks5DnsStrategy {SYSTEM_MODE=0, PROXY_MODE=1}`; `interface Socks5Proxy {host, port, username?, password?, dnsStrategy?, exclusionList?}`.

`OH/api/@ohos.net.http.d.ts`
- `@since 26` | `:424–493` | `HttpRequestOptions` new fields `reuseConnections?: boolean` (default true), `inactivityMs?: number` (default 118 s), `usingSocks5Proxy?: Socks5Proxy`, `enablePartialChain?: boolean`, `queryParams?: string \| QueryParamObject`, `body?: string \| Object \| ArrayBuffer`.
- `@since 26` | `:554/:595` | `interface ValidationContext {pemCerts: string[], x509Certs: X509Cert[], host: string, ip: string}`; `type ValidationCallback = (context: ValidationContext) => boolean \| Promise<boolean>` — **custom TLS pinning**, the single most valuable security addition for a fleet API client.
- `@since 26` | `:1501/:1898/:2001` | `requestSync(url: string, options?: HttpRequestOptions): HttpResponse`; `enableAutoCookie(enable: boolean): void`; `RequestMethod PATCH = "PATCH"`.
- `@since 26` | `:42/:673/:687` | `type Socks5Proxy = connection.Socks5Proxy`; `QueryParamValue`; `QueryParamObject = Record<string, QueryParamValue \| QueryParamValue[]>`.

`OH/api/@ohos.net.webSocket.d.ts`
- `@since 26` | `:169/:178` | `minSupportTlsProtocol?: TlsProtocol`; `supportOriginPort?: boolean`.
- `@since 26` | `:290/:576/:586` | `interface WebSocketOpenInfo {status: number, message: string, protocol?: string}`; `on('openInfo', callback: AsyncCallback<WebSocketOpenInfo>)`; `off('openInfo', ...)` — the HTTP status of a failed handshake, previously invisible.
- `@since 26` | `:1125` | `enum TlsProtocol {TLS_V_1_0=0, TLS_V_1_1=1, TLS_V_1_2=2, TLS_V_1_3=3}`.

---

## 13. Ability / continuation / collaboration

- `@since 26` | `OH/api/@ohos.application.DistributedExtensionContext.d.ts:30` | `connectServiceExtensionAbility(want: Want, options: ConnectOptions): number` — syscap `DistributedSched.AppCollaboration`; `:59 disconnectServiceExtensionAbility(connection: number): Promise<void>`.
- `@since 26` | `OH/api/@ohos.data.distributedKVStore.d.ts:2189` | `rekey(): Promise<void>` — rotate the database encryption key.
- `@since 26` | `OH/api/@ohos.distributedHardware.mechanicManager.d.ts:102` | `function isControlSupported(mechDeviceType?: MechDeviceType): boolean`.
- `@since 26` | `HMS/api/@hms.collaboration.accessoryAccessManager.d.ts:10` **[module-new]** (84 tags) | `declare namespace accessoryAccessManager` (syscap `Collaboration.Accessory.AccessManager`) — accessory/partner discovery + wakeup: `enum DiscoveryType {PARTNER_BLE_CONNECT=0}`; `enum ServiceName {PARTNER_APP_ACCESSORY_COLLABORATION='P_AppAccessoryCollaboration', PARTNER_SHARE_SERVICE='P_ShareService', PARTNER_DISTRIBUTED_CAMERA_SERVICE='P_DCameraService'}`; `enum WakeupType {START_ABILITY_BY_CALL=0}`; `interface PickerItemInfo {discoveryType, displayName, displayImage: image.PixelMap, requestAttachServiceInfo: Array<ServiceInfo>, hasScreen?, bleAddress?, bleMtuSize?, productId?, subProductId?}`; `interface AccessoryInfo {displayName, accessoryId?}`; `enum AccessEvent {PICKER_PRESENT=0, PICKER_DISMISS=1, PICKER_END_SUCC=2, PICKER_END_FAIL=3, SERVICE_ATTACHING=300, SERVICE_ATTACH_SUCC=301, ...}`; `interface StringResourceInfo {moduleName, stringResourceId, bundleName?}`; `interface WakeupInfo {wakeupType, bundleName, abilityName, briefDesc}` — hardwired accessory (in-vehicle terminal / dashcam) integration.
- `@since 26` | `OH/api/@ohos.app.ability.scriptManager.d.ts` **[module-new]** | script/automation manager (see §8).

---

## 14. Location (geoLocationManager) + background task

`OH/api/@ohos.geoLocationManager.d.ts` (34 tags)
- `@since 26` | `:57` | `function onLocationChange(request: LocationRequest \| ContinuousLocationRequest, callback: Callback<Location>): void` (perm `APPROXIMATELY_LOCATION`); `:100 offLocationChange`.
- `@since 26` | `:902/:913/:924` | `isGnssServiceSupported(): boolean`; `isGnssFenceServiceSupported()`; `isCachedGnssServiceSupported()` — **feature-detect before promising GNSS accuracy**.
- `@since 26` | `:935` | `findMatchingWlan(wlanBssidArray: Array<string>, rssiThreshold: number, needStartScan: boolean): Promise<Array<MatchingWlanInfo>>` (perms `LOCATION` + `APPROXIMATELY_LOCATION`); `:2360 interface MatchingWlanInfo {index, ssid}` — Wi-Fi-positioning interpolation for indoor fleet depots.
- `@since 26` | `:957` | `getCurrentDistrict(params?: DistrictRequestParams): Promise<DistrictInfo>` (syscap `Location.Geocoder`); `:1070 DistrictInfo {locale?, countryCode?, countryName?, administrativeArea?, subAdministrativeArea?, locality?, subLocality?}`; `:1144 DistrictRequestParams {locale?, timeoutMs? (default 5000)}` — reverse geocode without a network SDK.
- `@since 26` | `:977/:998/:1040` | `startBluetoothSearch(request: BluetoothSearchRequestParams, callback: Callback<BluetoothScanResult>): void`; `stopBluetoothSearch`; `BluetoothSearchRequestParams {deviceIdArray: Array<string>, rssiThreshold?}` — BLE-beacon/pet-tag-style ranging.
- `@since 26` | `:1012/:2926` | `getPostProcessingTrack(sportsType: SportsType): Promise<Array<Location>>`; `SportsType SKIING = 4` (only SKIING supported) — track smoothing already computed by the system.
- `@since 26` | `:2026/:2226/:2984` | `Location.isFromMock?: boolean` (**cheat/spoof detection for driver-reported positions**); `Poi additionalInfo?: string`; `interface Point {latitude, longitude}`.

`OH/api/@ohos.resourceschedule.backgroundTaskManager.d.ts` (27 tags)
- `@since 26` | `:206` | `requestAuthFromUserByDialog(context: Context, callback: Callback<UserAuthResult>): void` — requests `MODE_SPECIAL_SCENARIO_PROCESSING` authorization via a system dialog (perm `ohos.permission.KEEP_BACKGROUND_RUNNING`); `:241 checkSpecialScenarioAuthResult(context: Context): Promise<UserAuthResult>`.
- `@since 26` | `:371/:535/:544` | `detailedReason?: ContinuousTaskDetailedCancelReason`; `suspendMessage?: SuspendMessage`; `interface SuspendMessage {message: string, reason: ContinuousTaskSuspendReason}` — the system now *tells you why* tracking was killed.
- `@since 26` | `:1374` | `MODE_NEARLINK = 14` (`BackgroundMode`).
- `@since 26` | — | `enum ContinuousTaskDetailedCancelReason {USER_CANCEL_REMOVE_NOTIFICATION=3, SYSTEM_CANCEL_DATA_TRANSFER_LOW_SPEED=4, SYSTEM_CANCEL_AUDIO_PLAYBACK_NOT_RUNNING=6, SYSTEM_CANCEL_AUDIO_RECORDING_NOT_RUNNING=7, SYSTEM_CANCEL_NOT_USE_LOCATION=8, SYSTEM_CANCEL_NOT_USE_BLUETOOTH=9, SYSTEM_CANCEL_NOT_USE_MULTI_DEVICE=10, SYSTEM_CANCEL_USE_ILLEGALLY=11, SYSTEM_CANCEL_DATA_TRANSFER_NOT_UPDATE=12, SYSTEM_CANCEL_VOIP_NOT_RUNNING=13, SYSTEM_CANCEL_USER_UNAUTHORIZED=14}`.
- `@since 26` | — | `enum ContinuousTaskSuspendReason {SYSTEM_SUSPEND_VOIP_NOT_USED=13, SYSTEM_SUSPEND_BLUETOOTH_DATA_NOT_EXIST=14, SYSTEM_SUSPEND_POSITION_NOT_MOVED=15, SYSTEM_SUSPEND_AUDIO_PLAYBACK_MUTE=16, SYSTEM_SUSPEND_NEARLINK_NOT_USED=17, SYSTEM_SUSPEND_NEARLINK_DATA_NOT_EXIST=18, SYSTEM_SUSPEND_USER_UNAUTHORIZED=19}`.

---

## 15. 平行视界 (parallel view) / 一多 (one-develop-multi-deploy) — **NEGATIVE**

- `@since 26` | **none.** `rg -i 'parallel|平行视界|dualPage|splitScreen|一多|oneMulti|multiDeploy|responsiveLayout'` over `OH/api` + `OH/component` `.d.ts`/`.d.ets` returns **only gesture hits**: `OH/component/common.d.ts:19041 parallelGesture(gesture, mask?)`, `OH/component/common.d.ts:22475 shouldBuiltInRecognizerParallelWith`, `OH/component/common.d.ts:26744 addParallelGesture<T>`, `OH/component/gesture.d.ts:179 Parallel` (GestureMode), `OH/component/enums.d.ts:3898 PARALLEL` (NestedScrollMode), `OH/component/scroll_bar.d.ts:167` (doc prose). **平行视界 is not exposed as a named API in this SDK.**
- `@since 26` | **free-form — no dedicated symbol.** No `freeMultiWindow` symbol exists; "freeform window" appears only in doc prose (`OH/api/@ohos.app.ability.StartOptions.d.ts`, `OH/api/@ohos.window.d.ts`). What you actually use: `OH/api/@ohos.bundle.bundleManager.d.ts:643 export enum SupportWindowMode`; `OH/api/@ohos.app.ability.StartOptions.d.ts:247 supportWindowModes?: Array<bundleManager.SupportWindowMode>`; `OH/api/@ohos.window.d.ts:7465 setSupportedWindowModes(...)`. The 26-era responsive machinery that *is* real is the Environment API (§3.3) plus `WindowPostureMode`/`AcrossDisplayPresentation`/`SplitRatioPreference` (§2).

---

## 16. Other whole-module-new subsystems worth knowing (26)

- `@since 26` | `OH/api/@ohos.busManager.serial.d.ts` **[module-new]** | serial-bus manager (46 tags).
- `@since 26` | `OH/api/@ohos.FusionConnectivity.ranging.d.ts` **[module-new]** | ranging API (41 tags) — precise distance to a peer device.
- `@since 26` | `OH/api/@ohos.nearlink.*` **[module-new]** — the whole NearLink stack is API 26: `ssap` (81), `constant` (69), `remoteDevice` (63), `advertising` (33), `dataTransfer` (31), `scan` (25), `cdsm`, `manager`. `BackgroundMode.MODE_NEARLINK = 14` (§14) is its background counterpart.
- `@since 26` | `OH/api/@ohos.datashare.*`, `OH/api/@ohos.security.cert.d.ts` (53), `OH/api/@ohos.security.cryptoFramework.d.ts` (40), `OH/api/@ohos.security.huks.d.ts` (18), `OH/api/@ohos.i18n.d.ts` (65), `OH/api/@ohos.graphics.text.d.ts` (28), `OH/api/@ohos.data.relationalStore.d.ts` (37), `OH/api/@ohos.enterprise.restrictions.d.ts` (73), `OH/api/@ohos.enterprise.applicationManager.d.ts` (39) | additional 26-tagged surfaces not drilled into here.
- `@since 26` | `OH/api/@ohos.arkui.advanced.*V2.d.ets` | see §3.6.

---

## TOP 10 most usable for a WebView-shell fleet-tracking app on phone + tablet + 2in1

1. **`OH/api/@ohos.net.http.d.ts:554/:595` — `ValidationContext` + `ValidationCallback`** — per-request TLS pinning for the fleet backend is the one security control that decides whether enterprise customers will ship your shell at all.
2. **`OH/api/@ohos.window.floatView.d.ts` [module-new] (+ `OH/api/@ohos.window.d.ts:4366` float-navigation avoid area)** — a real system-hosted floating window bound to a 闪控球 (`FloatViewState.IN_FLOATING_BALL`) is the native "keep tracking while the user does something else" affordance a WebView page cannot build.
3. **`OH/api/@ohos.resourceschedule.backgroundTaskManager.d.ts:206/:241` — `requestAuthFromUserByDialog` / `checkSpecialScenarioAuthResult`** — turns continuous tracking from "silently killed" into an explicit, user-granted special scenario, and `SuspendMessage`/`detailedReason` tells you why it stopped.
4. **`OH/api/@ohos.window.d.ts:2272` — `getAllWindowLayoutInfo` + the new `Environment` API (`OH/component/common.d.ts:704 ReadonlyEnvKey.WINDOW_AVOID_AREA`)** — one source of truth for insets/avoid areas so the map canvas and floating readouts lay out correctly on phone, tablet, 2in1 and half-folded, without `on('avoidAreaChange')` plumbing.
5. **`OH/api/@ohos.notificationManager.d.ts:921` — `openNotificationSettingsWithResult` (+ `lockScreenEnabled`/`bannerEnabled`/`badgeNumberEnabled`/`notificationEnabled`)** — the highest-value root cause of "I didn't get the alert" complaints; you can now read the user's actual switches and guide them back.
6. **`OH/api/@ohos.geoLocationManager.d.ts:935/:977/:2026` — `findMatchingWlan`, `startBluetoothSearch`, `Location.isFromMock`** — indoor/depot positioning plus spoof detection on driver-reported positions; `:957 getCurrentDistrict` gives offline-friendly reverse geocoding (OH side only — `@kit.LocationKit`).
7. **`OH/api/@ohos.web.webview.d.ts:5022` — `setErrorPageEnabled(enable, includeSubframe)` + `getSubframeErrorPageEnabled()`** — the dashboard is an iframe inside your shell, so sub-frame failure visibility is the difference between a blank panel and a diagnosable one.
8. **`OH/api/@ohos.net.connection.d.ts:1143/:1167` — `queryTraceRoute` / `queryProbeResult` (+ `OH/api/@ohos.net.webSocket.d.ts:290 WebSocketOpenInfo`)** — field diagnostics that distinguish "vehicle offline" from "network bad" from "our server slow", which is the #1 support cost in fleet ops.
9. **`HMS/api/@hms.core.map.offlineMapData.d.ts:19` [module-new] — `getRecommendedCityIdsByLatLngs` (+ `HMS/api/@hms.core.map.map.d.ts:1922 addSignalLine` / `:2737 addLineText`)** — download exactly the offline map for a route, then paint speed/congestion colours and route names onto it; tablet/2in1 benefit most from the bigger canvas. `@kit.MapKit`.
10. **`HMS/api/@hms.core.liveview.liveViewManager.d.ts:1922` — `CustomLayout` / `LAYOUT_TYPE_CUSTOM=100` + `HMS/api/@hms.core.liveview.LiveViewCardExtensionAbility.d.ts` `onRender`** — an ETA/distance/progress 实况窗 rendered from your own page, with `lifeCycleMode` keeping it alive; visible with the phone locked without waking the WebView.
