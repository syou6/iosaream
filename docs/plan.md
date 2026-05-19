# OkiMission — 技術アーキテクチャ計画（深掘り版 v2）

## Context

OkiMission は iOS 26 AlarmKit を中核に据えた「ミッション完了で止まるアラーム」アプリ（Wayk 日本版）。
リポジトリ `/home/user/iosaream`（ブランチ `claude/okimission-alarmkit-design-NTgxV`）は README.md 1 行のみのグリーンフィールド。
ユーザーの設計レポートで業務／コスト／競合／法務の意思決定はほぼ完了。本計画は **実装可能性のあるレベルまでの技術アーキテクチャと、各決定の再検証チェックポイント** に絞る。

v1 が浅いとの指摘を受け、本 v2 では (a) Apple フレームワークの実 API 粒度、(b) ミッションエンジン状態機械・アンチチート、(c) Postgres DDL / RLS、(d) 特商法 field-level 要件、(e) Privacy Manifest、(f) StoreKit/RevenueCat 製品設計、(g) CI/CD、(h) パフォーマンス予算、(i) アクセシビリティ、(j) Liquid Glass 対応まで深掘りする。

プロジェクト識別子は全てプレースホルダ（`com.example.okimission` 系）。

---

## 0. ロックイン決定（早見表）

| 領域 | 決定 |
|---|---|
| 最低 iOS | 26.0、iPhone 11 (A13) 以降、A14 必要なら 26.2 検討 |
| ベース | `jacobsapps/ADHDAlarms`（MIT）フォーク参考 |
| アラーム | AlarmKit 1.0 |
| Live Activity | ActivityKit |
| 物体検出 | Apple Vision + CreateML（YOLO 不可・AGPL） |
| 姿勢推定 | `VNDetectHumanBodyPoseRequest` |
| AI 生成 | Gemini 2.5 Flash 経由 Supabase Edge Function |
| 音声 | ElevenLabs Starter で 20–30 種事前生成しバンドル同梱 |
| Backend | Supabase Pro |
| 課金 | RevenueCat + StoreKit 2、Small Business Program (15%) |
| 分析 | PostHog Free |
| クラッシュ | Sentry Free |
| Push | APNs 直送（Supabase Edge Function 経由） |
| ローカライズ | JA 主／EN 従 |
| アーキテクチャ | **MV パターン（SwiftUI ネイティブ）＋ Observation framework**。TCA / MVVM は採用しない（個人開発・ペイロード小・iOS 26 専用なので `@Observable` で十分） |
| DI | コンストラクタ注入＋ `EnvironmentValues` 拡張。ライブラリ無し（Factory / Resolver / Swinject 不要） |
| Navigation | `NavigationStack` + 型付き Route enum。Coordinator パターン不採用 |
| 同時実行 | Swift Concurrency（async/await/actor）一本。Combine は ActivityKit/RevenueCat の薄いブリッジでのみ |
| デザイン | iOS 26 Liquid Glass full adoption（`.glassEffect()`, `Material.glass`） |

---

## 1. Xcode プロジェクト・ターゲット構成

ワークスペース `OkiMission.xcworkspace` ＋単一 `OkiMission.xcodeproj`。SPM 依存はプロジェクト直結（ローカル SPM パッケージなし）。

### 1.1 ターゲット一覧

| ターゲット | 種別 | 目的 | Bundle ID（placeholder） | 主要 Capabilities |
|---|---|---|---|---|
| `OkiMission` | iOS App | 全機能 UI／ミッション／カメラ／音声 | `com.example.okimission` | AlarmKit, Sign in with Apple, Push, App Groups, Background Modes (audio/processing/remote-notification), Time Sensitive Notifications, HealthKit (deferred) |
| `OkiMissionWidget` | Widget Extension | Live Activity, ホーム画面 widget, Lock Screen widget | `com.example.okimission.widget` | App Groups, Push (Live Activity remote update) |
| `OkiMissionIntents` | App Intents Extension | StartMission/Snooze/Stop intent 低レイテンシ解決 | `com.example.okimission.intents` | App Groups, AlarmKit (read) |
| `OkiMissionWatch` | watchOS App（**Phase 2、launch 後**） | 独自 watch UI | `com.example.okimission.watchkitapp` | — |
| `OkiMissionTests` | Unit | XCTest + Swift Testing | — | — |
| `OkiMissionUITests` | UI | UI スモーク | — | — |
| `OkiMissionSnapshotTests` | Unit | swift-snapshot-testing | — | — |

### 1.2 SPM 依存（バージョン pin）

| Package | 範囲 | 用途 |
|---|---|---|
| `purchases-ios` (RevenueCat) | 5.x | StoreKit 2 ラッパ＋entitlement |
| `supabase-swift` | 2.x | Auth / Postgres / Edge Functions |
| `sentry-cocoa` | 8.x | Crash + perf |
| `posthog-ios` | 3.x | Analytics |
| `swift-snapshot-testing` (Point-Free) | 1.x | Snapshot test |
| `swift-collections` (Apple) | 1.x | OrderedSet/Deque（mission queue） |

`@available(iOS 26, *)` 修飾は最低 OS が 26 なので原則不要。条件分岐は **Apple Watch companion** と **iPad** 大画面レイアウトのみ。

### 1.3 Build Configurations / Schemes

| Scheme | Configuration | Bundle ID Suffix | StoreKit | RC 環境 | Supabase 環境 | Sentry DSN |
|---|---|---|---|---|---|---|
| `OkiMission-Debug` | Debug | `.dev` | StoreKit Configuration File `OkiMission.storekit` | Sandbox | dev project | dev |
| `OkiMission-Beta` | Beta | （無） | 実 App Store sandbox | Production | prod | prod |
| `OkiMission-Release` | Release | （無） | 実 App Store | Production | prod | prod |

ENV 変数は xcconfig（`Config/Debug.xcconfig` 等）で管理。秘匿値は **Xcode Cloud secret** に置き、xcconfig からは `$(SECRET_API_KEY)` で参照。リポジトリにはコミットしない。

### 1.4 Swift / Compiler 設定

- Swift 6.0 strict concurrency: **Complete** モード（warning ではなく error）。Sendable 違反はビルド失敗扱い。
- `SWIFT_UPCOMING_FEATURE_*` 全 ON（`StrictConcurrency`, `ExistentialAny`, `InternalImportsByDefault` 等）
- Optimization: Debug `-Onone`, Beta/Release `-O`（whole module）, Release は `-Osize` ではなく `-O`（起動速度優先、サイズより）
- Library Evolution: app target は OFF（バイナリ拡張なし）、widget/intents extension も OFF

---

## 2. モジュール・フォルダレイアウト

```
OkiMission/
  App/
    OkiMissionApp.swift           // @main, ModelContainer 注入, Sentry 即時初期化
    Bootstrap.swift               // 起動シーケンス（順序が重要：§17）
    RootView.swift                // 認証状態で分岐
    Routes/                       // Route enum, NavigationStack path
  Core/
    Persistence/
      ModelContainer+Factory.swift
      Schema/                     // VersionedSchema 群
        SchemaV1.swift
      Models/
        Alarm.swift, MissionTemplate.swift, MissionRun.swift,
        AudioPack.swift, UserProfile.swift, SubscriptionCacheSnapshot.swift,
        AnalyticsOutbox.swift     // オフライン時のイベントバッファ
      Repositories/
        AlarmRepository.swift, MissionRepository.swift, UserRepository.swift
      Migrations/
        Migration_V1_to_V2.swift  // 雛形のみ、出番後置き
    Concurrency/
      AsyncDebouncer.swift, TaskQueue.swift, CancellableContinuation.swift
    Logging/
      Logger+Sentry.swift         // os.Logger → Sentry breadcrumb bridge
      LogCategory.swift
    Errors/
      DomainError.swift           // typed error hierarchy
      ErrorMapper.swift           // 内部エラー → user-facing message
    Time/
      Clock.swift                 // protocol
      SystemClock.swift, TestClock.swift
    Feature/                      // フィーチャーフラグ（remote config 不採用、ローカル enum）
      FeatureFlag.swift
  DesignSystem/
    Tokens/
      OMColor.swift               // semantic, dark/light/contrast variant
      OMSpacing.swift              // 4/8/12/16/24/32 グリッド
      OMTypography.swift           // Dynamic Type 対応
      OMRadius.swift, OMShadow.swift
    Components/
      OMButton.swift, OMCard.swift, OMSheet.swift,
      OMProgressRing.swift, OMGlassPanel.swift  // Liquid Glass
    Haptics/
      OMHaptic.swift               // CHHapticEngine wrapper
    Animations/
      OMSpring.swift, OMTransition.swift
    Iconography/
      OMSymbol.swift               // SF Symbols 6 wrapper
  Services/
    AlarmKit/
      AlarmService.swift
      AlarmConfigurationBuilder.swift
      AlarmPresentationFactory.swift
      AlarmAuthorizationStore.swift
      AlarmMetadataPayload.swift   // AlarmMetadata 準拠
      AlarmEventBus.swift
    LiveActivity/
      ActivityController.swift
      AlarmActivityAttributes.swift
      Renderers/
        LockScreenView.swift
        DynamicIslandCompact.swift
        DynamicIslandExpanded.swift
        StandByView.swift
    Audio/
      AudioPackManager.swift
      PrebakedSoundCatalog.swift   // 静的データ
      AudioSessionCoordinator.swift // AVAudioSession orchestration
    Camera/
      CameraSession.swift          // actor
      CameraPermission.swift
      CameraOrientationObserver.swift
    Vision/
      VisionPipeline.swift
      FrameBroker.swift            // actor, fps throttle
      RequestQueue.swift
    CoreML/
      ModelLoader.swift            // actor, hot cache
      JapaneseObjectsModel.swift   // 自前 .mlmodelc wrapper
      PoseSmoother.swift
    Mission/                       // ミッションエンジン共通（features ではなく services）
      MissionRunner.swift          // 状態機械
      MissionStateMachine.swift
      MissionAntiCheat.swift
      MissionRestoration.swift     // kill 復旧
    AI/
      GeminiProxyClient.swift
      MissionGenerationCache.swift
      FallbackTemplateLibrary.swift // バンドル同梱 JSON
    Auth/
      SupabaseAuthService.swift
      SignInWithAppleCoordinator.swift
      NonceGenerator.swift
      KeychainStore.swift
    Subscriptions/
      RevenueCatService.swift
      EntitlementStore.swift       // @Observable, source of truth
      TokushohoGate.swift          // purchase 前の最終確認画面 enforcer
      StoreKitListener.swift       // Transaction.updates 監視（init 時に起動）
    Push/
      APNsRegistrar.swift
      RemoteNotificationRouter.swift
    Analytics/
      PostHogClient.swift
      EventRegistry.swift          // 全イベント列挙
      AnalyticsOutbox.swift        // オフライン flush
    Crash/
      SentryBootstrap.swift
      BreadcrumbBridge.swift
    Sync/
      PostgresMirrorService.swift
      SyncQueue.swift
    Network/
      HTTPClient.swift             // URLSession + retry
      Reachability.swift           // NWPathMonitor wrapper
  Features/
    Onboarding/
      OnboardingFlow.swift, OnboardingView.swift, PermissionGate.swift
    Paywall/
      PaywallView.swift, TokushohoSheet.swift, PaywallVariantSelector.swift
    AlarmList/
      AlarmListView.swift, NextAlarmCard.swift
    AlarmEditor/
      AlarmEditorView.swift, ScheduleEditor.swift, SoundPickerView.swift,
      MissionPickerView.swift, SnoozePolicyEditor.swift
    AlarmFiring/
      MissionLauncherView.swift, AlarmFiringStateView.swift
      Intents/
        StartMissionIntent.swift, SnoozeIntent.swift, StopAlarmIntent.swift,
        NavigateToMissionIntent.swift, QuickCreateAlarmIntent.swift,
        ToggleAlarmIntent.swift, AlarmEntity.swift, AppShortcuts.swift
    Missions/
      ObjectHunt/
        ObjectHuntMission.swift, ObjectHuntView.swift, ObjectHuntEngine.swift
      Pushups/
        PushupMission.swift, PushupView.swift, PushupRepCounter.swift
      Squats/
        SquatMission.swift, SquatView.swift, SquatRepCounter.swift
      Math/
        MathMission.swift, MathView.swift, MathProblemGenerator.swift
      Shake/
        ShakeMission.swift, ShakeView.swift, MotionMonitor.swift
      Barcode/
        BarcodeMission.swift, BarcodeView.swift
      Shared/
        Mission.swift, MissionContext.swift, MissionOutcomeReport.swift,
        MissionView+Common.swift, MissionFramingView.swift, MissionRouter.swift
    History/
      HistoryView.swift, StreakCalendar.swift, ShareImageRenderer.swift
    Settings/
      SettingsView.swift, AccountSection.swift, SubscriptionSection.swift,
      MissionPreferencesSection.swift, LocaleSection.swift, AboutSection.swift,
      DeleteAccountFlow.swift
    Legal/
      PrivacyPolicyView.swift, TermsView.swift, TokushohoView.swift,
      OSSLicensesView.swift
  Resources/
    Sounds/                        // 20–30 .caf
    Models/                        // .mlmodelc bundles
    FallbackTemplates/             // ja.json, en.json
    Localizable.xcstrings
    InfoPlist.xcstrings            // 権限文言の翻訳
    Assets.xcassets                // app icon, accent color
  Supporting/
    Info.plist
    OkiMission.entitlements
    PrivacyInfo.xcprivacy
    OkiMission.storekit            // dev 用 StoreKit Configuration
```

---

## 3. アーキテクチャパターン詳細

### 3.1 MV パターン採用理由

- iOS 26 専用＝ `@Observable` 利用可、ViewModel boilerplate 不要
- 個人開発＝ TCA の学習・型ボイラープレートは ROI 非合理
- SwiftData は ModelContext を直接 View に渡せるので Repository 経由のラッピング層は必要箇所のみ

### 3.2 状態管理

- **永続**: SwiftData (`@Model`)
- **UI 状態**: `@Observable` クラス（`*Model.swift`）または `@State`
- **クロスフィーチャー状態**: `EntitlementStore`, `AuthStore`, `AlarmEventBus`（全て `@Observable` シングルトン actor または class）
- **設定値**: `@AppStorage`（軽量）、複雑なものは UserDefaults 直書きの `@Observable` ラッパ

### 3.3 DI

```
App
 ├─ ModelContainer 注入 → .modelContainer(...)
 ├─ EnvironmentValues 拡張で AlarmService, GeminiProxyClient 等を注入
 └─ EntitlementStore は @Environment(EntitlementStore.self)
```

テスト時は `previewContainer(seed:)` ファクトリで in-memory ModelContainer ＋ モックサービスを差し替え。

### 3.4 Navigation

```swift
enum AppRoute: Hashable { case alarmDetail(UUID), missionRun(UUID), settings, paywall, tokushoho, legal(LegalPage) }
```

`NavigationStack` の `path: Binding<[AppRoute]>` で型付き遷移。Deep link / App Intent からの遷移は `RootView` の `.onOpenURL` / `.onContinueUserActivity` で `path` を構築。

### 3.5 Error Strategy

```swift
enum DomainError: Error {
  case alarmKitNotAuthorized
  case missionFailed(MissionFailureReason)
  case networkUnavailable
  case subscriptionRequired
  case dataCorrupted(table: String)
  ...
}
```

`ErrorMapper` で `DomainError → LocalizedStringResource` 変換。Sentry には `domainError` タグで分類。ユーザー向け文言は String Catalog で `error.alarmkit.not_authorized` 等のキーで管理。

---

## 4. SwiftData スキーマ詳細

### 4.1 `@Model` 全体像

```
Alarm                ← 1..n → MissionRun
MissionTemplate      ← 1..n → MissionRun, ← n..1 ← Alarm (optional)
AudioPack            ← n..1 ← Alarm (FK by identifier)
UserProfile          (singleton row)
SubscriptionCacheSnapshot (singleton row)
AnalyticsOutbox      (event queue)
```

### 4.2 Alarm

| プロパティ | 型 | 制約 |
|---|---|---|
| `id` | `UUID` | PK |
| `label` | `String` | max 64 chars |
| `scheduleKind` | `AlarmScheduleKind` | enum stored as `Int` |
| `fireDate` | `Date?` | scheduleKind=.oneShot 時必須 |
| `weekdayMask` | `Int` | bit 0=日 ... bit 6=土 |
| `timeOfDayHour` | `Int?` | 0–23 |
| `timeOfDayMinute` | `Int?` | 0–59 |
| `countdownSeconds` | `Int?` | scheduleKind=.countdown 時必須、min 60 |
| `soundId` | `String` | AudioPack.identifier FK |
| `missionTemplateId` | `UUID?` | nil=ミッションなし（標準アラーム） |
| `snoozeMaxCount` | `Int` | 0–10 |
| `snoozeDurationSec` | `Int` | 60–900 (1–15min) |
| `allowSnooze` | `Bool` | |
| `isEnabled` | `Bool` | |
| `alarmKitId` | `UUID?` | AlarmKit 返却 ID、nil=未スケジュール |
| `createdAt`, `updatedAt` | `Date` | |
| `runs` | `[MissionRun]` | `@Relationship(deleteRule: .cascade, inverse: \MissionRun.alarm)` |

複合制約: `scheduleKind=.recurringWeekly` の時は `timeOfDayHour/Minute` 必須、`weekdayMask != 0` 必須。これは Repository 層の `validate()` メソッドでチェック。

`Index`: `id`（暗黙 PK）、`isEnabled`（アクティブアラーム一覧で頻繁にクエリ）、`alarmKitId`（AlarmKit→domain 逆引き）。SwiftData の `@Attribute(.unique)` は `id` と `alarmKitId` に付与。

### 4.3 MissionTemplate

| プロパティ | 型 | 制約 |
|---|---|---|
| `id` | `UUID` | PK |
| `kind` | `MissionKind` | enum |
| `difficulty` | `MissionDifficulty` | enum |
| `parametersJSON` | `String` | Codable struct を JSON エンコード（kind 別に異なる構造） |
| `aiGenerated` | `Bool` | |
| `localeHint` | `String` | "ja-JP" |
| `targetDate` | `Date?` | AI 生成テンプレの「翌朝向け」日付 |
| `consumed` | `Bool` | AI prefetch テンプレが使用済か |
| `createdAt` | `Date` | |

Codable parameter 型（kind 別）:
- `ObjectHuntParameters { targets: [ObjectClass], minConfidence: Double = 0.6, requiredCount: Int = 3, timeLimitSec: Int = 90 }`
- `PushupParameters { reps: Int, formStrictness: FormLevel }`
- `SquatParameters { reps: Int, depthRequirement: DepthLevel }`
- `MathParameters { problemCount: Int, operations: [Operation], maxValue: Int, allowedMistakes: Int }`
- `ShakeParameters { intensity: Double, durationSec: Int }`
- `BarcodeParameters { allowedSymbologies: [VNBarcodeSymbology.RawValue] }`

### 4.4 MissionRun

| プロパティ | 型 |
|---|---|
| `id` | UUID PK |
| `alarmId` | UUID FK |
| `alarm` | `Alarm?` inverse |
| `templateId` | UUID FK |
| `startedAt`, `completedAt?` | Date |
| `outcome` | `MissionOutcome` (.success / .failed / .abandoned / .skipped / .cheated) |
| `metricsJSON` | String |
| `snoozeCountBefore` | Int |
| `appBackgroundedDuringMission` | Bool | アンチチート signal |
| `clockTamperedDuringMission` | Bool | systemUptime 検証 |

### 4.5 AudioPack

| プロパティ | 型 |
|---|---|
| `identifier` | String PK（例 `"jp_morning_gentle_01"`） |
| `displayNameJA`, `displayNameEN` | String |
| `bundleFilename` | String |
| `durationSec` | Double |
| `requiresEntitlement` | SubscriptionTier |
| `previewHash` | String | バンドル内ファイルのハッシュ、検証用 |

### 4.6 UserProfile（シングルトン）

| プロパティ | 型 |
|---|---|
| `id` | UUID（Supabase user id） |
| `appleUserIdentifier` | String（Keychain 同期） |
| `email?` | String（Apple relay の可能性あり） |
| `displayName?` | String |
| `preferredLocale` | String |
| `streakCount` | Int |
| `lastSuccessDate?` | Date |
| `currentStreakStartDate?` | Date |
| `longestStreak` | Int |
| `onboardingCompletedAt?` | Date |
| `notificationsAuthorized` | Bool |
| `alarmKitAuthorized` | Bool |
| `cameraAuthorized` | Bool |

### 4.7 SubscriptionCacheSnapshot（シングルトン）

RC が真の source of truth。これは起動瞬間〜RC resolve までの bridge。
- `cachedTier: SubscriptionTier`
- `cachedExpiresAt: Date?`
- `lastVerifiedAt: Date`
- `productIdentifier: String?`

### 4.8 AnalyticsOutbox

オフライン時 PostHog が flush 失敗したイベントをここに退避し、Reachability 復活時に再送。
- `id` UUID PK
- `eventName` String
- `propertiesJSON` String
- `timestamp` Date
- `attemptCount` Int

### 4.9 マイグレーション戦略

`VersionedSchema` `SchemaV1` を初版から作成。`MigrationPlan` 雛形（empty stages）も用意。**初版リリース後、最初の breaking change がきた瞬間に v2 と `MigrationStage.lightweight` または `.custom` で接続**。これを launch 前から仕込んでおくことで、初回マイグレーションの設計コストを launch 後でなく今支払う。

### 4.10 SwiftData 制約 / pitfall

- `@Attribute(.externalStorage)` は `metricsJSON` / `parametersJSON` が肥大化する場合のみ。通常は 1KB 未満想定なので不要。
- `@Relationship(deleteRule: .cascade)` は Alarm→MissionRun のみ。MissionTemplate は再利用される可能性があるため `.nullify`。
- iCloud 同期は **採用しない**（Phase 2）。Multi-device 同期は Supabase Postgres ミラー経由。

---

## 5. AlarmKit 深掘り統合

### 5.1 認可フロー

`AlarmAuthorizationStore` (actor):
1. `init` で `AlarmManager.shared.authorizationState` を取得（`.notDetermined / .authorized / .denied`）
2. 初回起動の Onboarding ステップで `try await AlarmManager.shared.requestAuthorization()` を呼ぶ
3. `authorizationUpdates` async sequence を購読し、設定アプリで変更された場合に store 更新
4. `.denied` 時はガイドアラート＋「設定を開く」ボタン（`UIApplication.openSettingsURLString`）

### 5.2 AlarmConfiguration 組み立て

`AlarmConfigurationBuilder.build(from: Alarm)` で SwiftData ドメイン Alarm から `AlarmConfiguration<AlarmMetadataPayload>` を生成。

**3 モードの使い分け**:
| ドメイン `AlarmScheduleKind` | AlarmKit 構成 |
|---|---|
| `.oneShot(fireDate)` | `.schedule(.fixed(date))` |
| `.recurringWeekly` | `.schedule(.relative(time:weekdays:))` |
| `.countdown(seconds)` | `.countdownDuration(.init(preAlert: seconds, postAlert: 60))` |

**preAlert/postAlert**: countdown ダウン時に preAlert 秒が経過すると `.alerting` 状態、ユーザー操作なしで postAlert 秒さらに経過すると自動停止。OkiMission の運用では `postAlert: 60` 固定（1 分鳴り続けて自動停止＝AlarmKit のフェイルセーフ）、ミッション完了で明示停止が前提。

**Presentation**:
```
AlarmPresentation(
  alert: AlertConfiguration(
    title: alarm.label,
    stopButton: AlarmButton(
      text: "停止",
      textColor: .white,
      systemImageName: "stop.fill"
    ),
    secondaryButton: AlarmButton(
      text: "ミッション開始",
      textColor: .white,
      systemImageName: "play.fill"
    ),
    secondaryButtonBehavior: .custom  // App Intent ルート
  ),
  countdown: CountdownConfiguration(  // countdown mode 時のみ
    title: alarm.label,
    pauseButton: AlarmButton(text: "一時停止", ...)
  )
)
```

`secondaryButtonBehavior: .custom` で `StartMissionIntent` をバインド。Apple 提供の built-in intents（`PauseAlarmIntent`, `ResumeAlarmIntent`, `OpenAlarmAppIntent`）は countdown mode の pause/resume にのみ使用。

### 5.3 サウンド設定

```
AlertConfiguration.sound = .named("jp_morning_gentle_01.caf")
```

**制約**:
- ファイル: main bundle 直下 or `Library/Sounds/`（前者を採用）
- フォーマット: CAF (Core Audio Format)、Linear PCM 16-bit、44.1kHz、モノラル推奨
- 長さ: AlarmKit の明示制限は未公開だが、UNNotificationSound 経験則で **最大 30 秒** を採用。30 秒以下のループ可能なクリップを 20–30 本同梱
- 音量: `AlertConfiguration.sound` で個別音量設定は不可。デバイス着信音量に従う
- フェイクパス対策: `previewHash` を `AudioPack` に持たせ、起動時に Bundle 内ファイルのハッシュ照合（外部攻撃ではなくバンドル破損検知）

### 5.4 Metadata

```swift
struct AlarmMetadataPayload: AlarmMetadata {
  let alarmId: UUID
  let missionTemplateId: UUID?
  let missionKind: MissionKind?
}
```

`AlarmAttributes<AlarmMetadataPayload>` で Live Activity と紐付け。`AlarmMetadata` プロトコル準拠で `Codable + Sendable + Hashable` 必須。

### 5.5 ライフサイクル監視

```swift
for await update in AlarmManager.shared.alarmUpdates {
  // update: [Alarm<AlarmMetadataPayload>]
  // 全アラームの最新状態（.scheduled / .countdown / .paused / .alerting / .completed）
  await alarmEventBus.emit(.snapshot(update))
}
```

`AlarmEventBus` が `AsyncStream<AlarmEvent>` を発行し、UI と AnalyticsClient と AlarmRepository（domain `Alarm.isEnabled` 同期）が購読。

### 5.6 既知制約と対応

| 制約 | 対応 |
|---|---|
| アラーム発火で host app は自動起動しない | UI 上に「ミッション開始」ボタン必須。タップ時のみ起動 |
| `StopAlarmIntent` がスワイプ却下で発火しない（1.0） | 発火後 30 秒以内に `MissionRun` 行が作成されなかったら `.dismissedWithoutMission` イベント発行。ストリーク影響なし |
| Spotify / Apple Music 不可 | 影響なし（ElevenLabs prebake 同梱で完結） |
| 最大アラーム本数 | **公式記載なし** → 安全側で 64 本上限を Repository 層で課す。超過時は最古の `.completed` を削除 |
| Critical Alerts entitlement の必要性 | AlarmKit は entitlement 不要で alert を bypass する。Critical Alerts entitlement は別途申請不要 |
| Focus / DnD bypass | AlarmKit はデフォルトで bypass する。設定不要 |

### 5.7 エンタイトルメント `com.apple.developer.alarmkit`

**不確実性あり**（Apple Developer Forums で要否報告が分かれる）。
- 戦略: provisioning profile に追加せずビルド → Xcode が要求した場合は entitlement ファイルに追加 → Capabilities タブから有効化 → Apple Developer ポータルで App ID に追加
- 拒否時のフォールバック: UNNotificationCenter Critical Alert entitlement（要 Apple 申請、数日〜数週間）に縮退。**ship blocker** 判定し設計レポート §1 通り

---

## 6. App Intents 完全カタログ

### 6.1 全 Intent 一覧

| Intent | パラメータ | resolver | 戻り値 | 開示 |
|---|---|---|---|---|
| `StartMissionIntent` | `alarmId: String` | 自動（識別子） | `IntentResult & OpensIntent` → `NavigateToMissionIntent` | AlarmKit secondary |
| `SnoozeIntent` | `alarmId: String`, `durationSec: Int` | デフォルト 5 分 | `IntentResult` | AlarmKit secondary (条件付き) |
| `StopAlarmIntent` | `alarmId: String` | — | `IntentResult` | AlarmKit primary stop |
| `NavigateToMissionIntent` | `runId: String` | — | `IntentResult` + 内部 deep link | 非公開 |
| `QuickCreateAlarmIntent` | `time: DateComponents`, `label: String?`, `missionKind: MissionKind?` | DateComponentsResolver | `IntentResult & ReturnsValue<AlarmEntity>` | Shortcuts/Siri |
| `ToggleAlarmIntent` | `alarm: AlarmEntity`, `enabled: Bool` | EntityResolver | `IntentResult` | Shortcuts/Widget |
| `ListUpcomingAlarmsIntent` | — | — | `IntentResult & ReturnsValue<[AlarmEntity]>` | Siri |
| `GetStreakIntent` | — | — | `IntentResult & ReturnsValue<Int>` | Siri/Widget |

### 6.2 AlarmEntity

```swift
struct AlarmEntity: AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "アラーム")
  static var defaultQuery = AlarmEntityQuery()
  var id: UUID
  var displayRepresentation: DisplayRepresentation
  // label, time, isEnabled
}
```

`AlarmEntityQuery: EntityQuery & EntityStringQuery` で `suggestedEntities()` と `entities(matching:)` を実装。Spotlight 検索結果に最近のアラームを表示。

### 6.3 AppShortcuts

`AppShortcuts` provider で QuickCreate と GetStreak を Siri suggestions に登録。`AppShortcutPhrase("ストリーク確認", \.$action, ...)` で日本語 invocation phrase を 2–3 種ずつ登録。

### 6.4 Intent Donation

ユーザーがアラームを手動作成・ミッション完了するたびに `IntentDonationManager.shared.donate(...)` で donation。Siri の suggestion 品質向上。

---

## 7. Live Activity 深掘り

### 7.1 AlarmActivityAttributes

```swift
struct AlarmActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    enum Phase: Codable, Hashable {
      case countingDown(remaining: TimeInterval, total: TimeInterval)
      case firing(missionPending: Bool)
      case snoozed(until: Date)
      case missionInProgress(progress: Double)  // 0.0–1.0
      case completed
    }
    var phase: Phase
    var lastUpdated: Date
  }
  let alarmId: UUID
  let label: String
  let soundDisplayName: String
  let missionKind: MissionKind?
}
```

### 7.2 起動・更新・終了

| トリガ | アクション |
|---|---|
| `AlarmService.schedule(countdown)` 成功 | `Activity.request(...)` 開始、Push Token 取得 |
| `alarmUpdates` で `.countdown` 受信 | `Activity.update(...)` 毎分（前景時）／push update（背景時、必要なら） |
| `.alerting` 受信 | `phase = .firing(missionPending: alarm.hasMission)` |
| `SnoozeIntent` 実行後 | `phase = .snoozed(until:)` |
| ミッション開始 (`StartMissionIntent`) | host app 起動 → `phase = .missionInProgress(progress:)` を間隔更新 |
| ミッション成功 | `phase = .completed` → 3 秒後 `Activity.end(dismissalPolicy: .immediate)` |
| `stale-date` (10 分間更新なし) | system が自動で stale 表示 |

### 7.3 レンダラ実装方針

- **Lock Screen view**: 縦長、`OMGlassPanel` 内に時刻＋ミッション種別アイコン＋ストップボタン
- **Dynamic Island compact**: leading=アイコン、trailing=残り時間
- **Dynamic Island expanded**: 4 領域に分割、bottom=2 ボタン（ミッション開始／スヌーズ）
- **StandBy**: フルスクリーン時計＋大型アラームラベル
- **Apple Watch mirror**: SwiftUI view が自動で適応、追加実装不要

### 7.4 Push Update 戦略

**Phase 1**: ローカル更新のみ（push update なし）。countdown と即時遷移はローカルで完結する。
**Phase 2 検討**: マルチデバイス同期（iPhone でスヌーズ→Watch にも反映）が必要になったら `ActivityKit pushToken` を Supabase に送信し、Edge Function から APNs Live Activity push を投げる。

---

## 8. ミッションエンジン深掘り

### 8.1 Mission プロトコル

```swift
protocol Mission: Sendable {
  associatedtype Config: Codable & Sendable
  associatedtype Metrics: Codable & Sendable
  static var kind: MissionKind { get }
  static var requiredCapabilities: Set<MissionCapability> { get }
  static var minimumDeviceModel: DeviceCapabilityClass { get }
  
  func run(
    config: Config,
    context: MissionContext
  ) -> AsyncThrowingStream<MissionEvent<Metrics>, Error>
}

enum MissionCapability { case camera(.front | .rear), motion, microphone, barcode }
enum MissionEvent<M> {
  case stateChanged(MissionState)
  case progressUpdated(Double)
  case feedback(MissionFeedback)  // "もう少し！" 等の UI hint
  case suspicionDetected(MissionAntiCheatSignal)
  case completed(M)
  case failed(MissionFailureReason)
}
```

### 8.2 状態機械

```
[idle]
   └─→ checkPermission → [framing]
            ├─→ user cancel → [cancelled]
            └─→ framing ok → [running]
                     ├─→ pause (app background) → [paused]
                     │        └─→ resume → [running] or [aborted]
                     ├─→ success → [verifying] → [completed]
                     └─→ failure / timeout → [failed]
```

各遷移で:
- 関連 `MissionRun` 行を更新（`startedAt`, `completedAt`, `outcome`）
- `AlarmActivityAttributes.ContentState.phase` を更新
- PostHog にイベント送信
- Sentry breadcrumb 追加

### 8.3 アンチチート

5 種の検知シグナル、`MissionAntiCheat.evaluate(...)` で集計、複数該当時 `outcome = .cheated`：

| シグナル | 検知方法 | 重み |
|---|---|---|
| App backgrounded mid-mission | `scenePhase` 監視 | +2 |
| System clock tampered | `ProcessInfo.systemUptime` の単調増加検証 | +5 |
| Screenshot taken | `UIScreen.didCaptureNotification` | +1 |
| Excessive pause toggling | `UIApplication.didEnterBackgroundNotification` 回数 | +2 |
| Frame stream gap | カメラフレーム間隔が想定範囲外（>1s 連続） | +3 |

合計スコア >= 5 で `cheated`。`appBackgroundedDuringMission` / `clockTamperedDuringMission` を MissionRun に保存。

### 8.4 Kill 復旧

`MissionRestoration`:
1. ミッション開始時に `UserDefaults` に `restorationToken: { runId, startedAt, alarmId, kind }` を書く
2. mission 完了/cancel 時にクリア
3. 次回起動時に token が残っていたら：起動から 5 分以内 → 自動再開ダイアログ。5 分超 → `outcome = .abandoned` で run を close

### 8.5 個別ミッション実装

#### ObjectHunt

- フレーム: 背面カメラ 1920×1080, 10fps
- パイプライン: `VNImageRequestHandler` → 自前 `JapaneseObjectsModel.mlmodelc` (`VNCoreMLRequest`)
- 検出: target object list（例 `["remote_control", "cup", "toothbrush"]`）が全て信頼度 ≥0.6 で各 1 フレーム以上検出 → success
- UI: 検出済みオブジェクトをチェック付きカードでリスト表示、未検出は半透明
- 制限時間: 90s デフォルト、超過で failed

#### Pushup（深掘り §9 参照）

#### Squat

- Pose: 同上 BodyPose
- 角度: 膝関節（hip-knee-ankle）
- 閾値: down ≤100°, up ≥170°
- 補助: 腰 Y 座標のデルタが画面高の 15% 以上
- ヒステリシス: down→up→down で 1rep

#### Math

- 問題タイプ: 加減乗除 4 種
- 難易度別:
  - easy: 1 桁加減算、5 問、誤答 1 まで
  - medium: 2 桁加減算＋1 桁乗算、5 問、誤答 1 まで
  - hard: 2 桁四則、7 問、誤答 0
- 出題: `MathProblemGenerator` で seed 固定（同一日同一 difficulty で再現可、テスト容易）
- 制限時間: easy 60s, medium 90s, hard 120s

#### Shake

- センサ: `CMMotionManager.accelerometerUpdates`、100Hz
- 計測: 累積 |acceleration - gravity| を 10 秒間積算、閾値 50 m/s 超で success
- フィードバック: progress ring で振り強度を可視化

#### Barcode

- `VNDetectBarcodesRequest`、symbologies = [.qr, .ean13, .code128]
- 登録: ユーザーが事前に「歯ブラシ」「冷蔵庫の中身」等の barcode を Settings で登録
- 検出: 登録済 barcode と一致 → success

### 8.6 フォールバックチェーン

カメラ拒否 / モーション無効 / 低光不可など、能力欠落時：

```
ObjectHunt(camera) → camera 拒否 → Math
Pushup(camera+pose) → camera 拒否 → Shake → motion 無効 → Math
Squat(camera+pose) → 同上
Barcode(camera) → 同上
Shake(motion) → motion 無効 → Math
Math() → 常時利用可（最終）
```

`MissionRouter.resolve(template: MissionTemplate, capabilities: DeviceCapabilities)` で実行時決定。

---

## 9. Body Pose 数学詳細

### 9.1 関節の使い方

`VNDetectHumanBodyPoseRequest` の 19 関節のうち、Pushup/Squat で使うのは：
- Pushup: `.leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist`
- Squat: `.leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle`

### 9.2 角度計算

3 点 A, B, C の角度 θ at B = `acos( (BA · BC) / (|BA| · |BC|) )`、ラジアン → 度。

腕立て肘角度: `angle(shoulder, elbow, wrist)`、左右両方を計算し平均を採用。
スクワット膝角度: `angle(hip, knee, ankle)`、同様に平均。

### 9.3 信頼度フィルタ

各関節 `VNRecognizedPoint.confidence` を取得。閾値:
- `.high` >= 0.7: 採用
- `.medium` 0.4–0.7: 採用するが weight 0.5
- `.low` < 0.4: そのフレームは破棄

両肩 OR 両肘の confidence が low なら **フレーム破棄**。連続 30 フレーム破棄（=1 秒）で UI に「カメラに体を映してください」hint。

### 9.4 平滑化

EMA（指数移動平均）: `smoothedAngle[t] = α * raw[t] + (1-α) * smoothedAngle[t-1]`、α = 0.4。カルマンフィルタは過剰、EMA で十分。

### 9.5 Rep カウント（ヒステリシス）

```
state: .up | .down | .transitioning
   .up + angle <= downThreshold (90° for elbow) → .down
   .down + angle >= upThreshold (160° for elbow) → .up && repCount += 1
```

ヒステリシス幅 = `upThreshold - downThreshold = 70°`、これにより微振動でのカウント増加を防ぐ。

### 9.6 不正対策

- min rep duration: 0.8 秒未満の rep は破棄（座ったまま腕だけ動かす不正）
- rep の rhythm 監視: rep 間隔の標準偏差が小さすぎる（< 0.05s）= 機械的 → flag
- 関節の y 移動: pushup で体全体が動いていない（shoulder y delta < 5px）= flag

### 9.7 関節欠落・オクルージョン

片側の関節が `.low` confidence で取れない場合、もう片側のみで判定（weight 1.0）。両側欠落で 1 秒持続 → mission UI に framing hint。

---

## 10. 物体検出モデルパイプライン

### 10.1 クラス taxonomy

**Phase 1（launch 時）**: 30 クラス
- 日本家屋固有: 畳、布団、こたつ、座布団、湯呑、急須、箸、茶碗、味噌汁碗、しゃもじ、まな板、菜箸、お盆、すだれ、座椅子、行灯、暖簾、襖、障子、和室テーブル
- 洗面所: 歯ブラシ、歯磨き粉、コップ、タオル
- リビング: リモコン、雑誌、ティッシュ箱
- キッチン: 醤油ボトル、コーヒーカップ、お茶ボトル

各クラスは MECE（exhaustive ではない、識別容易性優先）。

### 10.2 訓練データ収集

- **クラウドソース**: ランサーズ／クラウドワークスで「日本家屋オブジェクト撮影」案件、1 クラスあたり 300–500 枚目標
- **アノテーション**: RectLabel Pro（Mac、買い切り 約 4,500 円）でローカル作業、もしくは Roboflow Free（1 月 1,000 枚まで）
- **総枚数**: 30 × 400 = 12,000 枚目標、最低 8,000 枚
- **照度バリエーション**: 朝・昼・夜・薄暗の 4 条件均等
- **アングル**: 真上・斜め 45°・水平の 3 アングル
- **train/val/test 分割**: 70/15/15、被写体（部屋）単位で分割（同じ部屋の画像が train と test に混在しないように）

### 10.3 augmentation

CreateML の組込 augmentation:
- horizontal flip
- random crop (10–20%)
- brightness ±20%
- saturation ±10%
- noise injection (Gaussian σ=0.01)

過剰 aug は精度劣化するので上記まで。

### 10.4 モデル設計

- CreateML Object Detector の `transfer learning`（YOLOv2 backbone、Apple 提供）
- input: 416×416
- output: 30 クラス + bbox
- 期待モデルサイズ: 15–25 MB（`.mlmodel` → `.mlmodelc` 圧縮後）

### 10.5 精度目標

- 検証 mAP@0.5: **目標 0.65 以上**、ローンチブロッカー **0.55 未満**
- 1 クラスあたり AP 0.5 未満のクラスは Phase 1 から外す（精度未達クラスは出題リストに含めない）

### 10.6 モデルバージョニング

- ファイル名: `JapaneseObjects_v1.0.mlmodelc`
- `ModelLoader` が version を `Info.plist` の `OMModelVersion` キーから読む
- A/B test: Phase 2 で複数モデルバンドル＋PostHog で feature flag

### 10.7 On-Device 推論

`compute units = .all`（Neural Engine 優先）。実機 iPhone 11 でのレイテンシ目標 **<50ms per frame** at 10fps。超えたら入力サイズを 320×320 に下げる。

---

## 11. Vision / Core ML パイプライン詳細

### 11.1 キャプチャ→推論→UI の queue 階層

```
[Capture queue: serial, .userInteractive]
   ↓ CMSampleBuffer
[FrameBroker actor: throttling]
   ↓ AsyncStream<CVPixelBuffer>
[VisionPipeline: VNImageRequestHandler 構築]
   ↓ Vision request 完了 (Vision 内部スレッド)
[VisionPipeline actor: 結果集約]
   ↓ AsyncStream<VisionEvent>
[@MainActor ViewModel: UI 反映]
```

### 11.2 Throttling

検出: 10fps（100ms 間隔）
Pose: 30fps（33ms 間隔）

throttling は drop policy（古いフレームを捨てる、queue しない）。`AsyncStream` の bufferingPolicy = `.bufferingNewest(1)`.

### 11.3 並行リクエスト制限

1 ミッション 1 リクエスト種別のみ。`RequestQueue` actor が重なりを禁止。VisionPipeline は前リクエスト完了まで次フレームを破棄。

### 11.4 メモリ圧

- 1920×1080 RGBA フレーム ≒ 8MB
- バッファ 1 個のみ保持（drop policy）
- モデル: 20MB 級、メモリ常駐 60 秒
- 合計 ~30MB peak

### 11.5 ホットキャッシュ

`ModelLoader` (actor):
```
load(.japaneseObjects) → 既にロード済 → 即返
                       → 未ロード → MLModel.load(...) async → 60s タイマーで unload
```

mission 連続実行で reload コスト（500–1500ms）を回避。

---

## 12. カメラ / オーディオセッション

### 12.1 AVCaptureSession 設定

```swift
session.sessionPreset = .hd1920x1080
input: AVCaptureDeviceInput(device: .builtInWideAngleCamera, position: .front/.back)
output: AVCaptureVideoDataOutput(
  videoSettings: [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
)
output.alwaysDiscardsLateVideoFrames = true
```

オリエンテーション: `AVCaptureConnection.videoRotationAngle` を device orientation に従って更新。

### 12.2 AVAudioSession

ミッション中はアラーム音と TTS hint（将来）を重ねるため `AVAudioSession.Category.playback`, `.mixWithOthers` で他アプリの音楽を継続。

アラーム発火時の音は AlarmKit が自前 audio session 管理するので、host app 側で session 設定する必要なし。**ミッション開始＝host app 起動以降に audio session を `.playback` で activate**。

### 12.3 CallKit / 中断

着信中: `AVAudioSession.interruptionNotification` 監視。中断発生でミッション一時停止（state = .paused）、`AVAudioSessionInterruptionType.ended` で再開可否を UI 提示。

### 12.4 サイレントスイッチ / ボリューム

AlarmKit はサイレントスイッチを bypass（仕様）。ミッション中の TTS は `.playback` カテゴリなのでサイレント時も鳴る。Settings で「ミッション中のサウンド」トグルを提供。

---

## 13. 背景ライフサイクル

### 13.1 起動シーケンス（Bootstrap.swift、順序厳守）

```
1. SentryBootstrap.start()           // 必ず最初。早期クラッシュ捕捉
2. StoreKitListener.startListening() // Transaction.updates を即座に購読開始
                                     // Apple 要件: UI 描画前
3. ModelContainer 作成
4. Logger 設定
5. AlarmAuthorizationStore 初期化
6. AlarmService.shared (alarmUpdates 購読開始)
7. RevenueCatService.configure(apiKey:)
8. SupabaseAuthService.configure()
9. PostHogClient.start()
10. APNsRegistrar.register()         // 通知許可済の場合
11. SwiftUI App body 開始
```

### 13.2 BGTask 登録

`Info.plist > BGTaskSchedulerPermittedIdentifiers`:
- `com.example.okimission.ai-prefetch` (BGAppRefreshTask) - 翌日分 AI ミッション prefetch
- `com.example.okimission.analytics-flush` (BGProcessingTask) - PostHog outbox flush

`BGTaskScheduler.register(forTaskWithIdentifier:)` を `Bootstrap.swift` で実施。`submit` は ai-prefetch を毎晩スケジュール（earliest = next 0:00 - 3:00）。

### 13.3 Silent Push Fallback

BGAppRefresh ヒット率が低い（Apple は保証しない、実測 40–70% 程度）ため、Phase 2 で silent push（`content-available: 1`）に切替検討。

### 13.4 アラームライフサイクルと app 状態

```
alarm.fire(背景時) → AlarmKit が alert UI 表示（app 起動なし）
                  → ユーザー Stop タップ → app 起動なし、alarm 完了
                  → ユーザー Start Mission タップ → app 起動、deep link で MissionRouter へ
                  → ユーザー スワイプ却下 → app 起動なし、stop intent 発火保証なし
alarm.fire(前景時) → host app 表示中なら AlarmKit alert がフルスクリーンで覆う？
                  → 実機検証必要、要 §28 #X
```

---

## 14. Supabase バックエンド詳細

### 14.1 Postgres スキーマ（DDL）

```sql
-- 拡張
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- プロフィール
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  apple_user_identifier text unique not null,
  display_name text,
  preferred_locale text not null default 'ja-JP',
  subscription_tier text not null default 'free',  -- 'free' | 'pro' | 'pro_annual'
  subscription_expires_at timestamptz,
  streak_count int not null default 0,
  longest_streak int not null default 0,
  current_streak_start_date date,
  last_success_date date,
  apns_token text,
  apns_env text default 'production',  -- 'production' | 'sandbox'
  notifications_authorized boolean default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_subscription_tier_idx on public.profiles(subscription_tier) where deleted_at is null;
create index profiles_apns_token_idx on public.profiles(apns_token) where apns_token is not null;

-- アラーム履歴ミラー（端末側 SwiftData が正、サーバは分析用）
create table public.alarm_runs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  alarm_id uuid not null,                  -- 端末側 SwiftData の UUID
  mission_template_id uuid,
  mission_kind text,
  outcome text not null,                   -- 'success' | 'failed' | 'abandoned' | 'skipped' | 'cheated'
  started_at timestamptz not null,
  completed_at timestamptz,
  metrics jsonb,
  snooze_count_before int default 0,
  device_model text,
  app_version text,
  os_version text,
  created_at timestamptz not null default now()
);

create index alarm_runs_user_id_started_at_idx on public.alarm_runs(user_id, started_at desc);
create index alarm_runs_outcome_idx on public.alarm_runs(outcome);

-- AI ミッション生成キャッシュ
create table public.mission_generations (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target_date date not null,
  difficulty_hint text not null,
  template jsonb not null,
  generated_at timestamptz not null default now(),
  consumed_at timestamptz,
  unique(user_id, target_date, difficulty_hint)
);

-- レート制限
create table public.rate_limits (
  user_id uuid not null references public.profiles(id) on delete cascade,
  bucket text not null,           -- 'mission_generate'
  window_start timestamptz not null,
  count int not null default 0,
  primary key (user_id, bucket, window_start)
);

-- RevenueCat webhook イベントログ
create table public.billing_events (
  id uuid primary key default uuid_generate_v4(),
  rc_event_id text unique,
  rc_app_user_id text not null,
  event_type text not null,
  product_id text,
  raw_payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_error text
);

create index billing_events_rc_app_user_id_idx on public.billing_events(rc_app_user_id, received_at desc);
```

### 14.2 RLS ポリシー

```sql
alter table public.profiles enable row level security;
alter table public.alarm_runs enable row level security;
alter table public.mission_generations enable row level security;
alter table public.rate_limits enable row level security;
alter table public.billing_events enable row level security;  -- 読み書き全禁止（service_role のみ）

-- profiles: 自分の行のみ
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
-- INSERT は trigger で auto、DELETE はクライアントから不可（Edge Function 経由のみ）

-- alarm_runs: 自分の user_id の行のみ
create policy "alarm_runs_all_own" on public.alarm_runs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- mission_generations: read のみ自分の行
create policy "mission_generations_select_own" on public.mission_generations
  for select using (auth.uid() = user_id);
-- INSERT は Edge Function service_role でのみ

-- rate_limits: クライアント直接アクセス不可
-- billing_events: service_role のみ
```

### 14.3 トリガ

```sql
-- auth.users 新規作成 → profiles 行作成
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, apple_user_identifier, preferred_locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'apple_user_identifier', new.id::text),
    coalesce(new.raw_user_meta_data->>'preferred_locale', 'ja-JP')
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- updated_at 自動更新
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
```

### 14.4 Edge Functions（Deno）

ディレクトリ構成（リポジトリ別ディレクトリ `/supabase/functions/`、本リポジトリと分離管理が安全だが、簡略のため同居も可）：

```
supabase/
  functions/
    missions-generate/
      index.ts          // POST handler
      gemini.ts         // Gemini API call
      prompt.ts         // JA prompt template
      ratelimit.ts
    missions-feedback/
      index.ts
    audio-manifest/
      index.ts
    push-register/
      index.ts
    billing-webhook/
      index.ts          // RevenueCat webhook
      verify.ts         // HMAC signature verify
    push-send/
      index.ts          // 内部 RPC、Postgres trigger からも呼べる
    account-delete/
      index.ts          // SiwA 安全削除フロー
  config.toml
  migrations/
    20260601000000_initial_schema.sql
    ...
```

### 14.5 Secret 管理

- Supabase Dashboard > Edge Functions > Secrets:
  - `GEMINI_API_KEY`
  - `REVENUECAT_WEBHOOK_SECRET`
  - `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_P8`（P8 鍵全文、Base64 encoded）
  - `APP_BUNDLE_ID`
- ローカル開発: `.env.local`、gitignore、`supabase secrets set` で deploy

### 14.6 マイグレーション運用

- `supabase migration new <name>` で SQL ファイル生成
- 命名: `YYYYMMDDHHMMSS_purpose.sql`
- 適用: dev は `supabase db reset --local`、本番は CI 経由 `supabase db push`
- ロールバック用 SQL は別ファイルで `down/` ディレクトリに用意（運用のみ）

### 14.7 バックアップ

- Supabase Pro は自動 PITR（point-in-time recovery）7 日間
- 月次論理バックアップ: `pg_dump` を GitHub Actions で実行し S3 互換ストレージ（Cloudflare R2 free）に保存

---

## 15. Edge Function エンドポイント仕様

### 15.1 POST /missions/generate

**Auth**: Supabase JWT（Bearer）必須

**Request**:
```json
{
  "targetDate": "2026-06-01",
  "difficultyHint": "medium",
  "history": ["pushup", "math", "shake"],
  "localeOverride": "ja-JP"
}
```

**Validation**:
- targetDate: ISO date、今日〜+3 日以内
- difficultyHint: enum
- history: 最大 10 要素
- ユーザーは認証済（JWT 検証）

**Rate limit**: 5/日/ユーザー、window=24h
- 実装: rate_limits テーブルに upsert、count++、超過で 429

**Cache check**: `mission_generations.unique(user_id, target_date, difficulty_hint)` 存在 → 返却

**Gemini call**: 標準プロンプト + history + localeで日本語ミッションテンプレ JSON 生成、temperature=0.7, max_output_tokens=512

**Persist**: mission_generations へ insert

**Response**:
```json
{ "template": {...MissionTemplate JSON...}, "ttlSec": 86400, "cached": false }
```

### 15.2 POST /missions/feedback

**Auth**: Supabase JWT

**Request**: `{ runId, outcome, durationSec, metrics }`

**Action**: alarm_runs へ upsert、`mission_generations.consumed_at` をマーク

**Response**: `{ ok: true }`

### 15.3 GET /audio/manifest

**Auth**: 不要（公開）

**Response**: 同梱音声カタログ JSON（クライアントは Bundle 内データを基本利用、これは将来の拡張用）

### 15.4 POST /push/register

**Auth**: Supabase JWT

**Request**: `{ apnsToken, env }`

**Action**: `profiles.apns_token`, `apns_env` を更新

### 15.5 POST /billing/webhook

**Auth**: HMAC-SHA256 署名検証（`X-RevenueCat-Authorization` ヘッダ）

**Action**:
1. 署名検証失敗 → 401
2. `billing_events` に raw_payload 保存（冪等性のため event_id unique）
3. event_type で分岐: `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION`, `BILLING_ISSUE`
4. `profiles.subscription_tier` / `subscription_expires_at` を更新
5. processed_at をマーク

### 15.6 POST /account/delete

**Auth**: Supabase JWT

**Action**（順序重要）:
1. `profiles.deleted_at = now()` でソフト削除マーク
2. 関連 alarm_runs / mission_generations は **30 日保持** 後に物理削除（GDPR/APPI 配慮）
3. Apple SiwA refresh token を revoke API で取消（`https://appleid.apple.com/auth/revoke`）
4. Supabase `auth.users` レコード削除（cascade で profiles も最終的に物理削除）
5. クライアントには 204

---

## 16. RevenueCat / StoreKit 詳細

### 16.1 製品設計

**Product IDs（App Store Connect）**:
- `com.example.okimission.pro.monthly` — Auto-Renewable Subscription、月額 ¥600
- `com.example.okimission.pro.yearly` — Auto-Renewable Subscription、年額 ¥4,800（20% 割引）
- （Phase 2）`com.example.okimission.pro.lifetime` — Non-Consumable、買い切り ¥12,800

Subscription Group: `pro_group`（monthly と yearly を 1 グループに）

**Introductory Offer**:
- Free Trial 3 days、新規ユーザー対象（Wayk と同水準）
- 同一 subscription group 内で 1 度のみ使用可（Apple ルール）

### 16.2 RevenueCat 設定

**Entitlements**:
- `pro` — Pro 機能フルアクセス

**Offerings**:
- `default` — メインオファリング
  - Package `monthly` → `com.example.okimission.pro.monthly`
  - Package `annual` → `com.example.okimission.pro.yearly`
- `holiday_2026` — シーズナル A/B test 用（同 product を含む別 layout）

**Paywall A/B**:
- v1: Annual 強調、Monthly はサブ
- v2: Trial 強調、Annual default
- v3: Streak 訴求型（「7 日続けたい？」）
- v4: Mission 訴求型（「AI 起こしを試そう」）

各 Paywall は RevenueCat Paywalls v2 テンプレを使うが、**特商法シートは RC ではなく完全自前 SwiftUI**。RC paywall 上の購入ボタンタップ → 自前 TokushohoSheet を modal 提示 → 「確認して購入」タップで `Purchases.shared.purchase(package:)` を実行。

### 16.3 EntitlementStore

```swift
@Observable @MainActor
final class EntitlementStore {
  enum Tier: Equatable { case free, pro(expiresAt: Date?) }
  private(set) var tier: Tier = .free
  private(set) var customerInfo: CustomerInfo?
  
  func bootstrap() async {
    let info = try? await Purchases.shared.customerInfo()
    update(from: info)
    for await info in Purchases.shared.customerInfoStream {
      update(from: info)
    }
  }
}
```

`@Entitled(.pro)` プロパティラッパで `@Environment(EntitlementStore.self).tier == .pro(...)` を返す。

### 16.4 Restore

Settings に「購入の復元」ボタン → `Purchases.shared.restorePurchases()` → 結果を toast。

### 16.5 サーバ側 receipt 検証

Apple App Store Server Notifications V2 と RevenueCat webhook の両方を受ける（多層防御）。
- RC webhook: §15.5
- Apple ASSN: 別 Edge Function `/billing/apple-notifications`（Phase 2、まずは RC のみで OK）

### 16.6 Family Sharing

App Store Connect で **Family Sharing を有効化**。コード側で `Purchases.shared.familyShareableProducts` をチェックしてエンタイトルメント反映。

### 16.7 Transaction Listener

```swift
final class StoreKitListener {
  func startListening() {
    Task.detached(priority: .background) {
      for await result in Transaction.updates {
        // RC が処理するが、明示的に Transaction.finish() しないと多重通知
        await self.handle(result)
      }
    }
  }
}
```

`Bootstrap.swift` で UI 描画前に起動（Apple Human Interface 要件）。

### 16.8 Promotional Offers

- Free Trial 失効後の win-back: `pay_as_you_go` $0.99/月 × 3 ヶ月（Phase 2）
- Code Redemption: ベータテスター向け 1 ヶ月無料（App Store Connect で生成）

---

## 17. 特商法 field-level 完全仕様

### 17.1 必須表記項目（OkiMission 個別の値）

| 項目 | 例 | 備考 |
|---|---|---|
| 販売事業者名 | 〇〇 〇〇（個人事業主の場合は本名） | 法人化後は法人名 |
| 運営責任者 | 〇〇 〇〇 | 個人なら同上 |
| 所在地 | 〒XXX-XXXX 東京都〇〇区〇〇 X-X-X | バーチャルオフィス可。「**省略可能** 請求あれば遅滞なく開示」表記は条件付き可（消費者庁 2022 解釈） |
| 電話番号 | 03-XXXX-XXXX | 同上、開示準備義務あり |
| メールアドレス | help@oki-mission.app | 必須 |
| URL | https://oki-mission.app | |
| 商品代金 | OkiMission Pro 月額 ¥600 / 年額 ¥4,800（税込） | 全税込明示 |
| 商品代金以外の必要料金 | なし（インターネット通信料はお客様負担） | |
| 引渡時期 | お支払い手続き完了後、即時利用可能 | |
| 支払方法 | App Store 経由のクレジットカード／キャリア決済／Apple ID 残高 | |
| 返品・キャンセル | デジタル商品の性質上、ご購入後の返金はお受けできません。サブスクリプションの解約は App Store のサブスクリプション管理画面からいつでも行えます。 | App Store の標準キャンセルポリシ参照 |
| 動作環境 | iOS 26.0 以降、iPhone 11 以降 | |
| **サブスク自動更新特約**（2022 改正必須） | 各回の分量・各回の金額・各回の支払時期・解約方法を明示 | §17.2 |

### 17.2 サブスク自動更新表記（精密版）

特商法 12 条の 6 / 11 条 5 号関連、消費者庁 2022 年改正に基づく必須項目：

```
【自動更新サブスクリプションについて】

■ 各回の分量
  OkiMission Pro の全機能をご利用いただけます（期間中無制限）

■ 各回の金額
  月額プラン：600 円（税込）
  年額プラン：4,800 円（税込）

■ 各回の支払時期
  月額プラン：契約日から起算して 1 ヶ月ごとに自動更新
  年額プラン：契約日から起算して 12 ヶ月ごとに自動更新

■ 解約方法
  iPhone の「設定」アプリ → ご自身の Apple ID（最上部）→「サブスクリプション」
  → OkiMission Pro → 「サブスクリプションをキャンセル」
  でいつでも解約できます。次回更新日の 24 時間以上前に解約手続きを完了してください。
```

### 17.3 表示場所（3 箇所必須）

1. **公式 LP**: `/legal/tokushoho` ページ（KIYAC 生成）
2. **アプリ内 Settings > 特定商取引法に基づく表記**: SwiftUI ネイティブ画面
3. **購入直前の TokushohoSheet**: paywall → purchase 前の modal で再表示、最終確認ボタンの直上に必須表示

### 17.4 TokushohoSheet UI 仕様

```
[Sheet]
  ┌─────────────────────────────┐
  │ ご購入内容のご確認            │
  │                              │
  │ ・プラン: 年額プラン           │
  │ ・金額:   4,800 円（税込）     │
  │ ・期間:   12 ヶ月、以後自動更新│
  │ ・次回更新: 2027 年 6 月 1 日  │
  │                              │
  │ [▼ 特定商取引法に基づく表記]  │
  │   (展開すると §17.2 全文)     │
  │                              │
  │ [▼ 利用規約]                  │
  │ [▼ プライバシーポリシー]      │
  │                              │
  │ □ 上記内容に同意する          │
  │                              │
  │  [確認して購入]               │
  │  [キャンセル]                 │
  └─────────────────────────────┘
```

`□ 上記内容に同意する` のチェックなしで「確認して購入」は無効。

---

## 18. Privacy Manifest 詳細

### 18.1 PrivacyInfo.xcprivacy

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>  <!-- IDFA 不使用 -->
  
  <key>NSPrivacyTrackingDomains</key>
  <array/>  <!-- 同上 -->
  
  <key>NSPrivacyCollectedDataTypes</key>
  <array>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeEmailAddress</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeUserID</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
        <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypePerformanceData</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeCrashData</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeProductInteraction</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypePurchaseHistory</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
  </array>
  
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <!-- UserDefaults -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>  <!-- access info available only to this app -->
      </array>
    </dict>
    <!-- File timestamp -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>C617.1</string>  <!-- inspect/access files within own app container -->
      </array>
    </dict>
    <!-- System boot time -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>35F9.1</string>  <!-- measure time elapsed between events (anti-cheat clock check) -->
      </array>
    </dict>
    <!-- Disk space -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>E174.1</string>  <!-- write or delete file -->
      </array>
    </dict>
  </array>
</dict>
</plist>
```

### 18.2 サードパーティ SDK 検証

| SDK | Privacy Manifest 同梱 | 確認 |
|---|---|---|
| RevenueCat (purchases-ios) 5.x | ◯ | バンドル時に自動マージ |
| Supabase-Swift 2.x | ◯（最新版）| 要 release notes 確認 |
| Sentry-Cocoa 8.x | ◯ | 同上 |
| PostHog-iOS 3.x | ◯ | 同上 |

ビルド時に Xcode が「missing privacy manifest」warning を出す場合は SDK version を最新へ。

### 18.3 App Store Connect の Nutrition Labels

App Store Connect > Privacy で以下を申告：
- Data Used to Track You: なし
- Data Linked to You: User ID, Email, Purchase History, Product Interaction
- Data Not Linked to You: Crash Data, Performance Data

---

## 19. 認証＆アカウント削除フロー

### 19.1 Sign in with Apple 詳細

1. `ASAuthorizationAppleIDProvider` で request 生成、`requestedScopes = [.fullName, .email]`
2. `NonceGenerator` で `SHA256(randomString(32))` を `request.nonce` にセット、原文を保持
3. `ASAuthorizationController` 提示
4. 成功 → `appleIDCredential.identityToken` (JWT) + `authorizationCode` 取得
5. Supabase `auth.signInWithIdToken(provider: .apple, idToken:, nonce:)`
6. Supabase が JWT 検証＋user 作成、`auth.users` 行できる
7. trigger `handle_new_user()` で `profiles` 行作成（§14.3）
8. Keychain に `appleUserIdentifier` を保存（次回起動の自動ログイン）

### 19.2 トークンリフレッシュ

Supabase SDK が `auth.session` を自動リフレッシュ。失敗時は再ログインフロー。
Apple `authorizationCode` から refresh token を取得しサーバ保存しても良いが、Phase 1 は不要。Phase 2 で account-delete 時の Apple revoke 用に取得。

### 19.3 アカウント削除フロー（App Store Guideline 5.1.1(v) 必須）

1. Settings > アカウント削除 → 警告ダイアログ「全データが削除されます」
2. テキスト確認入力（"DELETE" タイプ）
3. `/account/delete` Edge Function 呼出（§15.6）
4. クライアント側: Keychain クリア、SwiftData ストア破棄、`Purchases.shared.logOut()`
5. ルート画面へ戻りオンボーディング再開

**Apple Token Revoke**（必須、Guideline 5.1.1(v)）:
- サーバ側で `client_secret` を JWT 生成（ES256, Apple Developer 設定の Key で署名）
- POST `https://appleid.apple.com/auth/revoke` with `client_id`, `client_secret`, `token`, `token_type_hint`
- 失敗してもログのみ、ユーザー削除は続行

---

## 20. Push 通知設計

### 20.1 用途

OkiMission の push 用途は **少ない**:
- Streak 喪失警告（前日の successful day がなかった日の 20:00）
- 朝のミッションプリフェッチ trigger（silent push、Phase 2）
- メジャーアップデート告知（手動）

アラーム発火は AlarmKit 自身が処理、push 不要。

### 20.2 Categories / Actions

```
OMNotificationCategory.streakReminder
  actions: [.viewApp]
OMNotificationCategory.silentPrefetch (content-available)
```

### 20.3 Critical Alerts

不要。AlarmKit が bypass する仕様なので追加 entitlement なしで良い。

### 20.4 APNs 鍵

- p8 Key を Apple Developer Portal で作成
- Supabase Secrets に `APNS_KEY_P8` (Base64) 保存
- Edge Function `/push/send` で `jose` (Deno) を使い JWT 生成、APNs に POST

### 20.5 Time-Sensitive Notifications

ストリーク警告は `interruptionLevel = .timeSensitive` で送信、Focus mode bypass。

---

## 21. アナリティクス taxonomy 完全版

### 21.1 イベント一覧

| イベント名 | プロパティ |
|---|---|
| `app.launch` | `cold_start: Bool`, `from_widget: Bool` |
| `app.foreground` | — |
| `app.background` | `session_duration_sec: Int` |
| `onboarding.step_view` | `step: String` |
| `onboarding.permission_granted` | `permission: String` |
| `onboarding.permission_denied` | `permission: String` |
| `onboarding.completed` | `duration_sec: Int` |
| `auth.sign_in_started` | — |
| `auth.sign_in_succeeded` | `is_new_user: Bool` |
| `auth.sign_in_failed` | `error_code: String` |
| `auth.sign_out` | — |
| `auth.account_deleted` | — |
| `alarm.created` | `schedule_kind: String`, `has_mission: Bool`, `mission_kind: String?` |
| `alarm.edited` | `alarm_id: String`, `changed_fields: [String]` |
| `alarm.deleted` | `alarm_id: String` |
| `alarm.fired` | `alarm_id: String`, `was_app_in_foreground: Bool` |
| `alarm.snoozed` | `alarm_id: String`, `snooze_count: Int`, `snooze_duration_sec: Int` |
| `alarm.dismissed_without_mission` | `alarm_id: String`, `had_mission: Bool` |
| `mission.started` | `kind: String`, `difficulty: String`, `ai_generated: Bool` |
| `mission.progress` | `kind: String`, `progress: Double` （サンプル 10%） |
| `mission.completed` | `kind: String`, `duration_sec: Int`, `metrics_summary: JSON` |
| `mission.failed` | `kind: String`, `reason: String`, `duration_sec: Int` |
| `mission.fallback_used` | `original_kind: String`, `fallback_kind: String`, `reason: String` |
| `mission.cheat_detected` | `kind: String`, `signals: [String]` |
| `paywall.viewed` | `variant: String`, `trigger: String` |
| `paywall.purchase_started` | `variant: String`, `product_id: String` |
| `paywall.tokushoho_viewed` | `variant: String`, `product_id: String` |
| `paywall.tokushoho_confirmed` | `variant: String`, `product_id: String` |
| `paywall.purchase_succeeded` | `variant: String`, `product_id: String`, `period: String` |
| `paywall.purchase_failed` | `variant: String`, `error_code: String` |
| `paywall.restore_attempted` | `success: Bool` |
| `share.image_exported` | `share_target: String` |
| `subscription.entitlement_changed` | `from: String`, `to: String`, `reason: String` |
| `streak.broken` | `previous_count: Int` |
| `streak.milestone` | `count: Int` |
| `app.crash` | `is_fatal: Bool` （Sentry と二重送信ではなく集計用） |
| `notification.received` | `category: String` |
| `notification.tapped` | `category: String` |
| `settings.changed` | `setting: String`, `value: String` |
| `audio.previewed` | `sound_id: String` |
| `legal.tokushoho_viewed_in_app` | — |

### 21.2 ユーザープロパティ

`locale`, `tier`, `streak_bucket` ('0', '1-6', '7-29', '30+'), `device_model`, `os_version`, `app_version`, `first_seen_at`, `country_code` (locale 由来).

### 21.3 PII 取扱

- Supabase user id は `SHA256(supabaseUserId + salt)` で PostHog distinct ID として使用
- email は PostHog に送信しない
- IP は PostHog 設定で disable

### 21.4 サンプリング

`mission.progress` は 10% サンプル、それ以外は 100%。

### 21.5 オフライン flush

ネットワーク断時 `AnalyticsOutbox` に書込、`Reachability` 復活で flush。最大保持 1,000 件、超過時 FIFO 削除。

---

## 22. Sentry 詳細

### 22.1 初期化

```swift
SentrySDK.start { options in
  options.dsn = AppConfig.sentryDsn
  options.environment = AppConfig.environment.rawValue
  options.releaseName = "okimission@\(Bundle.appVersion)+\(Bundle.buildNumber)"
  options.dist = Bundle.buildNumber
  options.tracesSampleRate = 0.2  // 20% performance trace
  options.profilesSampleRate = 0.1  // 10% profiling (iOS only)
  options.attachScreenshot = true
  options.attachViewHierarchy = true
  options.enableUserInteractionTracing = true
  options.beforeSend = { event in
    // ユーザー識別子は user.id にハッシュ済 Supabase ID のみ、email は除去
    event.user?.email = nil
    return event
  }
}
```

### 22.2 breadcrumb bridge

`os.Logger` のラッパで主要 `info` 以上を `SentrySDK.addBreadcrumb(...)` に転送。

### 22.3 タグ

- `feature` ("alarm" / "mission" / "paywall" / "auth")
- `tier` ("free" / "pro")
- `mission_kind`
- `domain_error_code`

### 22.4 dSYM upload

Xcode Cloud post-action で `sentry-cli upload-dif --auth-token $SENTRY_TOKEN`、Build phase で自動化。

---

## 23. ローカライズ詳細

### 23.1 String Catalog 構成

`Localizable.xcstrings` に全 UI 文字列。キー命名: `feature.subfeature.role`、例 `alarm.editor.save_button` `mission.pushup.start_prompt`。

### 23.2 Plural / Stringsdict

`Localizable.xcstrings` の plural variations サポートを使用、別 `.stringsdict` 不要。

### 23.3 InfoPlist localization

`InfoPlist.xcstrings` で `NSAlarmKitUsageDescription`, `NSCameraUsageDescription` 等を JA + EN 提供。

### 23.4 日時・数値

`Date.FormatStyle` `Number.FormatStyle` を `Locale.current` で。ハードコード `"yyyy/MM/dd"` は禁止。

### 23.5 AI 生成テンプレのローカライズ

Edge Function `/missions/generate` 呼出時に `locale` を渡し、Gemini に対し「Generate in Japanese / English」を指示。EN 用テンプレはサーバ側で別キャッシュ。

### 23.6 特商法のみ JA

§17.1 通り、特商法本文は JA のみ。EN ユーザーには JA 本文＋EN サマリを併記。

---

## 24. アクセシビリティ詳細

### 24.1 VoiceOver

- 全 SwiftUI コンポーネントに `accessibilityLabel`, `accessibilityHint`, `accessibilityValue` 必須
- Alarm カード: `accessibilityElement(children: .combine)` で 1 ボタンとして読上
- Pushup ミッション中: rep カウント変化を `accessibilityNotification(.announcement)` で通知

### 24.2 Pushup の音声代替

視覚依存の Pushup/Squat は VoiceOver 有効ユーザーには代替 UX が必要：
- 自動的に Math ミッションを提案（フォールバック §8.6）
- もしくは「音声カウント」モードで rep ごとにビープ＋VoiceOver アナウンス

設定で「視覚補助モード」トグル提供。

### 24.3 Dynamic Type

`Font.system(...).dynamicTypeSize(...DynamicTypeSize.xxxLarge)` で上限指定。`OMTypography` トークン経由で一元管理。Lock Screen widget は固定サイズ（widget の制約）。

### 24.4 Reduce Motion

`@Environment(\.accessibilityReduceMotion)` を全アニメーションで参照。Live Activity の進捗 ring も reduce motion 時はフェードのみ。

### 24.5 色覚補助

Object Hunt の検出済みマーカは色だけでなく **チェックアイコン**を併用。`OMColor` token で「success」「warning」「danger」を semantic に定義、color blindness friendly palette。

### 24.6 触覚

`CHHapticEngine` で rep ごとの軽いタップフィードバック、ミッション成功で勝利パターン。`UIAccessibility.isReduceMotionEnabled` だが触覚は別設定（`@Environment(\.accessibilityReduceMotion)` には連動しない）。

### 24.7 文字コントラスト

WCAG AA（contrast ratio 4.5:1 以上）を `OMColor` セマンティクスで担保。`@Environment(\.colorSchemeContrast) == .increased` 時のカラーバリアントを別途定義。

---

## 25. Liquid Glass / iOS 26 デザインシステム

### 25.1 採用方針

iOS 26 Liquid Glass を **積極的に full adoption**。アラームアプリは「夜間に見る」UX が多く、Glass の透過感が雰囲気に合う。

### 25.2 トークン

```
OMColor (semantic):
  - background.primary / secondary / tertiary
  - surface.glass.subtle / regular / prominent  ← Liquid Glass tinted
  - content.primary / secondary / accent
  - status.success / warning / danger / info
  - mission.{kind}.accent  ← ミッション種別ごとのアクセント色
```

### 25.3 コンポーネント

- `OMGlassPanel`: `.glassEffect(.regular, in: .rect(cornerRadius: OMRadius.lg))` ラッパ
- `OMButton`: 3 variant — `prominent`（filled）/ `secondary`（glass）/ `ghost`（borderless）
- `OMProgressRing`: countdown とミッション進捗の両用

### 25.4 Glass の制限

- 過剰使用は読みづらさ／パフォーマンス低下を招く。1 画面に 3 layer まで
- Lock Screen widget は Glass 不可（widget 側 API 制約）→ flat tinted

### 25.5 Dark mode

OkiMission は **dark mode 主体**で設計（朝起動時に眩しさ抑制）。light mode も実装するが secondary。

### 25.6 ハプティクス＋アニメ統合

ミッション成功時: 0.8 秒の expansion animation + `CHHapticEvent` series（success pattern）+ optional sound chime（設定でトグル）。

---

## 26. Navigation 詳細

### 26.1 Route enum

```swift
enum AppRoute: Hashable {
  case alarmList
  case alarmDetail(alarmId: UUID)
  case alarmEditor(mode: AlarmEditorMode)
  case missionRun(runId: UUID)
  case missionResult(runId: UUID)
  case history
  case settings
  case settingsAccount
  case settingsSubscription
  case paywall(trigger: PaywallTrigger)
  case tokushoho
  case legal(LegalPage)
  case onboarding
  case ossLicenses
}
```

### 26.2 RootView

```
RootView
 ├─ if !auth.isSignedIn → OnboardingFlow
 ├─ else → MainTabView (Alarms / History / Settings)
 │           └─ NavigationStack(path: $router.path)
 │                 .navigationDestination(for: AppRoute.self) { ... }
 └─ .sheet(item: $router.modalRoute) { ... }
```

### 26.3 Deep link

- `okimission://mission/<runId>` → mission runner
- App Intent 経由は `OpensIntent` で直接 path 操作

### 26.4 Tab 構成

Phase 1 は **3 tab**: アラーム / 履歴 / 設定。Paywall, Mission Run, Editor は modal/full-screen-cover。

---

## 27. CI / CD 詳細

### 27.1 Xcode Cloud 採用

理由: 個人開発で別 CI セットアップは ROI 悪。Xcode Cloud は Apple Developer 加入で無料 25 compute hours/月、足りない場合 $50/月で 100 hours。

### 27.2 ワークフロー

| Workflow | Trigger | Steps |
|---|---|---|
| `PR Check` | PR open / update | build + unit test + UI test (smoke) |
| `Beta Build` | `claude/*` ブランチ push | build + test + Sentry dSYM + TestFlight upload |
| `Release` | `release/*` ブランチ push | build + test + dSYM + App Store Connect submit |
| `Nightly` | 毎晩 03:00 JST | snapshot test + perf benchmark + Sentry release |

### 27.3 コード署名

- Automatic signing: 個人開発は automatic で十分
- Manual を選ぶ場面: Critical Alerts entitlement 取得時など特殊 entitlement の場合のみ

### 27.4 Sentry / PostHog 統合

- dSYM upload: Xcode Cloud post-build script で `sentry-cli upload-dif`
- Sentry release marker: `sentry-cli releases new okimission@$VERSION` + `releases finalize`
- PostHog: release 番号を `app.launch` event property で送信

### 27.5 Snapshot Test

- swift-snapshot-testing で主要 View（AlarmListView, MissionLauncherView, PaywallView）の record/verify
- 3 device size × 2 mode (light/dark) × 2 dynamic type → 12 snapshot/view
- 失敗時は PR コメントに diff 画像（GitHub Actions 経由、Xcode Cloud は画像コメント弱い）

### 27.6 性能ベンチマーク

XCTest performance test で：
- cold start time（`XCUIApplication().launch()` の経過時間）
- mission first-frame レイテンシ（mock camera）
- AlarmService.schedule throughput

Nightly で実行、PostHog にプッシュ。

---

## 28. パフォーマンス予算

| 指標 | iPhone 11 目標 | iPhone 15 Pro 目標 | 計測 |
|---|---|---|---|
| Cold start (launch → AlarmList interactive) | ≤ 2.0 s | ≤ 1.0 s | Xcode profiler |
| AlarmList scroll FPS | ≥ 55 | ≥ 60 | Instruments |
| AlarmService.schedule 1 件 | ≤ 200 ms | ≤ 100 ms | XCTest perf |
| カメラ起動 → 1 frame | ≤ 800 ms | ≤ 400 ms | 実測 |
| ObjectHunt 推論 per frame | ≤ 80 ms | ≤ 40 ms | Vision profiler |
| Pose 推論 per frame | ≤ 35 ms | ≤ 18 ms | 同上 |
| ミッション中 1 分あたりバッテリ消費 | ≤ 1.5% | ≤ 1.0% | Xcode Energy |
| メモリ peak（ミッション中） | ≤ 180 MB | ≤ 200 MB | Instruments |
| アプリバイナリサイズ | ≤ 80 MB | ≤ 80 MB | Xcode size |
| dSYM 付きアーカイブ | ≤ 250 MB | — | — |
| 起動時通信回数 | ≤ 3 件（Supabase auth refresh, RC customer info, PostHog identify） | — | 計装 |

予算違反は CI で fail（Phase 2、まず計装と可視化）。

---

## 29. エラーハンドリング / オフライン戦略

### 29.1 ネットワーク必要性マップ

| 機能 | ネット要 | フォールバック |
|---|---|---|
| アラーム作成・編集 | 不要 | — |
| アラーム発火 | 不要 | — |
| ミッション実行 | 不要 | — |
| AI ミッション生成 | 推奨（prefetch あり） | バンドル fallback templates |
| Sign in with Apple | 必要 | キャッシュ済 session で起動可（read-only モード） |
| RC entitlement check | 推奨 | SubscriptionCacheSnapshot で 7 日 grace |
| PostHog | 不要 | AnalyticsOutbox 退避 |
| Sentry | 不要 | 自動 retry |
| Postgres ミラー | 不要 | SyncQueue 退避 |

### 29.2 エラー UX

- ネット断トースト: 一度だけ表示、永続 banner なし（ノイズ）
- 認証期限切れ: 静かに再ログイン試行、失敗時のみ UI 表示
- AlarmKit 失敗: 「アラームを登録できません、設定で許可してください」CTA

### 29.3 Reachability

`NWPathMonitor` を `Reachability` actor でラップ、`AsyncStream<NWPath.Status>` を発行。各サービス（Outbox, SyncQueue）が購読。

---

## 30. Onboarding フロー詳細

### 30.1 ステップ

```
1. Welcome / 価値訴求（1 画面、スキップ不可）
2. Sign in with Apple（必須）
3. ロケール確認（自動検出済、変更可）
4. 通知許可リクエスト（説明付き）
5. AlarmKit 許可リクエスト（必須、拒否時は再リクエストフロー）
6. 最初のアラーム作成チュートリアル（time picker + sound preview）
7. ミッション概念紹介（3 種選択：簡単・運動・写真）
8. Paywall 初回提示（変動：直訴 v.s. defer）→ 完了
```

権限要求順序は **重要**: 通知 → AlarmKit → カメラ（カメラは lazy、ミッション初回起動時）。一気に出さない。

### 30.2 完了マーク

`UserProfile.onboardingCompletedAt = Date()`、次回起動からスキップ。

---

## 31. Wayk-specific 差別化機能の設計

### 31.1 ストリーク

- 「成功」定義: 1 日 1 回以上、いずれかのアラームでミッション success
- リセット条件: 24 時間以内に success がない（タイムゾーンは `UserProfile.preferredLocale` から決定）
- マイルストーン: 7 日 / 30 日 / 100 日 / 365 日で celebration UI＋通知

### 31.2 時間帯別ミッション生成

Edge Function `/missions/generate` の `difficultyHint` に `morning_easy` / `morning_energetic` / `evening_calm` 等を含め、Gemini プロンプトで「朝向きの軽い運動」「夜向きの読書系」などを生成。

### 31.3 ソーシャル / フレンド機能

**Phase 1 では実装しない**。Phase 2 で Supabase Realtime + 友人ストリーク比較を検討。

### 31.4 シェア画像生成

`Features/History/ShareImageRenderer.swift` で SwiftUI View → `ImageRenderer(content:)` → UIImage → ShareLink。テンプレ:
- 朝の成功カード（時刻・ストリーク日数・ミッション kind）
- マイルストーンカード（7 日達成等）

JA / EN ラベルは描画時に切替。

### 31.5 音声起こしの将来

Phase 2 で TTS による「○○さん、おはようございます」読み上げ。今は ElevenLabs prebake のみ。

---

## 32. Apple Watch 対応

### 32.1 Phase 1（launch 時）

watchOS app なし。Live Activity が Smart Stack に自動ミラーされる（iOS 26 + watchOS 26 の機能）。これで「アラームが Watch にも表示される」UX が成立。

### 32.2 Phase 2 検討

watchOS native app を追加し、独自 Pose / Heart Rate 系ミッションを追加。`WKAlarmKit` 同等 API がある場合のみ採用。

---

## 33. 再検証チェックポイント（全主要決定 25 項目）

| # | 決定 | トリガ | アクション |
|---|---|---|---|
| 1 | AlarmKit entitlement | 初回 Release ビルド | 拒否時は Critical Alerts entitlement 申請＋縮退、ship-blocker 判定 |
| 2 | AlarmKit `StopAlarmIntent` swipe-dismiss 発火 | iOS 26.x 各 release | 安定発火なら「dismissed-without-mission」検出を簡素化 |
| 3 | AlarmKit 最大アラーム本数 | β 期間中、64 本超ストレステスト | 上限改定 or 上限警告 UI 追加 |
| 4 | iOS 26 普及率 JP 70% | 四半期、StatCounter＋Apple 公式 | 達成で最低 OS 26.2 へ |
| 5 | iOS 26 デバイス分布変化 | 半期 | iPhone 11 利用率が <5% なら 最低 12 へ |
| 6 | Liquid Glass パフォーマンス | iPhone 11 実機テスト | 60fps 維持できないなら Glass 階層削減 |
| 7 | Body Pose 精度（横向き・低光） | β 完走率 | <60% なら横向き禁止 or hint 強化 |
| 8 | CreateML 日本家屋 mAP | 毎訓練 | <0.55 で ship 不可、データ拡張 |
| 9 | 物体検出モデルサイズ | バイナリ >150 MB | ODR 化 |
| 10 | Vision per-frame レイテンシ | iPhone 11 計測 | >80ms なら入力サイズ縮小 |
| 11 | Gemini Flash コスト | 月次 | 上限超で 夜間バッチのみ化 |
| 12 | Gemini Flash p95 latency | 週次 | >3s で別モデル検討 |
| 13 | RevenueCat Paywalls v2 vs 特商法 | 設計レビュー | 自前画面化（部分） |
| 14 | StoreKit Transaction observer 起動順 | リリース前 e2e | Apple ガイド準拠確認、UI 描画前完了 |
| 15 | MRR 200 万円突破 | 月次 | Apple 外部リンク entitlement 検討 |
| 16 | PostHog Free 上限 | 月次 | 非クリイベントのサンプリング |
| 17 | Sentry Free 上限 | 月次 | 同上 |
| 18 | Supabase Pro quota 70% | 月次 | Team プラン or 移行検討 |
| 19 | Apple Watch Smart Stack 実機 | watchOS 26 実機 | 不足なら watchOS target 追加 |
| 20 | App Intents extension cold-start | iPhone 11 profile | <300ms ならホスト統合可、>1s なら最適化必須 |
| 21 | BGAppRefresh ヒット率 | 30 日 β テレメトリ | <40% で silent push 切替 |
| 22 | 特商法表記の弁護士レビュー | 月商 100 万円到達 | 5–15 万円で外部レビュー |
| 23 | アカウント削除フロー | App Store 審査前 | 5.1.1(v) 準拠を実機検証 |
| 24 | Privacy Manifest コンプライアンス | リリース前＋SDK 更新時 | warning 0 確認 |
| 25 | サブスク継続率 / churn | 月次 | <30% で paywall 再設計 |
| 26 | iCloud 同期需要 | β アンケート | 要望多なら Phase 2 で `.cloudKitDatabase` |
| 27 | 法人化検討 | 月商 500 万円 | 税理士相談 |
| 28 | Ultralytics YOLO Enterprise 価格公開 | 公開時 | 再評価（現状 Vision で十分） |
| 29 | iOS 27 announce | 2026 年 6 月 WWDC | AlarmKit 2.0 / 新 API の影響評価 |

---

## 34. クリティカルファイル（初手 20 ファイル）

新規作成。実装順：

1. `OkiMission/App/OkiMissionApp.swift`
2. `OkiMission/App/Bootstrap.swift`
3. `OkiMission/Core/Persistence/Schema/SchemaV1.swift`
4. `OkiMission/Core/Persistence/Models/Alarm.swift`
5. `OkiMission/Core/Persistence/Models/MissionTemplate.swift`
6. `OkiMission/Core/Persistence/Models/MissionRun.swift`
7. `OkiMission/Core/Persistence/Models/AudioPack.swift`
8. `OkiMission/Core/Persistence/Models/UserProfile.swift`
9. `OkiMission/Services/AlarmKit/AlarmService.swift`
10. `OkiMission/Services/AlarmKit/AlarmConfigurationBuilder.swift`
11. `OkiMission/Services/AlarmKit/AlarmMetadataPayload.swift`
12. `OkiMission/Services/LiveActivity/AlarmActivityAttributes.swift`
13. `OkiMission/Services/LiveActivity/ActivityController.swift`
14. `OkiMission/Features/AlarmFiring/Intents/StartMissionIntent.swift`
15. `OkiMission/Features/AlarmFiring/Intents/SnoozeIntent.swift`
16. `OkiMission/Features/AlarmFiring/Intents/StopAlarmIntent.swift`
17. `OkiMission/Features/Missions/Shared/Mission.swift`
18. `OkiMission/Features/Missions/Math/MathMission.swift`  ← 最簡単、第1ミッション
19. `OkiMission/Features/AlarmList/AlarmListView.swift`
20. `OkiMission/Features/AlarmEditor/AlarmEditorView.swift`

参照（流用元、LICENSE 確認後）:
- `jacobsapps/ADHDAlarms` の `AlarmModel`, `AlarmConfiguration` 組立, `Alarm.Schedule.relative()` パターン, 色トグル UX, `SnoozeDelaySection`

---

## 35. 検証マトリクス（end-to-end）

実機検証（iPhone 11 と iPhone 15 Pro 両方）必須。

| カテゴリ | 検証項目 | 合格条件 |
|---|---|---|
| 権限 | AlarmKit 認可ダイアログ | 初回起動で表示、許可で `authorizationState = .authorized` |
| 権限 | カメラ権限（lazy） | ミッション初回起動時のみダイアログ |
| エンタイトルメント | provisioning profile | Release で `com.apple.developer.alarmkit` 含む |
| アラーム | 1-shot 発火 | 5 分後設定、画面ロック、サイレント switch ON でも発火 |
| アラーム | 週次 recurring | 翌週同曜日同時刻に再発火 |
| アラーム | countdown 5 分 | Live Activity 表示、Dynamic Island 表示 |
| アラーム | 最大本数 | 64 本登録できる |
| ミッション | Math 完走 | 5 問正解で `outcome=.success` |
| ミッション | Pushup 5rep | カメラ前で 5 回 → rep counter 5 表示 |
| ミッション | ObjectHunt | 事前撮影 3 物体検出で success |
| ミッション | フォールバック | カメラ拒否でも Math へ自動切替 |
| ミッション | kill 復旧 | 起動 5 分以内に再開ダイアログ |
| ミッション | アンチチート | 時計改変で `outcome=.cheated` |
| Live Activity | countdown | 残り時間が秒単位で減少表示 |
| Live Activity | mission progress | 進捗 0→1 で更新 |
| 認証 | SiwA 初回 | Supabase `auth.users` 行作成、profiles 行も作成 |
| 認証 | 自動再ログイン | Kill restart で再ログイン不要 |
| 認証 | アカウント削除 | profiles soft delete、SiwA revoke 試行、Keychain クリア |
| 課金 | Paywall 表示 | 2 個目アラーム作成で表示 |
| 課金 | 特商法シート | purchase 前に必ず表示、チェックなしで disable |
| 課金 | 購入成功 | RC entitlement `pro` 反映、Pro ミッションロック解除 |
| 課金 | 復元 | 別端末で SiwA 同一 user → entitlement 復元 |
| 課金 | webhook | RC dashboard で送信した event が `billing_events` に到達 |
| AI | prefetch | 夜間 BGAppRefresh 後、`mission_generations` に翌日分行 |
| AI | rate limit | 6 回目で 429 |
| AI | fallback | offline で fallback テンプレ起動 |
| 通知 | streak 警告 | 24h 成功なしで翌 20:00 表示 |
| 分析 | PostHog | 主要 20 種イベントが dashboard 着信 |
| 分析 | outbox | offline 時バッファ、online で flush |
| クラッシュ | Sentry | 強制クラッシュが dashboard 着信、dSYM 解決済 |
| ローカライズ | EN モード | システム EN で UI 英語、Tokushoho のみ JA |
| アクセシビリティ | VoiceOver | AlarmList 全行読上、Pushup VoiceOver 時は Math 提案 |
| アクセシビリティ | Dynamic Type | XXL で UI 破綻なし |
| パフォーマンス | cold start | iPhone 11 で 2.0s 以下 |
| パフォーマンス | バイナリ | ≤80MB |
| Watch | Smart Stack | iPhone Live Activity が Watch に表示 |
| 法務 | 特商法 LP | KIYAC 生成 + アプリ内 native + シート 3 箇所 |
| 法務 | Privacy Manifest | Xcode warning 0 |
| 法務 | Privacy Nutrition Labels | App Store Connect 入力済 |

`OkiMission-Beta` で TestFlight 配布、外部テスター 30–50 名で 1 週間：crash-free user 率 ≥99.5%、Day 1 retention ≥40%、ミッション完走率 ≥60% を確認後 Release。

---

## 36. 残課題 / Caveats

設計の前提が変わると影響大な項目：

1. **AlarmKit 1.0 の `OpenAlarmAppIntent` / `PauseAlarmIntent` / `ResumeAlarmIntent` の正確な仕様**は Apple 公式ドキュメントが JS レンダリングで取得困難。実装時に Xcode 26 のヘッダで再確認必須
2. **AlarmKit `secondaryButtonBehavior: .custom` の正確な enum 名**は Xcode で確認必須（`.custom` ではなく別命名の可能性）
3. **AlarmKit 最大アラーム本数**は公式未公開、64 上限は OkiMission 側の安全策
4. **Privacy Manifest の Required Reason API コード**（`CA92.1`, `C617.1` 等）は Apple 公式が更新されているので、ビルド時に Xcode warning と照合
5. **AppleSiwA `client_secret` JWT 署名仕様**は Apple Developer 設定で Key 作成後に正確値を確認
6. **RevenueCat Paywalls v2 で特商法シート挿入可能か** はバージョン依存、実装着手時に検証
7. **Supabase Edge Function の Deno ランタイム制限**（メモリ・実行時間）が Gemini API レイテンシと組合せで問題ないか実測必要
8. **iOS 26 Liquid Glass の iPhone 11 (A13) 実機パフォーマンス**は実測必須、Glass 階層を要調整可能性
9. **CreateML 日本家屋モデルの実訓練 mAP** は訓練データ確保後でないと不明。launch ブロッカー条件 0.55 を達成できない場合、Phase 1 はビルトイン COCO クラスのみで開始する選択肢
10. **特商法 「所在地省略可能」の最新解釈**は弁護士レビューで最終確認、サブスクで規約違反すると 100 万円罰金
11. **Apple Watch Smart Stack の Live Activity 自動ミラー**が iOS 26 + watchOS 26 の正式機能か実機検証必要
12. **App Intents extension の cold-start latency** は iPhone 11 で profile しないと最終判断不可

これらは §33 のチェックポイントで継続的に再評価する。

---

# Appendix A — AlarmKit / iOS Framework 深掘り

## A.1 AlarmKit API surface（実装擬似コード）

### A.1.1 AlarmConfiguration 組み立て（pseudocode）

```swift
struct AlarmConfigurationBuilder {
  static func build(from alarm: Alarm) throws -> AlarmConfiguration<AlarmMetadataPayload> {
    let metadata = AlarmMetadataPayload(
      alarmId: alarm.id,
      missionTemplateId: alarm.missionTemplateId,
      missionKind: alarm.missionTemplateId.flatMap { /* lookup */ }
    )
    
    let presentation = AlarmPresentation(
      alert: .init(
        title: LocalizedStringResource(stringLiteral: alarm.label),
        stopButton: .init(
          text: "停止", textColor: .white, systemImageName: "stop.fill"
        ),
        secondaryButton: alarm.missionTemplateId != nil
          ? .init(text: "ミッション", textColor: .white, systemImageName: "play.fill")
          : nil,
        secondaryButtonBehavior: .custom  // App Intent ルート
      ),
      countdown: alarm.scheduleKind == .countdown ? .init(
        title: LocalizedStringResource(stringLiteral: alarm.label),
        pauseButton: .init(text: "一時停止", textColor: .white, systemImageName: "pause.fill")
      ) : nil
    )
    
    let attributes = AlarmAttributes(
      presentation: presentation,
      metadata: metadata,
      tintColor: .accentColor
    )
    
    let sound: AlertConfiguration.Sound = .named(alarm.soundId + ".caf")
    
    switch alarm.scheduleKind {
    case .oneShot:
      guard let fireDate = alarm.fireDate else { throw DomainError.invalidAlarmConfig }
      return AlarmConfiguration(
        schedule: .fixed(fireDate),
        attributes: attributes,
        sound: sound,
        stopIntent: StopAlarmIntent(alarmId: alarm.id.uuidString),
        secondaryIntent: StartMissionIntent(alarmId: alarm.id.uuidString)
      )
      
    case .recurringWeekly:
      guard let h = alarm.timeOfDayHour, let m = alarm.timeOfDayMinute else {
        throw DomainError.invalidAlarmConfig
      }
      let weekdays = Weekday.decode(mask: alarm.weekdayMask)
      return AlarmConfiguration(
        schedule: .relative(.init(
          time: .init(hour: h, minute: m),
          repeats: .weekly(weekdays)
        )),
        attributes: attributes,
        sound: sound,
        stopIntent: StopAlarmIntent(alarmId: alarm.id.uuidString),
        secondaryIntent: StartMissionIntent(alarmId: alarm.id.uuidString)
      )
      
    case .countdown:
      guard let seconds = alarm.countdownSeconds else { throw DomainError.invalidAlarmConfig }
      let duration = Alarm.CountdownDuration(
        preAlert: TimeInterval(seconds),
        postAlert: 60  // 自動停止までの猶予
      )
      return AlarmConfiguration(
        countdownDuration: duration,
        attributes: attributes,
        sound: sound,
        stopIntent: StopAlarmIntent(alarmId: alarm.id.uuidString),
        secondaryIntent: StartMissionIntent(alarmId: alarm.id.uuidString)
      )
    }
  }
}
```

※ 実 API 名は Xcode 26 ヘッダで再確認必須（§36 #1, #2）。`secondaryButtonBehavior` の正確な enum 値、`Alarm.CountdownDuration` のイニシャライザシグネチャ、`AlarmAttributes` の `tintColor` 受付有無は実機ビルドで確定。

### A.1.2 AlarmService 主要メソッド

```swift
@MainActor
final class AlarmService {
  static let shared = AlarmService()
  private let manager = AlarmManager.shared
  private var updatesTask: Task<Void, Never>?
  
  func bootstrap() async {
    // alarmUpdates 購読
    updatesTask = Task {
      for await snapshot in manager.alarmUpdates {
        await alarmEventBus.emit(.snapshot(snapshot))
      }
    }
  }
  
  func requestAuthorization() async throws -> AlarmAuthorizationState {
    let state = try await manager.requestAuthorization()
    await alarmAuthorizationStore.update(state)
    return state
  }
  
  func schedule(_ alarm: Alarm) async throws -> UUID {
    let config = try AlarmConfigurationBuilder.build(from: alarm)
    let kitAlarm = try await manager.schedule(config)
    // alarmKitId を SwiftData に書き戻し
    try await alarmRepository.setAlarmKitId(domainId: alarm.id, kitId: kitAlarm.id)
    return kitAlarm.id
  }
  
  func cancel(domainAlarmId: UUID) async throws {
    guard let kitId = try await alarmRepository.fetchAlarmKitId(domainId: domainAlarmId) else { return }
    try await manager.cancel(kitId)
    try await alarmRepository.clearAlarmKitId(domainId: domainAlarmId)
  }
  
  func resyncAll() async throws {
    // 端末再起動 or プロセス再起動後、SwiftData と AlarmKit の状態を整合
    let kitAlarms = try await manager.alarms
    let domainAlarms = try await alarmRepository.allEnabled()
    
    let kitIds = Set(kitAlarms.map(\.id))
    let domainKitIds = Set(domainAlarms.compactMap(\.alarmKitId))
    
    // KitにあってDomainにない → 孤児、キャンセル
    for orphanId in kitIds.subtracting(domainKitIds) {
      try? await manager.cancel(orphanId)
    }
    // DomainにあってKitにない → 再スケジュール
    for missingAlarm in domainAlarms where missingAlarm.alarmKitId == nil
                                       || !kitIds.contains(missingAlarm.alarmKitId!) {
      _ = try await schedule(missingAlarm)
    }
  }
}
```

`resyncAll()` は **OS アップデート後 / 強制再起動後 / アプリ更新後** の起動時に呼ぶ（§17 Bootstrap 手順に組込）。

### A.1.3 AlarmEvent

```swift
enum AlarmEvent: Sendable {
  case snapshot([Alarm<AlarmMetadataPayload>])
  case stateChanged(alarmId: UUID, newState: AlarmKitState)
  case dismissedWithoutMission(alarmId: UUID, at: Date)
}

actor AlarmEventBus {
  private var subject = AsyncStream.makeStream(of: AlarmEvent.self).continuation
  let stream: AsyncStream<AlarmEvent>
  
  init() {
    let (s, c) = AsyncStream.makeStream(of: AlarmEvent.self)
    self.stream = s; self.subject = c
  }
  
  func emit(_ event: AlarmEvent) { subject.yield(event) }
}
```

「dismissed-without-mission」検出：snapshot で `.completed` 状態に遷移した直後 30 秒以内に該当 `MissionRun` が作成されなければ `.dismissedWithoutMission` を発行。

## A.2 AlarmKit と OS 機能の相互作用

| OS 機能 | AlarmKit 挙動 | OkiMission での扱い |
|---|---|---|
| サイレントスイッチ | bypass（鳴る） | 仕様通り、ユーザー設定不要 |
| Focus mode / DnD | bypass（鳴る） | 同上 |
| Sleep Focus | bypass、ベッドタイム連動なし | アラーム時刻と Sleep Focus は独立 |
| Low Power Mode | 通常動作（公式記載なし） | 実機検証 |
| 機内モード | ローカル発火なので影響なし | — |
| 充電中／放電中 | 影響なし | — |
| 端末ロック | Lock Screen UI 表示 | Live Activity が full activate |
| StandBy mode | 大型レイアウト表示 | `StandByView` レンダラ実装 |
| AirPlay 音声 | システムが routing | — |
| 通話中 | AlarmKit は鳴る、ユーザーは無視可 | 録音はしない |

## A.3 AVAudioSession 詳細設計

### A.3.1 ライフサイクル

```swift
@MainActor
final class AudioSessionCoordinator {
  enum Activity { case idle, missionRunning, missionFeedback }
  private var current: Activity = .idle
  
  func enter(_ activity: Activity) async throws {
    let session = AVAudioSession.sharedInstance()
    switch activity {
    case .idle:
      try session.setActive(false, options: [.notifyOthersOnDeactivation])
    case .missionRunning, .missionFeedback:
      try session.setCategory(.playback, mode: .default,
        options: [.mixWithOthers, .duckOthers]
      )
      try session.setActive(true)
    }
    current = activity
  }
}
```

### A.3.2 中断処理

```swift
NotificationCenter.default.addObserver(
  forName: AVAudioSession.interruptionNotification,
  object: nil, queue: nil
) { notification in
  guard let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
  switch type {
  case .began:
    Task { await missionRunner.pause(reason: .audioInterrupted) }
  case .ended:
    let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
    let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
    if options.contains(.shouldResume) {
      Task { await missionRunner.resume() }
    }
  @unknown default: break
  }
}
```

### A.3.3 ルート変更（イヤホン抜き挿し）

```swift
AVAudioSession.routeChangeNotification を監視:
  oldRoute に headphones がいて、newRoute にいなければ → ミッション一時停止
```

## A.4 Background Modes / BGTask 詳細

### A.4.1 Background Modes 必要性

- `audio`: ミッション中の TTS / カウント音声を背景再生で継続する場合に必要。AlarmKit 自体には不要（システム管理）。実装時に音声フィードバックを必須化しないなら削除可
- `processing`: BGProcessingTask 経由の長時間処理（AI prefetch のうち重い処理）
- `remote-notification`: silent push 受信

### A.4.2 BGTask 完全実装

```swift
// Bootstrap.swift
BGTaskScheduler.shared.register(
  forTaskWithIdentifier: "com.example.okimission.ai-prefetch",
  using: nil
) { task in
  AIPrefetchJob.handle(task as! BGAppRefreshTask)
}

BGTaskScheduler.shared.register(
  forTaskWithIdentifier: "com.example.okimission.analytics-flush",
  using: nil
) { task in
  AnalyticsFlushJob.handle(task as! BGProcessingTask)
}

// AIPrefetchJob
enum AIPrefetchJob {
  static func handle(_ task: BGAppRefreshTask) {
    scheduleNext()  // 翌晩の再実行を登録
    let workTask = Task {
      try? await geminiProxyClient.prefetchTomorrowsMission()
      task.setTaskCompleted(success: true)
    }
    task.expirationHandler = { workTask.cancel() }
  }
  
  static func scheduleNext() {
    let request = BGAppRefreshTaskRequest(
      identifier: "com.example.okimission.ai-prefetch"
    )
    // 翌 0:00 JST 〜 03:00 JST の間で OS に委ねる
    request.earliestBeginDate = nextMidnightJST
    try? BGTaskScheduler.shared.submit(request)
  }
}
```

### A.4.3 BGAppRefresh 信頼性

Apple は 実行を **保証しない**。実測値:
- 充電中・接続中・夜間 → ヒット率 60–80%
- バッテリ駆動・低使用ユーザー → 30–50%

OkiMission 戦略: prefetch 失敗を前提に、起動時の foreground fetch（Reachability 良好時）も並行で行う。ユーザーが朝起動するまでに翌日分が揃っていない場合はバンドル fallback を使用。

## A.5 StoreKit 2 Transaction Observer 詳細

### A.5.1 起動順序（Apple HIG 要件）

```
1. App init (SwiftUI body 描画前)
2. RevenueCat.configure  ← これ自体が内部で Transaction observer 起動
3. Transaction.updates 購読開始  ← RC が代行するが念のため自前でも起動
4. UI 描画開始
```

RC SDK の `configure` 時点で transaction observer が自動起動するため、自前 `StoreKitListener` は **redundancy（多層防御）**：RC が落ちた場合・通知漏れ対策。

### A.5.2 自前 Transaction Listener

```swift
final class StoreKitListener {
  private var task: Task<Void, Never>?
  
  func startListening() {
    task = Task.detached(priority: .background) { [weak self] in
      for await result in Transaction.updates {
        await self?.process(result)
      }
    }
  }
  
  func stopListening() { task?.cancel() }
  
  private func process(_ result: VerificationResult<Transaction>) async {
    switch result {
    case .verified(let transaction):
      // RC が処理するので、ここでは Sentry に breadcrumb のみ
      Logger.subscriptions.info("Transaction verified: \(transaction.productID)")
      await transaction.finish()
    case .unverified(let transaction, let error):
      Logger.subscriptions.error("Unverified transaction \(transaction.id): \(error)")
      // unverified でも finish しないと再送され続ける
      await transaction.finish()
    }
  }
}
```

### A.5.3 払い戻し（Refund）

ユーザーが App Store で refund を要求し、Apple が承認すると：
- `Transaction.updates` に `.unverified` または `revocation_date` 付き transaction が流れる
- RC webhook の `CANCELLATION` イベントで `subscription_tier` を `free` に戻す
- アプリ側は次回 `customerInfoStream` で `.pro → .free` 遷移、UI が即座にロック状態に

### A.5.4 Sandbox vs Production

- Beta (TestFlight) は **常に Sandbox**
- Debug ビルドは StoreKit Configuration File（`OkiMission.storekit`）でローカル模擬
- Release は Production

## A.6 Keychain アクセス制御

```swift
let access = SecAccessControlCreateWithFlags(
  nil,
  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,  // 端末ロック解除後アクセス可、バックアップ対象外
  [],
  nil
)!

let query: [String: Any] = [
  kSecClass as String: kSecClassGenericPassword,
  kSecAttrService as String: "com.example.okimission",
  kSecAttrAccount as String: "appleUserIdentifier",
  kSecAttrAccessControl as String: access,
  kSecValueData as String: data
]
```

- `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: iCloud Keychain 経由で他端末に同期されない（マルチデバイスでは再ログインさせる）
- バイオメトリクス保護は不要（アラームアプリで都度認証は UX 劣化）

## A.7 URLSession / HTTPClient 詳細

```swift
final class HTTPClient {
  private let session: URLSession
  
  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 15
    config.timeoutIntervalForResource = 30
    config.waitsForConnectivity = true  // 圏外時に接続復活を待つ
    config.urlCache = URLCache(memoryCapacity: 4_000_000, diskCapacity: 20_000_000)
    config.httpAdditionalHeaders = [
      "User-Agent": "OkiMission/\(Bundle.appVersion) iOS/\(UIDevice.current.systemVersion)"
    ]
    self.session = URLSession(configuration: config)
  }
  
  func send<T: Decodable>(_ request: APIRequest, as: T.Type) async throws -> T {
    var attempt = 0
    var lastError: Error?
    while attempt < 3 {
      do {
        let (data, response) = try await session.data(for: request.urlRequest)
        // 429 / 5xx は backoff
        if let http = response as? HTTPURLResponse, (http.statusCode == 429 || http.statusCode >= 500) {
          throw HTTPError.retryable(http.statusCode)
        }
        return try JSONDecoder.appDefault.decode(T.self, from: data)
      } catch HTTPError.retryable {
        attempt += 1
        let delay = pow(2.0, Double(attempt))  // 2, 4, 8 sec
        try await Task.sleep(for: .seconds(delay))
      } catch {
        throw error
      }
    }
    throw lastError ?? HTTPError.exhausted
  }
}
```

タイムアウト 15 秒は Edge Function 経由 Gemini の最悪ケース（thinking off で p99 < 10s 想定）を踏まえる。

## A.8 Critical Alerts 縮退プラン（AlarmKit 不可時）

万一 AlarmKit entitlement が降りない場合の fallback：

1. Apple に `com.apple.developer.usernotifications.critical-alerts` 申請（フォーム提出、数日〜数週間）
2. `UNUserNotificationCenter` で `UNNotificationSound.criticalSoundNamed("...", withAudioVolume: 1.0)` を使い、Focus / DnD を bypass
3. ただし以下の機能を喪失：
   - Live Activity の AlarmKit 連携
   - secondary button（ミッションボタン）→ UNNotification の action だけで代替
   - StandBy 大型表示
4. UX 大幅劣化、launch を 1–2 ヶ月遅らせる ship-blocker 判定

---

# Appendix B — ミッションエンジン 深掘り

## B.1 状態機械 詳細

### B.1.1 状態定義

```swift
enum MissionState: Equatable {
  case idle
  case checkingCapabilities
  case awaitingPermission(Capability)
  case framing(progress: Double)       // 0.0–1.0 カメラ整合度
  case running(progress: Double)
  case paused(reason: PauseReason)
  case verifying                       // 完了判定中（サーバ送信前のローカル検証）
  case completed
  case failed(MissionFailureReason)
  case cancelled
  case cheated([AntiCheatSignal])
}

enum PauseReason {
  case appBackgrounded, audioInterrupted, lowConfidence, userInitiated
}
```

### B.1.2 遷移ルール

```
idle → checkingCapabilities                    (start)
checkingCapabilities → awaitingPermission      (権限未取得)
checkingCapabilities → framing                 (権限OK)
awaitingPermission → framing                   (権限取得後)
awaitingPermission → cancelled                 (拒否)
framing → running                              (整合度>=0.5 が 1秒持続)
framing → cancelled                            (timeout 60s)
running → paused                               (背景化 / 中断)
paused → running                               (前景復帰 within 30s)
paused → failed                                (中断 30s 超過)
running → verifying                            (条件達成)
running → failed                               (timeout / explicit fail)
verifying → completed                          (anti-cheat OK)
verifying → cheated                            (anti-cheat 検出)
```

### B.1.3 状態保持

`MissionRunner` actor 内 `currentState: MissionState`、変更時 `AsyncStream<MissionEvent>` に `.stateChanged` を発行。
View は `@Observable MissionViewModel` 経由で `currentState` を `@MainActor` で参照。

## B.2 アンチチート 詳細

### B.2.1 シグナル収集

```swift
struct AntiCheatContext {
  var backgroundEvents: [Date] = []
  var clockReadings: [(systemUptime: TimeInterval, wallClock: Date)] = []
  var screenshotEvents: [Date] = []
  var frameGaps: [TimeInterval] = []
  var sessionStart: Date
  var sessionStartUptime: TimeInterval
}
```

毎フレーム or イベント発生時に context を更新。ミッション終了時に `evaluate(context:)` で総合判定。

### B.2.2 スコアリング

```swift
func evaluate(context: AntiCheatContext, missionDuration: TimeInterval) -> AntiCheatVerdict {
  var score = 0
  var signals: [AntiCheatSignal] = []
  
  // 背景化
  let bgCount = context.backgroundEvents.count
  if bgCount >= 1 { score += 2 * bgCount; signals.append(.backgrounded(count: bgCount)) }
  
  // 時計改変: wallClock 経過 と systemUptime 経過の差が 5 秒超
  if let first = context.clockReadings.first, let last = context.clockReadings.last {
    let wallDelta = last.wallClock.timeIntervalSince(first.wallClock)
    let uptimeDelta = last.systemUptime - first.systemUptime
    if abs(wallDelta - uptimeDelta) > 5 {
      score += 5
      signals.append(.clockTampered(diff: wallDelta - uptimeDelta))
    }
  }
  
  // スクショ
  if !context.screenshotEvents.isEmpty {
    score += context.screenshotEvents.count
    signals.append(.screenshotsTaken(count: context.screenshotEvents.count))
  }
  
  // フレーム途切れ
  let bigGaps = context.frameGaps.filter { $0 > 1.0 }
  if bigGaps.count >= 3 {
    score += 3
    signals.append(.frameGaps(count: bigGaps.count))
  }
  
  // 短すぎる完了 (Math 全問 5秒以下 等)
  if missionDuration < expectedMinDuration[currentKind] {
    score += 4
    signals.append(.tooFast(duration: missionDuration))
  }
  
  return score >= 5 ? .cheated(signals) : .clean
}
```

### B.2.3 不正への UX 対応

- 即座に banner で「不正検出のためミッション失敗」表示
- ストリーク影響: `.cheated` はストリーク加算なし、`.cheated` 連発（同日 3 回）でアカウント警告
- アカウントの BAN は行わない（個人開発のサポートコスト）。代わりに RC entitlement 与えても feature gate を限定

## B.3 Body Pose アルゴリズム数学

### B.3.1 角度計算 完全実装

```swift
func angle(at vertex: CGPoint, from p1: CGPoint, to p2: CGPoint) -> Double {
  let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
  let v2 = CGVector(dx: p2.x - vertex.x, dy: p2.y - vertex.y)
  let dot = v1.dx * v2.dx + v1.dy * v2.dy
  let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
  let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
  guard mag1 > 0, mag2 > 0 else { return 0 }
  let cosTheta = max(-1, min(1, dot / (mag1 * mag2)))
  return acos(cosTheta) * 180 / .pi
}
```

### B.3.2 PoseSmoother

```swift
final class PoseSmoother {
  private var emaAngle: Double?
  private let alpha = 0.4
  
  func smooth(_ raw: Double) -> Double {
    if let prev = emaAngle {
      let smoothed = alpha * raw + (1 - alpha) * prev
      emaAngle = smoothed
      return smoothed
    } else {
      emaAngle = raw
      return raw
    }
  }
  
  func reset() { emaAngle = nil }
}
```

### B.3.3 PushupRepCounter

```swift
final class PushupRepCounter {
  enum Phase { case up, down, transitioning }
  
  private(set) var phase: Phase = .up
  private(set) var repCount: Int = 0
  private var lastTransition: Date = Date()
  
  private let downThreshold = 90.0
  private let upThreshold = 160.0
  private let minRepDuration: TimeInterval = 0.8
  
  func consume(elbowAngle: Double, leftConfidence: Double, rightConfidence: Double) -> RepEvent? {
    guard max(leftConfidence, rightConfidence) >= 0.4 else {
      return .lowConfidence
    }
    
    let now = Date()
    switch phase {
    case .up where elbowAngle <= downThreshold:
      phase = .down
      lastTransition = now
      return .phaseChanged(.down)
    case .down where elbowAngle >= upThreshold:
      // 1 rep 完了
      let duration = now.timeIntervalSince(lastTransition)
      if duration >= minRepDuration {
        repCount += 1
        phase = .up
        lastTransition = now
        return .repCompleted(count: repCount, duration: duration)
      } else {
        // 速すぎる → 破棄、ただし state はリセット
        phase = .up
        return .repRejectedTooFast
      }
    default:
      return nil
    }
  }
}
```

### B.3.4 関節欠落フォールバック

```swift
// 両側計算
let leftAngle: Double? = ...
let rightAngle: Double? = ...

let effectiveAngle: Double? = {
  switch (leftAngle, rightAngle) {
  case (let l?, let r?): return (l + r) / 2
  case (let l?, nil): return l       // 右見えない → 左のみ
  case (nil, let r?): return r       // 左見えない → 右のみ
  case (nil, nil): return nil        // どちらも見えない → 破棄
  }
}()
```

連続 30 フレーム（=1 秒 @ 30fps）両側欠落で UI に「カメラに体を映してください」hint。

## B.4 物体検出モデル 詳細

### B.4.1 NMS / IOU

CreateML Object Detector は内部で NMS を行うが、追加で：
- IOU 閾値 0.45 でデュプリケート除去
- 同クラス重複は信頼度の高い方を採用

### B.4.2 検出結果のスムージング

1 フレームのみの検出は false positive を含む。**3 フレーム連続検出** で確定とする：

```swift
struct DetectionTracker {
  private var streaks: [ObjectClass: Int] = [:]
  
  mutating func consume(detected: Set<ObjectClass>) -> Set<ObjectClass> {
    var confirmed: Set<ObjectClass> = []
    for cls in ObjectClass.allCases {
      if detected.contains(cls) {
        streaks[cls, default: 0] += 1
        if streaks[cls]! >= 3 { confirmed.insert(cls) }
      } else {
        streaks[cls] = 0
      }
    }
    return confirmed
  }
}
```

### B.4.3 訓練データ取得詳細

クラウドソース仕様書テンプレ：
- 「リモコンを 4 アングル × 3 照度条件で撮影、合計 12 枚 / 個人」
- 200 円 / 12 枚（@ ¥17/枚）想定
- 30 クラス × 400 枚 / クラス = 12,000 枚 → 約 20 万円
- アノテーション: 自前で 2 週間（または 外注 5 万円）

### B.4.4 Model A/B testing（Phase 2）

```swift
struct ModelVariant {
  let identifier: String
  let bundledFilename: String
  let trafficPercentage: Int
}

final class ModelLoader {
  func loadActiveModel() async throws -> MLModel {
    let variants: [ModelVariant] = [
      .init(identifier: "v1.0", bundledFilename: "JapaneseObjects_v1.0", trafficPercentage: 80),
      .init(identifier: "v1.1_experimental", bundledFilename: "JapaneseObjects_v1.1", trafficPercentage: 20)
    ]
    let chosen = pickByHash(userId: currentUserId, variants: variants)
    PostHog.identify(["object_model_variant": chosen.identifier])
    return try await load(filename: chosen.bundledFilename)
  }
}
```

## B.5 ミッション生成ルールエンジン

サーバ側 Edge Function の Gemini プロンプトに渡す制約：

```
ユーザー情報:
- locale: ja-JP
- 過去 30 日の難易度: medium 60%, easy 30%, hard 10%
- 過去 7 日の kind 履歴: [pushup, math, shake, pushup, math, math, objectHunt]
- 連続使用日数: 14 日
- 朝の時刻: 7:30 想定

ルール:
1. 連続して同じ kind を 3 回以上出さない
2. 14 日継続のため難易度を 1 段階上げる
3. 朝の時刻なので「準備運動」「目を覚ます」系のキャッチコピーを優先
4. アクセシビリティ設定がある場合 (vision-only / hearing-only) は Math または Shake に限定
```

Gemini からは structured output (JSON schema) で受ける：

```json
{
  "kind": "pushup",
  "difficulty": "medium",
  "parameters": {
    "reps": 8,
    "formStrictness": "moderate"
  },
  "title": "8回の腕立て伏せ",
  "description": "朝の体をすっきり目覚めさせよう",
  "estimatedDurationSec": 45,
  "encouragement": "がんばろう！"
}
```

## B.6 スコアリング / ストリーク重み付け

```swift
struct StreakWeight {
  static func value(for outcome: MissionOutcome, kind: MissionKind, durationFactor: Double) -> Double {
    guard outcome == .success else { return 0 }
    let base: Double = {
      switch kind {
      case .math, .shake: return 0.5      // 簡単
      case .objectHunt, .barcode: return 1.0  // 標準
      case .pushup, .squat: return 1.5    // 運動系
      }
    }()
    return base * durationFactor  // 0.8–1.2 の補正
  }
}

// 1 日に複数ミッション完走できる場合の cap
let dailyCap: Double = 2.0
let dailyTotal = min(dailyCap, sum(todayRuns.map(\.streakWeight)))
let streakDelta = dailyTotal >= 1.0 ? 1 : 0  // 整数増分
```

シンプルな「成功で +1 / 失敗で 0」もありだが、上記で「運動系を選ぶインセンティブ」を組み込める。Phase 1 は単純 +1、Phase 2 で導入検討。

## B.7 ミッションテンプレ version 互換

```swift
struct MissionTemplate: Codable {
  let id: UUID
  let kind: MissionKind
  let parametersVersion: Int  // 2026-06 = 1, 後方互換性のため
  let parametersJSON: String
  ...
}

func decodeParameters<T: Codable>(_ template: MissionTemplate, as: T.Type) throws -> T {
  guard template.parametersVersion == currentParametersVersion(for: template.kind) else {
    // 旧 version → migration or skip
    throw DomainError.unsupportedTemplateVersion
  }
  return try JSONDecoder().decode(T.self, from: Data(template.parametersJSON.utf8))
}
```

サーバ側 generated template が version 違いの場合はクライアントが skip し fallback template にフォールバック。

---

# Appendix C — バックエンド 深掘り

## C.1 Postgres 設計詳細

### C.1.1 接続プール

Supabase Pro はデフォルトで **Supavisor**（旧 pgbouncer 後継）が transaction mode で待受。Edge Function は serverless なので **transaction mode** 推奨（接続使い回し）。

クライアント（iOS app）からは PostgREST 経由のみ、生 SQL は使わない。

### C.1.2 インデックス戦略

```sql
-- profiles: subscription tier で頻繁にフィルタ
create index profiles_active_subscribers_idx 
  on public.profiles(subscription_tier)
  where deleted_at is null and subscription_tier != 'free';

-- alarm_runs: ユーザー別最新履歴クエリ用 covering index
create index alarm_runs_user_recent_idx 
  on public.alarm_runs(user_id, started_at desc) 
  include (outcome, mission_kind);

-- mission_generations: 期限切れ削除用
create index mission_generations_target_date_idx 
  on public.mission_generations(target_date);

-- billing_events: 未処理イベント検索
create index billing_events_unprocessed_idx
  on public.billing_events(received_at)
  where processed_at is null;
```

### C.1.3 PL/pgSQL 関数（アトミック操作）

```sql
-- ストリーク更新（race condition なし）
create or replace function public.update_streak(
  p_user_id uuid,
  p_success_date date
) returns int language plpgsql security definer as $$
declare
  v_last_success date;
  v_current_streak int;
  v_longest int;
  v_streak_start date;
begin
  select last_success_date, streak_count, longest_streak, current_streak_start_date
    into v_last_success, v_current_streak, v_longest, v_streak_start
    from public.profiles where id = p_user_id for update;

  if v_last_success = p_success_date then
    return v_current_streak;  -- 同日重複
  elsif v_last_success = p_success_date - interval '1 day' then
    v_current_streak := v_current_streak + 1;
  else
    v_current_streak := 1;
    v_streak_start := p_success_date;
  end if;
  
  v_longest := greatest(v_longest, v_current_streak);
  
  update public.profiles
    set last_success_date = p_success_date,
        streak_count = v_current_streak,
        longest_streak = v_longest,
        current_streak_start_date = v_streak_start,
        updated_at = now()
  where id = p_user_id;
  
  return v_current_streak;
end $$;
```

クライアントは PostgREST RPC 経由で呼出: `POST /rest/v1/rpc/update_streak`。

### C.1.4 期限切れデータの cleanup

```sql
-- 30 日経過した mission_generations を削除
create or replace function public.cleanup_old_generations() returns void
language plpgsql security definer as $$
begin
  delete from public.mission_generations
  where target_date < current_date - interval '30 days';
end $$;

-- pg_cron で毎日 03:00 UTC 実行
select cron.schedule('cleanup_generations', '0 3 * * *', 
  'select public.cleanup_old_generations()');
```

`pg_cron` は Supabase Pro で利用可。

### C.1.5 マイグレーション運用

```
supabase/migrations/
  20260601000000_initial_schema.sql           ← v1 全 DDL
  20260601000001_initial_rls.sql              ← RLS
  20260601000002_initial_triggers.sql         ← trigger
  20260601000003_initial_functions.sql        ← stored procedure
  20260601000004_initial_indexes.sql          ← index
  20260601000005_initial_cron.sql             ← pg_cron
  20260710000000_add_apns_token.sql           ← 機能追加例
```

各ファイル冒頭に `BEGIN;` / 末尾に `COMMIT;` でトランザクション化。失敗時は全戻し。

### C.1.6 ロールバック手順

Supabase は CLI で point-in-time recovery 可能（Pro 7 日）。手動ロールバック SQL は `supabase/migrations/down/` に対応する `*_down.sql` を用意。重大変更（dropカラム等）は必ず down を用意。

### C.1.7 VACUUM / autovacuum

Supabase はデフォルト autovacuum 設定で OK。`alarm_runs` が大量挿入・低削除になるため、analyze 頻度を上げる：

```sql
alter table public.alarm_runs set (
  autovacuum_analyze_scale_factor = 0.02,  -- 2% で analyze trigger
  autovacuum_analyze_threshold = 1000
);
```

### C.1.8 Read Replica（Phase 2）

Phase 1 は不要。MAU 10 万超 / 分析クエリ集中で Supabase Team プラン以上に upgrade。

## C.2 Edge Functions 実装詳細

### C.2.1 ディレクトリと共有モジュール

```
supabase/
  functions/
    _shared/
      auth.ts              // JWT 検証ヘルパ
      rate_limit.ts        // sliding window
      errors.ts
      cors.ts
      logger.ts
    missions-generate/
      index.ts
      gemini.ts
      prompt.ts
      schema.ts            // structured output schema
```

### C.2.2 共通 auth 検証

```typescript
// _shared/auth.ts
import { createClient } from "@supabase/supabase-js";

export async function getUser(req: Request): Promise<User> {
  const auth = req.headers.get("Authorization");
  if (!auth) throw new HttpError(401, "missing token");
  const token = auth.replace("Bearer ", "");
  
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { global: { headers: { Authorization: auth } } }
  );
  
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "invalid token");
  return data.user;
}
```

### C.2.3 Rate Limit（sliding window）

```typescript
// _shared/rate_limit.ts
export async function consume(
  supabase: SupabaseClient,
  userId: string,
  bucket: string,
  windowSec: number,
  maxCount: number
): Promise<{ allowed: boolean; remaining: number }> {
  const windowStart = new Date(Math.floor(Date.now() / 1000 / windowSec) * windowSec * 1000);
  
  const { data, error } = await supabase.rpc("rate_limit_consume", {
    p_user_id: userId,
    p_bucket: bucket,
    p_window_start: windowStart.toISOString(),
    p_max_count: maxCount
  });
  
  if (error) throw new HttpError(500, "rate limit error");
  return { allowed: data.allowed, remaining: data.remaining };
}
```

```sql
create or replace function public.rate_limit_consume(
  p_user_id uuid,
  p_bucket text,
  p_window_start timestamptz,
  p_max_count int
) returns table(allowed boolean, remaining int)
language plpgsql security definer as $$
declare v_count int;
begin
  insert into public.rate_limits (user_id, bucket, window_start, count)
  values (p_user_id, p_bucket, p_window_start, 1)
  on conflict (user_id, bucket, window_start) 
  do update set count = rate_limits.count + 1
  returning count into v_count;
  
  return query select v_count <= p_max_count, greatest(0, p_max_count - v_count);
end $$;
```

### C.2.4 missions-generate 完全実装

```typescript
// missions-generate/index.ts
import { getUser } from "../_shared/auth.ts";
import { consume } from "../_shared/rate_limit.ts";
import { generateMission } from "./gemini.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  
  try {
    const user = await getUser(req);
    const body = await req.json();
    const { targetDate, difficultyHint, history, localeOverride } = body;
    
    // バリデーション
    if (!targetDate || !difficultyHint) {
      return Response.json({ error: "missing fields" }, { status: 400 });
    }
    
    // レート制限 (5/day)
    const supabase = createServiceClient();
    const { allowed, remaining } = await consume(supabase, user.id, "mission_generate", 86400, 5);
    if (!allowed) return Response.json({ error: "rate limited", remaining }, { status: 429 });
    
    // キャッシュチェック
    const { data: cached } = await supabase
      .from("mission_generations")
      .select("template")
      .eq("user_id", user.id)
      .eq("target_date", targetDate)
      .eq("difficulty_hint", difficultyHint)
      .maybeSingle();
    
    if (cached) {
      return Response.json({ template: cached.template, ttlSec: 86400, cached: true });
    }
    
    // Gemini 生成
    const locale = localeOverride ?? "ja-JP";
    const template = await generateMission({ history, difficultyHint, locale });
    
    // 永続化
    await supabase.from("mission_generations").insert({
      user_id: user.id,
      target_date: targetDate,
      difficulty_hint: difficultyHint,
      template
    });
    
    return Response.json({ template, ttlSec: 86400, cached: false });
  } catch (err) {
    if (err instanceof HttpError) return Response.json({ error: err.message }, { status: err.status });
    console.error(err);
    return Response.json({ error: "internal" }, { status: 500 });
  }
});
```

### C.2.5 Gemini API 呼出（structured output）

```typescript
// missions-generate/gemini.ts
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai@latest";

const MISSION_SCHEMA = {
  type: "object",
  properties: {
    kind: { type: "string", enum: ["pushup", "squat", "math", "shake", "objectHunt", "barcode"] },
    difficulty: { type: "string", enum: ["easy", "medium", "hard"] },
    parameters: { type: "object" },
    title: { type: "string" },
    description: { type: "string" },
    estimatedDurationSec: { type: "integer", minimum: 10, maximum: 300 }
  },
  required: ["kind", "difficulty", "parameters", "title", "description", "estimatedDurationSec"]
};

export async function generateMission(input: {
  history: string[], difficultyHint: string, locale: string
}): Promise<MissionTemplate> {
  const genAI = new GoogleGenerativeAI(Deno.env.get("GEMINI_API_KEY")!);
  const model = genAI.getGenerativeModel({
    model: "gemini-2.5-flash",
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: MISSION_SCHEMA,
      temperature: 0.7,
      maxOutputTokens: 512
    }
  });
  
  const prompt = buildPrompt(input);  // §B.5 のプロンプトテンプレ
  const result = await model.generateContent(prompt);
  return JSON.parse(result.response.text());
}
```

### C.2.6 billing-webhook 実装（HMAC 検証）

```typescript
// billing-webhook/index.ts
import { createHmac } from "node:crypto";

Deno.serve(async (req) => {
  const signature = req.headers.get("X-RevenueCat-Signature");
  if (!signature) return new Response("no signature", { status: 401 });
  
  const body = await req.text();
  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")!;
  const expected = createHmac("sha256", secret).update(body).digest("hex");
  
  if (!timingSafeEqual(signature, expected)) {
    return new Response("invalid signature", { status: 401 });
  }
  
  const event = JSON.parse(body);
  const supabase = createServiceClient();
  
  // 冪等性: event.id がユニーク
  await supabase.from("billing_events").insert({
    rc_event_id: event.event.id,
    rc_app_user_id: event.event.app_user_id,
    event_type: event.event.type,
    product_id: event.event.product_id,
    raw_payload: event
  }).onConflict("rc_event_id").ignore();
  
  // tier 更新
  const tier = mapToTier(event.event.type, event.event.product_id);
  const expiresAt = event.event.expiration_at_ms 
    ? new Date(event.event.expiration_at_ms).toISOString() 
    : null;
  
  await supabase.from("profiles").update({
    subscription_tier: tier,
    subscription_expires_at: expiresAt
  }).eq("id", event.event.app_user_id);
  
  await supabase.from("billing_events")
    .update({ processed_at: new Date().toISOString() })
    .eq("rc_event_id", event.event.id);
  
  return new Response("ok");
});

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}
```

### C.2.7 account-delete 実装

```typescript
// account-delete/index.ts
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  
  const user = await getUser(req);
  const supabase = createServiceClient();
  
  // 1. ソフト削除マーク
  await supabase.from("profiles")
    .update({ deleted_at: new Date().toISOString() })
    .eq("id", user.id);
  
  // 2. Apple SiwA revoke
  try {
    await revokeAppleToken(user);
  } catch (e) {
    console.error("apple revoke failed:", e);
    // 続行
  }
  
  // 3. auth.users 削除（cascade）
  await supabase.auth.admin.deleteUser(user.id);
  
  return new Response(null, { status: 204 });
});

async function revokeAppleToken(user: User) {
  // user.user_metadata から refresh_token を取り出し
  const refreshToken = user.user_metadata?.apple_refresh_token;
  if (!refreshToken) return;
  
  // client_secret JWT 生成 (ES256, Apple Developer Key)
  const clientSecret = await buildAppleClientSecretJWT();
  
  await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: Deno.env.get("APPLE_CLIENT_ID")!,
      client_secret: clientSecret,
      token: refreshToken,
      token_type_hint: "refresh_token"
    })
  });
}
```

### C.2.8 push-send (内部 RPC)

```typescript
// push-send/index.ts
import jwt from "https://esm.sh/jsonwebtoken@9";

Deno.serve(async (req) => {
  // service_role token のみ許可
  const auth = req.headers.get("Authorization");
  if (auth !== `Bearer ${Deno.env.get("INTERNAL_RPC_KEY")}`) {
    return new Response("forbidden", { status: 403 });
  }
  
  const { userId, category, title, body, data, interruptionLevel } = await req.json();
  
  const supabase = createServiceClient();
  const { data: profile } = await supabase
    .from("profiles")
    .select("apns_token, apns_env")
    .eq("id", userId)
    .single();
  
  if (!profile?.apns_token) return Response.json({ error: "no token" }, { status: 404 });
  
  // APNs JWT (ES256, p8 key)
  const apnsToken = jwt.sign(
    { iss: Deno.env.get("APNS_TEAM_ID"), iat: Math.floor(Date.now() / 1000) },
    Deno.env.get("APNS_KEY_P8"),
    { algorithm: "ES256", header: { alg: "ES256", kid: Deno.env.get("APNS_KEY_ID") } }
  );
  
  const apnsUrl = profile.apns_env === "sandbox"
    ? `https://api.sandbox.push.apple.com/3/device/${profile.apns_token}`
    : `https://api.push.apple.com/3/device/${profile.apns_token}`;
  
  await fetch(apnsUrl, {
    method: "POST",
    headers: {
      "authorization": `bearer ${apnsToken}`,
      "apns-topic": Deno.env.get("APP_BUNDLE_ID")!,
      "apns-push-type": "alert",
      "apns-priority": interruptionLevel === "timeSensitive" ? "10" : "5"
    },
    body: JSON.stringify({
      aps: {
        alert: { title, body },
        category,
        "interruption-level": interruptionLevel ?? "active",
        sound: "default"
      },
      ...data
    })
  });
  
  return Response.json({ ok: true });
});
```

## C.3 Secret 管理運用

| 環境 | 場所 | 設定方法 |
|---|---|---|
| iOS (Production) | xcconfig + Xcode Cloud secret | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_API_KEY`, `POSTHOG_API_KEY`, `SENTRY_DSN` |
| iOS (Debug) | xcconfig + local `.env.development` (gitignore) | dev project の値 |
| Supabase Edge | Supabase Dashboard > Edge Functions > Secrets | `GEMINI_API_KEY`, `REVENUECAT_WEBHOOK_SECRET`, `APNS_*`, `APPLE_*` |
| Supabase DB | Postgres role / 環境変数 | 不要（Supabase が管理） |

### Secret rotation

| Secret | rotate 頻度 | 手順 |
|---|---|---|
| Gemini API Key | 6 ヶ月 | Google AI Studio で新キー生成 → Supabase Dashboard 反映 → 旧キー削除 |
| RC Webhook Secret | 1 年 | RC Dashboard で再生成 → Supabase 反映 |
| APNs Key | 不要（失効なし） | 鍵紛失時のみ再発行 |
| Sentry DSN | rotate 不要 | アプリ別 DSN |

## C.4 監視・アラート

- **Supabase Dashboard**: DB CPU > 70% でメール
- **PostHog**: dashboards に DAU / MAU / churn / 課金転換率 / ミッション完走率
- **Sentry**: alert rule = crash-free user < 99% でメール
- **Edge Function logs**: Supabase Dashboard で stdout 確認、エラー率を週次集計

---

# Appendix D — 法務・規制 深掘り

## D.1 個人情報保護法 (APPI) 対応

### D.1.1 利用目的の特定

プライバシーポリシーに以下を明記：

```
取得する個人情報:
1. Apple ID（Sign in with Apple）
2. メールアドレス（Apple Relay 含む）
3. 表示名（任意）
4. アラーム履歴・ミッション結果
5. 端末識別子（APNs token、Supabase user id ハッシュ）
6. 課金履歴（App Store 経由）
7. クラッシュ情報・利用解析データ

利用目的:
1. 本サービスの提供（認証、データ同期、課金処理）
2. お客様サポートへの対応
3. サービス改善のための分析
4. 不正利用の検知
5. アップデートのお知らせ
6. 法令遵守
```

### D.1.2 第三者提供

| 提供先 | 提供データ | 提供方法 | 国名 |
|---|---|---|---|
| Supabase Inc. | 全データ | API（暗号化）| 米国（Singapore region 選択可） |
| RevenueCat Inc. | ユーザー識別子、課金情報 | API | 米国 |
| Apple Inc. | 課金情報 | App Store | 米国 |
| Google LLC (Gemini) | ミッション履歴（匿名化）、locale | API | 米国 |
| ElevenLabs Inc. | 該当なし（事前生成のみ） | — | 米国 |
| PostHog Inc. | イベントログ（ハッシュ ID） | API | 米国（EU region 選択可） |
| Sentry (Functional Software Inc.) | クラッシュ情報 | API | 米国 |

**外国にある第三者への提供** は APPI 28 条で本人同意必須。プラポリで明示＋ Sign in with Apple 完了後に同意ダイアログ。

### D.1.3 開示・訂正・削除請求

問合せ窓口: `privacy@oki-mission.app`

請求受付から **2 週間以内** に対応。アカウント削除は §15.6 のフローで完結（30 日内に物理削除完了）。

### D.1.4 漏洩時報告義務

APPI 26 条で 個人情報保護委員会への報告 + 本人通知が必要なケース：
- 要配慮個人情報を含む（OkiMission は該当しない）
- 不正に利用される恐れ
- 1,000 人を超える漏洩

報告期限: **発生または認知から 3–5 日（速報）、30 日（確報）**。手順を Runbook 化。

## D.2 GDPR 対応（EU 展開時 Phase 2）

Phase 1 は日本＋英語圏（米・豪・NZ）のみ。EU 展開は Phase 2 で：
- DPA（Data Processing Agreement）を Supabase / RC / PostHog 等と締結（各社雛形あり）
- データ主体の権利（access / rectification / erasure / portability / restriction / objection）対応 UI
- 同意撤回機能
- DPO（Data Protection Officer）任命は規模次第（個人開発レベルでは通常不要）

## D.3 児童保護

### D.3.1 年齢確認

Sign in with Apple 完了後、初回起動時に **年齢確認ダイアログ**：

```
■ 年齢確認
ご利用には満 13 歳以上である必要があります。
未成年（18 歳未満）の方は保護者の同意を得てください。

[ 13 歳以上で、保護者の同意がある（または成人）] [ 13 歳未満 ]
```

13 歳未満選択でアカウント削除＋オンボーディング不可。これは App Store Connect の **App Rating** で「4+」を維持しつつ、内規上 13 歳未満を弾く方針。

### D.3.2 App Store Connect 申告

- Age Rating: 4+（暴力なし、性的描写なし、ギャンブルなし）
- Made for Kids: 該当しない（KidsCategory 入れない）
- Family Sharing: 有効

### D.3.3 未成年者の契約取消

民法 5 条で 18 歳未満の単独サブスク契約は法定代理人取消可能。**返金請求があった場合は Apple 経由で対応**（個人事業者では直接返金できない、App Store の refund policy に委ねる）。

利用規約に下記を明記：

```
未成年者の利用について
1. 18 歳未満の方は法定代理人の同意の上でご利用ください
2. 同意なしで購入された場合、法定代理人は契約の取消を求めることができます
3. その際、App Store の返金フローをご案内いたします
```

## D.4 利用規約 必須条項

KIYAC で生成、以下を含めること：

1. 適用範囲
2. サービス内容
3. 利用登録
4. アカウント管理
5. 禁止事項（リバースエンジニアリング、不正利用、自動化ツール、第三者への譲渡）
6. 知的財産権
7. 個人情報の取扱い（プラポリへの参照）
8. **免責事項**（アラーム不発火による損害の限定責任）
9. **損害賠償の上限**（過去 12 ヶ月の支払額を上限）
10. サービスの変更・終了
11. **反社会的勢力排除**
12. **準拠法・管轄裁判所**（日本法、東京地方裁判所）
13. **規約の変更**（重要な変更時の事前通知）

### D.4.1 アラーム不発火の免責文言（重要）

```
本アプリのアラーム機能は iOS 標準の AlarmKit を利用しております。
OS の不具合、端末の故障、設定の不備、その他当社の責によらない事由により
アラームが発火しない場合があります。重要な予定には複数のアラームをご利用
いただくか、他の手段との併用を推奨いたします。

アラーム不発火による損害について、当社は一切の責任を負いません。
```

これは AlarmKit を使用していても、ユーザーが「重要な医療目的（透析等）」「重要な業務」で使った場合の損害訴訟リスクを下げる。

## D.5 Apple App Store Review Guideline チェック

| Guideline | 内容 | OkiMission 対応 |
|---|---|---|
| 1.1 | 安全性 | ミッションで運動を強要しない、ユーザーは中断可 |
| 2.1 | アプリの完成度 | β テスト後にリリース |
| 2.5.4 | バックグラウンド | AlarmKit 使用で 2.5.4 リジェクト回避（§設計 §1） |
| 3.1.1 | App 内課金 | RC 経由で StoreKit、外部リンクは Phase 2 まで使わない |
| 3.1.2(a) | サブスク開示 | 特商法シートで分量・金額・期間明示 |
| 4.0 | 設計 | iOS HIG 準拠、Liquid Glass 採用 |
| 4.8 | Sign in with Apple | SiwA を唯一の認証手段として実装 |
| 5.1.1(v) | アカウント削除 | §15.6 / §19.3 |
| 5.1.2 | データ最小限 | Privacy Manifest §18 |
| 5.6 | 開発者識別 | App Store Connect で本名（個人事業）または法人名 |

## D.6 Privacy Nutrition Labels（App Store Connect 入力項目）

| カテゴリ | 収集データ | リンク | 用途 |
|---|---|---|---|
| Contact Info | Email | ✓ | App Functionality |
| Identifiers | User ID | ✓ | App Functionality, Analytics |
| Purchases | Purchase History | ✓ | App Functionality |
| Usage Data | Product Interaction | ✓ | App Functionality, Analytics |
| Diagnostics | Crash Data, Performance Data | ✗ | App Functionality |

「Tracking」カテゴリは全て「No」。

## D.7 特商法 表記の表示場所最終整理

| 場所 | 形式 | 必須項目 |
|---|---|---|
| LP `https://oki-mission.app/legal/tokushoho` | KIYAC 生成 HTML | §17.1 全項目 |
| App 内 Settings > 特商法 | SwiftUI native | 同上 |
| 購入直前 TokushohoSheet | SwiftUI sheet | §17.4 抜粋 + 全文展開可 |
| App Store Description | Apple 標準のサブスク開示 | Apple がフォーマット指定 |

## D.8 法人化判断マトリクス

| 月商 | 形態 | 税理士 | 推定費用/月 |
|---|---|---|---|
| 〜30 万円 | 個人事業 | 不要 | 0 円 |
| 30–100 万円 | 個人事業 + 青色申告 | 月次 5 万円 | 5 万円 |
| 100–300 万円 | 個人事業 + 経費最大化 | 月次 5 万円 | 5 万円 |
| 300 万円〜 | 法人化検討 | 顧問契約 | 8–10 万円 |
| 500 万円〜 | 法人化推奨 | 顧問契約 | 10–15 万円 |

法人化メリット: 消費税課税事業者切替、社保加入、与信向上、節税（役員報酬・退職金）。
法人化デメリット: 登記費用（合同 7 万円・株式 25 万円）、毎年の決算・税務、社保負担。

---

# Appendix E — StoreKit / RevenueCat 深掘り

## E.1 製品設計マトリクス

### E.1.1 価格戦略

国別価格（App Store Connect の Price Matrix 経由で自動換算、ベースは JP）：

| 商品 | 日本 (JPY) | 米国 (USD 換算) | 韓国 (KRW 換算) |
|---|---|---|---|
| Pro Monthly | ¥600 | $4.99 (Tier 5) | ₩5,500 |
| Pro Annual | ¥4,800 | $39.99 (Tier 40) | ₩45,000 |
| Pro Lifetime (Phase 2) | ¥12,800 | $99.99 | ₩115,000 |

Wayk と比較してやや低価格設定（Wayk Yearly $19.99-$39.99）。OkiMission は新規参入なので価格訴求＋ローカライズ訴求の二刀流。

### E.1.2 Subscription Group 設計

```
SubscriptionGroup: "OkiMission Pro" (group_id auto)
  ├ Pro Monthly (Level 1)
  └ Pro Annual (Level 1)   ← 同 level でクロスグレード可
```

両方を同 group の同 level に設定 → ユーザーが Monthly → Annual に切替時に **prorated** で即時アップグレード。

### E.1.3 Introductory Offer

```
Pro Monthly:
  - Free Trial 3 days (新規ユーザーのみ、subscription group 内 1 回限り)
Pro Annual:
  - Free Trial 7 days
```

両方を有効化することで、ユーザーは Monthly 試用後 Annual に乗り換えても Annual の trial を再度得られない（Apple ルール）。
Annual だけ 7 日 trial にすることで Annual 訴求を強化。

### E.1.4 Promotional Offer（Phase 2）

```
WinBack 1 month:
  - 失効後 30 日以内のユーザー対象
  - Pro Monthly 50% OFF（¥300）× 3 ヶ月
```

実装: RC で promotional offer 設定 → アプリ内で `Purchases.shared.getPromotionalOffer(forProductDiscount:product:)` で signature 取得 → `Purchases.shared.purchase(package:promotionalOffer:)` で適用。

## E.2 RevenueCat 構成

### E.2.1 Project / Apps / Offerings

```
RC Project: OkiMission
  └ App: iOS App Store
        ├ Entitlement: pro
        ├ Product: com.example.okimission.pro.monthly → Entitlement [pro]
        ├ Product: com.example.okimission.pro.yearly  → Entitlement [pro]
        └ Offering: default
              ├ Package: monthly  → product .monthly
              └ Package: annual   → product .yearly
              └ Metadata: { layout: "annual_emphasis", ja_headline: "...", en_headline: "..." }
```

### E.2.2 Paywall A/B 設計

RevenueCat Experiments で：

```
Experiment 1: Paywall Layout
  - Variant A: Annual emphasis (default)
  - Variant B: Trial emphasis ("3 日間無料で試す")
  - Variant C: Streak emphasis ("7 日続けたい？")
  - Variant D: Mission emphasis ("AI ミッションを試そう")
  
  各 25% 配分、最低 4 週間、conversion rate 比較
```

A/B test の identification は RC App User ID = Supabase user id ベース。

### E.2.3 EntitlementStore 実装

```swift
@MainActor @Observable
final class EntitlementStore {
  enum Tier: Equatable { case free, pro(expiresAt: Date?) }
  
  private(set) var tier: Tier = .free
  private(set) var isLoading: Bool = true
  private(set) var error: Error?
  private var customerInfoTask: Task<Void, Never>?
  
  func bootstrap() async {
    do {
      let info = try await Purchases.shared.customerInfo()
      update(from: info)
    } catch {
      // SubscriptionCacheSnapshot にフォールバック
      await loadFromCache()
      self.error = error
    }
    isLoading = false
    
    customerInfoTask = Task { [weak self] in
      for await info in Purchases.shared.customerInfoStream {
        await self?.update(from: info)
      }
    }
  }
  
  private func update(from info: CustomerInfo) {
    let entitlement = info.entitlements["pro"]
    if entitlement?.isActive == true {
      tier = .pro(expiresAt: entitlement?.expirationDate)
    } else {
      tier = .free
    }
    Task { await persistToCache() }
  }
  
  private func persistToCache() async {
    // SubscriptionCacheSnapshot 更新
  }
}
```

### E.2.4 Restore

```swift
@MainActor
func restorePurchases() async {
  do {
    let info = try await Purchases.shared.restorePurchases()
    if info.entitlements["pro"]?.isActive == true {
      showToast("Pro エンタイトルメントを復元しました")
    } else {
      showToast("購入が見つかりませんでした")
    }
  } catch {
    showError(error)
  }
}
```

### E.2.5 Product 取得（Paywall 表示時）

```swift
func loadOffering() async throws -> Offering {
  let offerings = try await Purchases.shared.offerings()
  guard let current = offerings.current else {
    throw DomainError.noOfferingsAvailable
  }
  return current
}
```

### E.2.6 購入実行

```swift
@MainActor
func purchase(package: Package) async {
  // 1. 特商法シート提示
  let confirmed = await TokushohoGate.confirm(package: package)
  guard confirmed else {
    Analytics.track(.tokushoho_cancelled)
    return
  }
  
  // 2. 購入
  do {
    let result = try await Purchases.shared.purchase(package: package)
    if result.userCancelled {
      Analytics.track(.purchase_user_cancelled)
      return
    }
    Analytics.track(.purchase_succeeded, properties: [
      "product_id": package.storeProduct.productIdentifier,
      "period": result.transaction?.subscriptionPeriod?.localizedDescription
    ])
  } catch {
    Analytics.track(.purchase_failed, properties: ["error": error.localizedDescription])
    showError(error)
  }
}
```

### E.2.7 Family Sharing

App Store Connect で **Family Sharing を有効化**。RC 側は自動対応（`CustomerInfo.entitlements` で `isActive` が family member でも true）。

注意点:
- Family organizer の transaction が family member に共有される
- 解約は organizer のみ可能
- アプリ側で「Family 共有による Pro」を明示する UI

```swift
if let info = customerInfo, info.entitlements["pro"]?.ownershipType == .familyShared {
  // "ご家族の共有によりご利用中" バッジ
}
```

## E.3 Sandbox テスト戦略

### E.3.1 Sandbox Tester アカウント

App Store Connect で 5–10 個の Sandbox Tester を作成（複数 region：US, JP, KR）。

各 tester で：
- 新規購入フロー
- Trial 開始 → 自動更新 → 解約
- Restore
- Family Sharing（要 organizer + member 2 アカウント）
- Promotional Offer（Phase 2）

Sandbox では時間が圧縮（Annual subscription = 1 時間）、自動更新 6 回でキャンセル扱い。

### E.3.2 StoreKit Configuration File

Debug ビルドで `OkiMission.storekit` ファイルを使用、ローカル模擬。CI でも実行可能。

```
OkiMission.storekit:
  - Subscriptions
    - Pro Monthly (¥600)
    - Pro Annual (¥4,800)
  - Introductory Offers
    - Free Trial 3 days for Monthly
    - Free Trial 7 days for Annual
```

### E.3.3 CI での StoreKitTest

```swift
import StoreKitTest

final class SubscriptionTests: XCTestCase {
  var session: SKTestSession!
  
  override func setUp() async throws {
    session = try SKTestSession(configurationFileNamed: "OkiMission")
    session.disableDialogs = true
    session.clearTransactions()
  }
  
  func testPurchaseMonthlySuccess() async throws {
    let result = try await Purchases.shared.purchase(/* package */)
    XCTAssertFalse(result.userCancelled)
    XCTAssertEqual(result.entitlements["pro"]?.isActive, true)
  }
  
  func testFreeTrialExpiration() async throws {
    // ...
    session.timeRate = .oneSecondIsOneDay
    // 4 秒待機 = 4 日経過 = trial 終了
    try await Task.sleep(for: .seconds(4))
    let info = try await Purchases.shared.customerInfo()
    XCTAssertEqual(info.entitlements["pro"]?.willRenew, true)  // 課金開始
  }
}
```

## E.4 Receipt 検証層

### E.4.1 RevenueCat による検証

RC は自動で：
- StoreKit JWS verification
- Apple App Store Server API 経由の最新状態確認
- Webhook での tier 反映

### E.4.2 二重検証（多層防御）

Phase 2 で Apple App Store Server Notifications V2 を追加 Edge Function `/billing/apple-notifications` で受信、RC webhook と一致確認。差分があれば Sentry 警告。

## E.5 サブスク状態遷移マトリクス

| 状態 | 詳細 | UI |
|---|---|---|
| 未購入 (free) | 一度も購入なし | Paywall 表示可 |
| Trial 中 | 課金前無料期間 | Pro 機能利用可、終了予定日表示 |
| Active (Pro) | 課金中、自動更新有効 | Pro 機能、解約案内 |
| Cancelled (期限内) | 解約済、期限まで利用可 | Pro 機能、再加入案内 |
| Expired | 期限切れ | Pro 機能停止、Paywall 表示 |
| Grace Period (Apple) | 課金失敗だが Apple が 16 日猶予 | Pro 機能継続、「お支払い情報を更新」案内 |
| Billing Issue | Grace Period 超過 | Pro 機能停止、緊急 Paywall |
| Refunded | 払い戻し済 | Pro 機能停止 |

各状態を `CustomerInfo.entitlements["pro"]` の properties で判定：
- `isActive`
- `willRenew`
- `periodType` (.normal / .intro / .trial)
- `expirationDate`
- `unsubscribeDetectedAt`
- `billingIssueDetectedAt`

## E.6 Free Trial の eligibility 確認

```swift
let offerings = try await Purchases.shared.offerings()
let isEligible = try await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: [
  "com.example.okimission.pro.monthly"
])

if isEligible["com.example.okimission.pro.monthly"]?.status == .eligible {
  // "3 日間無料で試す" ボタン表示
} else {
  // "¥600 / 月" 通常表示
}
```

---

# Appendix F — CI/CD・運用・性能予算 深掘り

## F.1 Xcode Cloud Workflow 仕様

### F.1.1 Workflow 一覧

```
1. PR Check
   Trigger: PR opened/updated on any branch
   Steps:
     - Build (Debug)
     - Unit Test
     - UI Test (smoke)
     - SwiftLint
     - Snapshot Test
   Notification: GitHub PR check status

2. Beta Build  
   Trigger: push to claude/*
   Steps:
     - Build (Beta)
     - Unit Test (full)
     - UI Test (full)
     - dSYM upload to Sentry
     - TestFlight internal upload
     - Sentry release marker
   Notification: Slack #beta-builds (or email)

3. Release Build
   Trigger: tag v*.*.*
   Steps:
     - Build (Release)
     - Unit Test (full)
     - dSYM upload
     - App Store Connect upload
     - Sentry release finalize
     - Git tag protection check
   Notification: 同上

4. Nightly Performance
   Trigger: schedule 03:00 JST daily
   Steps:
     - Performance Test (XCTest perf)
     - Memory leak detection
     - PostHog upload
   Notification: alert on regression
```

### F.1.2 ci_post_clone.sh

```bash
#!/bin/zsh
set -e

# secrets 復元
echo "POSTHOG_API_KEY=$POSTHOG_API_KEY" > Config/Secrets.xcconfig
echo "SENTRY_DSN=$SENTRY_DSN" >> Config/Secrets.xcconfig
echo "SUPABASE_URL=$SUPABASE_URL" >> Config/Secrets.xcconfig
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> Config/Secrets.xcconfig
echo "REVENUECAT_API_KEY=$REVENUECAT_API_KEY" >> Config/Secrets.xcconfig

# SwiftLint
brew install swiftlint || true

# Sentry CLI
curl -sL https://sentry.io/get-cli/ | bash || true
```

### F.1.3 ci_post_xcodebuild.sh

```bash
#!/bin/zsh
set -e

if [[ "$CI_XCODEBUILD_ACTION" == "archive" && "$CI_WORKFLOW" != "PR Check" ]]; then
  # dSYM upload
  sentry-cli upload-dif \
    --auth-token "$SENTRY_AUTH_TOKEN" \
    --org "$SENTRY_ORG" \
    --project "$SENTRY_PROJECT" \
    "$CI_ARCHIVE_PATH/dSYMs"
  
  # Release marker
  VERSION=$(defaults read "$CI_ARCHIVE_PATH/Info" CFBundleShortVersionString)
  BUILD=$(defaults read "$CI_ARCHIVE_PATH/Info" CFBundleVersion)
  sentry-cli releases new "okimission@$VERSION+$BUILD" || true
  sentry-cli releases finalize "okimission@$VERSION+$BUILD" || true
fi
```

## F.2 コード署名

- Automatic signing 採用（個人開発）
- Capabilities 変更時に Apple Developer Portal で自動同期
- Manual signing 必要なケース: Critical Alerts entitlement のような承認制機能

### Distribution Certificate

- 1 個のみ（Apple Distribution）
- Xcode Cloud が自動管理（Account Holder の Apple ID をリンク）

## F.3 バージョン管理

```
MARKETING_VERSION (CFBundleShortVersionString):
  semantic versioning  v1.2.3
  v1.0.0 = launch
  v1.x.0 = feature
  v1.x.y = bugfix
  v2.0.0 = major redesign / SwiftData v2 移行

CURRENT_PROJECT_VERSION (CFBundleVersion):
  自動 increment (Xcode Cloud の $CI_BUILD_NUMBER 連動)
  monotonic 整数
```

`agvtool` で自動化（Xcode Cloud post-script）。

## F.4 Snapshot Test 戦略

```swift
// AlarmListViewSnapshotTests.swift
final class AlarmListViewSnapshotTests: XCTestCase {
  func testAlarmList_default() {
    let store = MockAlarmStore.withSampleData
    let view = AlarmListView()
      .environment(store)
      .modelContainer(previewContainer(seed: .sample))
    
    assertSnapshot(of: view, as: .image(on: .iPhone15), record: false)
    assertSnapshot(of: view, as: .image(on: .iPhoneSE3rd), record: false)
    assertSnapshot(of: view, as: .image(on: .iPhone15, traits: .init(userInterfaceStyle: .dark)))
    assertSnapshot(of: view, as: .image(on: .iPhone15, traits: .init(preferredContentSizeCategory: .accessibilityExtraExtraLarge)))
  }
  
  func testAlarmList_empty() { /* ... */ }
  func testAlarmList_loading() { /* ... */ }
  func testAlarmList_error() { /* ... */ }
}
```

主要 View 10–15 種を snapshot test。CI で diff 検出時 PR コメントに画像添付（GitHub Actions では artifact 経由）。

## F.5 Performance Test

```swift
final class AlarmServicePerfTests: XCTestCase {
  func testScheduleAlarm_1000times() throws {
    let service = AlarmService(manager: MockAlarmManager())
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
      let exp = expectation(description: "complete")
      Task {
        for i in 0..<1000 {
          _ = try? await service.schedule(/* sample alarm */)
        }
        exp.fulfill()
      }
      wait(for: [exp], timeout: 30)
    }
  }
}

final class ColdStartTests: XCTestCase {
  func testColdStartTime() {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }
}
```

baseline は CI 上の median を 1 週間収集後 fix、その後 +20% で回帰扱い。

## F.6 メモリリーク検出

XCTest の **MetricKit** + `XCTMemoryMetric` で main 起動〜終了のメモリ delta。
Instruments の Leaks template を Nightly で実行する CI もあるが、Xcode Cloud では困難なので Phase 2 で別途。

## F.7 ローカリゼーション運用

### F.7.1 String Catalog 編集ワークフロー

1. JA 文言をコード内 `LocalizedStringResource` で記述
2. Xcode で String Catalog ファイル開く → JA 自動抽出
3. EN 列を手動翻訳（または ChatGPT 経由）
4. リリース前に `xcrun --sdk iphoneos genstrings` で漏れ検出

### F.7.2 機械翻訳サポート

開発初期は ChatGPT / Gemini で初訳 → ネイティブチェック（Phase 2 で proofreader 契約）。

## F.8 Asset 最適化

### F.8.1 画像

- App Icon 1024×1024、Assets.xcassets に格納
- 全画像 PNG/HEIC、必要時 SVG (PDF) → Xcode が自動 vectorize
- Optimization: Asset Catalog 経由で App Slicing 適用

### F.8.2 サウンド

- ElevenLabs 出力 mp3 → afconvert で CAF（Linear PCM）変換
- 1 ファイル 100–300 KB 想定、20 種 = 4–6 MB
- バンドル時に compress 不要（OS が再生時に最適化）

### F.8.3 Core ML モデル

- CreateML で `.mlmodel` 出力 → Xcode ビルド時に `.mlmodelc` に自動コンパイル
- iPhone 11 では FP16 推論で十分（FP32 不要）
- 量子化 (int8) は精度落ちすぎる場合があるので Phase 2 検証

## F.9 性能予算 詳細（再掲＋拡張）

| 指標 | 目標 (iPhone 11) | 計測手法 | 違反時の対応 |
|---|---|---|---|
| Cold start | ≤ 2.0 s | `XCTApplicationLaunchMetric` | bootstrap 順序見直し、defer 化 |
| Warm start | ≤ 0.8 s | 同上 | — |
| AlarmList 表示 | ≤ 100 ms | XCTest + ViewModel benchmark | SwiftData fetch optimize |
| AlarmList scroll | ≥ 55 fps | Instruments Time Profiler | LazyVStack / id stability |
| AlarmService.schedule | ≤ 200 ms | XCTClockMetric | AlarmKit 自体は高速、SwiftData 書込みが重い場合 background context |
| Mission 起動 (button tap → camera ready) | ≤ 800 ms | UI test 計測 | AVCaptureSession warm-up を事前実行 |
| ObjectHunt 推論/frame | ≤ 80 ms | Vision profiler | 入力 416→320 へ縮小 |
| Pose 推論/frame | ≤ 35 ms | 同上 | (既に高速、余裕) |
| Mission 1 分の電池消費 | ≤ 1.5% | Xcode Energy Log | カメラ FPS 低減、推論 throttle |
| Mission 中 Peak Memory | ≤ 180 MB | Instruments Allocations | バッファ削減、モデルキャッシュ削除 |
| App Bundle | ≤ 80 MB | `du -sh OkiMission.app` | モデル ODR 化検討 |
| Network requests on launch | ≤ 3 | 計装ログ | 起動と並列して non-blocking で |
| Crash-free user | ≥ 99.5% | Sentry | クラッシュ修正 |
| ANR rate | ≤ 0.5% | Sentry / PostHog | スレッド競合修正 |

## F.10 リリース・運用 Runbook

### F.10.1 リリースチェックリスト

```
[ ] バージョン番号更新（MARKETING_VERSION）
[ ] CHANGELOG 更新（リリースノート）
[ ] String Catalog の JA/EN 完備
[ ] Privacy Manifest 更新
[ ] App Store Connect:
    [ ] バージョン情報
    [ ] スクリーンショット (6.7", 6.1", iPad)
    [ ] App Preview ビデオ (任意)
    [ ] Description JA + EN
    [ ] Keywords JA + EN
    [ ] What's New JA + EN
    [ ] Age Rating 再確認
    [ ] Privacy Nutrition Labels 確認
[ ] サブスク商品の説明・スクリーンショット
[ ] In-App Purchase の Review Notes
[ ] 審査用ログイン情報（Sandbox tester）
[ ] Demo Video URL (mission の説明)
[ ] Git tag (vX.Y.Z)
[ ] CI/CD で Release Build 起動
```

### F.10.2 緊急 hotfix Runbook

```
1. main から hotfix/vX.Y.Z+1 ブランチ
2. 修正コミット (テスト含む)
3. PR → Review → Merge
4. Tag → CI Release Build
5. App Store Connect Phased Release で 1% → 5% → 25% → 100%
6. Sentry / PostHog で監視
```

App Store の Expedited Review は 1 件 / 90 日のみ申請可、緊急時のみ使用。

### F.10.3 リバート手順

App Store のリリースは一度公開すると取り下げ困難。Phased Release 中なら停止可能、完全公開後は新バージョンで上書きするか旧バージョンを再 submit。

## F.11 監視と alert

```
Sentry:
  - crash-free user < 99% → email
  - new issue first seen → email
  - issue regression → email

PostHog:
  - DAU dropoff > 30% week-over-week → manual review
  - paywall.conversion_rate < 2% → review
  - mission.completion_rate < 50% → review

Supabase:
  - DB CPU > 70% → email
  - Edge Function error rate > 5% → email
  - Storage usage > 80% → email

RevenueCat:
  - Trial conversion < 30% → manual review
  - Subscription churn > 15% → review
```

## F.12 オンコール体制

個人開発なので「自分」。Sentry email を iPhone push 通知設定で「Time Sensitive」に。深夜の critical issue 対応は SLA なし、翌朝対応。

---

# Appendix G — アーキテクチャパターン 深掘り

## G.1 MV パターン採用理由（詳細）

### G.1.1 各パターンの比較

| パターン | 個人開発適合 | iOS 26 適合 | テスト容易性 | 採用 |
|---|---|---|---|---|
| MVC (Apple 古典) | ◯ | △ | × | ✗ |
| MVVM (Combine) | △ | △ | ◯ | ✗ |
| MV + @Observable | ◎ | ◎ | ◯ | **◎** |
| TCA (Composable) | × | ◯ | ◎ | ✗（学習・型コスト） |
| VIPER | × | × | ◎ | ✗ |
| Clean Architecture | × | △ | ◎ | ✗（過剰） |

### G.1.2 MV パターン具体形

```swift
// View
struct AlarmListView: View {
  @Environment(AlarmService.self) var alarmService
  @Environment(EntitlementStore.self) var entitlement
  @Query(sort: \Alarm.timeOfDayHour) var alarms: [Alarm]
  @State private var isShowingEditor = false
  
  var body: some View {
    NavigationStack {
      List(alarms) { alarm in
        AlarmRow(alarm: alarm)
      }
      .toolbar { Button("追加") { isShowingEditor = true } }
      .sheet(isPresented: $isShowingEditor) {
        AlarmEditorView()
      }
    }
  }
}
```

別の `@Observable AlarmListViewModel` は不要。`@Query` で SwiftData から直接取得、ロジックは `AlarmService` に委譲。

### G.1.3 ViewModel が必要なケース

複雑な状態（loading + error + content + paging）を持つフィーチャーには `@Observable Model` クラスを置く：

```swift
@Observable @MainActor
final class PaywallModel {
  var offering: Offering?
  var isLoading: Bool = false
  var error: Error?
  var selectedPackage: Package?
  
  private let entitlement: EntitlementStore
  private let analytics: AnalyticsClient
  
  init(entitlement: EntitlementStore, analytics: AnalyticsClient) {
    self.entitlement = entitlement
    self.analytics = analytics
  }
  
  func load() async {
    isLoading = true
    do {
      offering = try await Purchases.shared.offerings().current
      analytics.track(.paywall_viewed)
    } catch {
      self.error = error
    }
    isLoading = false
  }
  
  func purchase(_ package: Package) async { /* ... */ }
}
```

「View 内の `@State` で済まない」かつ「複数 View から再利用」される場合のみ。

## G.2 Dependency Injection 詳細

### G.2.1 EnvironmentValues 拡張パターン

```swift
extension EnvironmentValues {
  @Entry var alarmService: AlarmService = .live
  @Entry var geminiProxyClient: GeminiProxyClient = .live
  @Entry var clock: Clock = SystemClock()
  // ...
}

// App ルート
@main
struct OkiMissionApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.alarmService, .live)
        .environment(\.geminiProxyClient, .live)
        // ...
    }
  }
}

// View 側
struct AlarmEditorView: View {
  @Environment(\.alarmService) var alarmService
  // ...
}
```

iOS 26 の `@Entry` macro（仮称）でボイラープレート削減。`@Entry` が iOS 26 で正式提供されない場合は EnvironmentKey 自作。

### G.2.2 シングルトン的サービスは `@Observable` クラス

```swift
@Observable @MainActor
final class EntitlementStore { /* ... */ }

// App ルート
@State var entitlementStore = EntitlementStore()

WindowGroup {
  RootView()
    .environment(entitlementStore)
}

// View 側
@Environment(EntitlementStore.self) var entitlement
```

### G.2.3 テスト時のモック

```swift
final class MockAlarmService: AlarmService {
  override func schedule(_ alarm: Alarm) async throws -> UUID {
    return UUID()  // 即座に返す
  }
}

func testAlarmCreation() async {
  let store = AlarmStore()
  store.alarmService = MockAlarmService()
  // ...
}
```

`AlarmService` を protocol 化することも検討したが、override で足りる場合は class のまま（boilerplate 削減）。

## G.3 Navigation 詳細

### G.3.1 NavigationStack のライフサイクル

```swift
@Observable
final class Router {
  var path: [AppRoute] = []
  var modalRoute: ModalRoute?
  
  func push(_ route: AppRoute) { path.append(route) }
  func pop() { path.removeLast() }
  func popToRoot() { path.removeAll() }
  func present(_ modal: ModalRoute) { modalRoute = modal }
  func dismiss() { modalRoute = nil }
}

struct RootView: View {
  @State var router = Router()
  
  var body: some View {
    NavigationStack(path: $router.path) {
      MainTabView()
        .navigationDestination(for: AppRoute.self) { route in
          destinationView(for: route)
        }
    }
    .sheet(item: $router.modalRoute) { route in
      modalView(for: route)
    }
    .environment(router)
  }
}
```

### G.3.2 Deep Link 解決

```swift
struct RootView: View {
  var body: some View {
    NavigationStack(path: $router.path) { /* ... */ }
      .onOpenURL { url in
        handleURL(url)
      }
      .onContinueUserActivity(StartMissionIntent.activityType) { activity in
        handleIntentActivity(activity)
      }
  }
  
  private func handleURL(_ url: URL) {
    // okimission://mission/<runId>
    guard url.scheme == "okimission" else { return }
    let components = url.pathComponents
    if components.count >= 2, components[1] == "mission" {
      if let runId = UUID(uuidString: components[2]) {
        router.push(.missionRun(runId: runId))
      }
    }
  }
}
```

### G.3.3 Sheet vs FullScreenCover vs Popover

| ケース | UI | 例 |
|---|---|---|
| 一時的入力 | `.sheet` | アラーム編集 |
| 集中タスク | `.fullScreenCover` | ミッション実行、Paywall |
| 補助情報 | `.popover` (iPad) / `.sheet` (iPhone) | 設定の説明 |
| 確認ダイアログ | `.alert` / `.confirmationDialog` | 削除確認 |

## G.4 State Restoration

iOS 標準の Scene state restoration は SwiftUI で `SceneStorage` を使うのが正攻法だが、複雑な path は手動で UserDefaults：

```swift
@AppStorage("router.path") var pathJSON: String = "[]"

private func saveRoute() {
  pathJSON = (try? JSONEncoder().encode(router.path)).map { String(data: $0, encoding: .utf8)! } ?? "[]"
}

private func restoreRoute() {
  guard let data = pathJSON.data(using: .utf8),
        let routes = try? JSONDecoder().decode([AppRoute].self, from: data) else { return }
  router.path = routes
}
```

ミッション実行中の kill 復旧は §8.4 と統合（restoration token と route の両方を見る）。

## G.5 SwiftUI ⇔ UIKit ブリッジ

### G.5.1 カメラプレビュー

```swift
struct CameraPreviewView: UIViewRepresentable {
  let session: AVCaptureSession
  
  func makeUIView(context: Context) -> PreviewView {
    let v = PreviewView()
    v.videoPreviewLayer.session = session
    v.videoPreviewLayer.videoGravity = .resizeAspectFill
    return v
  }
  
  func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
```

### G.5.2 SFSafariViewController

```swift
struct SafariView: UIViewControllerRepresentable {
  let url: URL
  
  func makeUIViewController(context: Context) -> SFSafariViewController {
    SFSafariViewController(url: url)
  }
  
  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
```

Privacy Policy / Terms はこれで表示。

## G.6 Concurrency 詳細

### G.6.1 Structured vs Unstructured

- **Structured** (`async let`, `TaskGroup`): 親 task のキャンセル伝播あり、推奨
- **Unstructured** (`Task { }`): View body 内で開始する fire-and-forget。`.task { }` modifier を優先（View ライフサイクル連動）
- **Detached** (`Task.detached`): priority 制御や親キャンセル不要時のみ。例: StoreKitListener

### G.6.2 Actor 設計

| Actor | 用途 | 理由 |
|---|---|---|
| `AlarmService` | AlarmKit + SwiftData 操作 | スケジューリングの並行安全性 |
| `CameraSession` | AVCaptureSession 管理 | UI 非ブロック |
| `FrameBroker` | フレームスロットル | producer/consumer 安全 |
| `ModelLoader` | Core ML hot cache | reload 競合防止 |
| `AlarmEventBus` | AlarmKit event fanout | broadcast 排他 |

`@MainActor` クラス: UI 連動の `EntitlementStore`, `Router`, ViewModel 群。

### G.6.3 Sendable

Swift 6 strict concurrency 下で全モデル型 `Sendable`:
- `@Model` クラスは SwiftData が `Sendable` 提供（context 越しの参照は ID 経由）
- Codable struct は自動 `Sendable`（全フィールド Sendable なら）
- enum も自動

例外: 一部の UIKit type（`UIImage` 等）は Sendable ではない。`Sendable` ラッパで safety を明示。

## G.7 Error Propagation

### G.7.1 typed throws (Swift 6)

```swift
func schedule(_ alarm: Alarm) async throws(DomainError) -> UUID {
  // 型付き throws で AlarmKitError も DomainError にラップ
}
```

### G.7.2 Result vs throw

- async/await + throws: 推奨
- Result<T, Error>: Combine ブリッジや古い API のみ
- Optional return on failure: 単純な失敗（cache miss 等）のみ

## G.8 ログ設計

### G.8.1 os.Logger カテゴリ

```swift
extension Logger {
  static let app = Logger(subsystem: "com.example.okimission", category: "app")
  static let alarmKit = Logger(subsystem: "...", category: "alarmkit")
  static let mission = Logger(subsystem: "...", category: "mission")
  static let vision = Logger(subsystem: "...", category: "vision")
  static let auth = Logger(subsystem: "...", category: "auth")
  static let subscriptions = Logger(subsystem: "...", category: "subscriptions")
  static let analytics = Logger(subsystem: "...", category: "analytics")
  static let network = Logger(subsystem: "...", category: "network")
}
```

### G.8.2 Sentry breadcrumb bridge

```swift
extension Logger {
  func info(_ message: String, file: String = #file, line: Int = #line) {
    self.log(level: .info, "\(message)")
    SentrySDK.addBreadcrumb(Breadcrumb(level: .info, category: subsystem) /* ... */)
  }
}
```

## G.9 テスト戦略

### G.9.1 種類別カバレッジ目標

| 種別 | 対象 | カバレッジ目標 |
|---|---|---|
| Unit | Core/, Services/, MissionEngine | 80% |
| Integration | Edge Function ⇔ iOS API path | 主要 5 シナリオ |
| UI | onboarding, paywall, mission flow | smoke 3 シナリオ |
| Snapshot | DesignSystem, 主要 View | 主要 15 view |
| Performance | cold start, scroll, schedule | 5 benchmark |

### G.9.2 SwiftUI Preview 戦略

各 View に `#Preview` を 3 種以上（default / loading / error / accessibility XXL）。

```swift
#Preview("default") {
  AlarmListView()
    .modelContainer(.previewWithSamples)
    .environment(EntitlementStore.preview(.pro))
}

#Preview("empty") {
  AlarmListView()
    .modelContainer(.previewEmpty)
    .environment(EntitlementStore.preview(.free))
}

#Preview("XXL") {
  AlarmListView()
    .modelContainer(.previewWithSamples)
    .environment(\.dynamicTypeSize, .accessibility5)
}
```

### G.9.3 Test Doubles

```swift
extension AlarmService {
  static var preview: AlarmService = MockAlarmService()
  static var live: AlarmService = AlarmService()
}

extension EntitlementStore {
  static func preview(_ tier: Tier) -> EntitlementStore {
    let store = EntitlementStore()
    store.tier = tier
    return store
  }
}

extension ModelContainer {
  static var previewWithSamples: ModelContainer {
    let container = try! ModelContainer(
      for: SchemaV1.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    SampleData.populate(into: container.mainContext)
    return container
  }
}
```

## G.10 Liquid Glass 実装方針

### G.10.1 採用範囲

- **強く採用**: AlarmList の各アラームカード、Live Activity、Settings sheet、Mission progress card
- **限定採用**: フルスクリーンの背景（コンテンツが多い画面では subtle level）
- **不採用**: ホーム widget（Apple の Widget API では Glass 直接不可）、テキスト読みやすさ優先のフォーム入力画面

### G.10.2 Glass tier 使い分け

```swift
.glassEffect(.subtle, in: .rect(cornerRadius: 12))   // 背景に近い、低コントラスト
.glassEffect(.regular, in: .rect(cornerRadius: 16))  // 標準カード
.glassEffect(.prominent, in: .rect(cornerRadius: 20)) // 強調パネル
```

### G.10.3 Dark mode

OkiMission は **dark default**。light mode も提供するが、iOS 26 のシステム設定に従う `@Environment(\.colorScheme)` 連動。

### G.10.4 動作確認

- iPhone 11 (A13) で 60fps 維持: Glass 1 layer + 通常コンテンツ → OK 想定
- 2 layer (背景 Glass + 上に Glass card) → 要計測
- 3 layer 以上は禁止（パフォーマンス + 視認性）

## G.11 Animation 設計

### G.11.1 Spring パラメータ

```swift
extension Animation {
  static let omGentle = Animation.spring(response: 0.5, dampingFraction: 0.85)
  static let omSnappy = Animation.spring(response: 0.3, dampingFraction: 0.75)
  static let omBouncy = Animation.spring(response: 0.6, dampingFraction: 0.6)
}
```

### G.11.2 Reduce Motion 連動

```swift
struct AnimatedView: View {
  @Environment(\.accessibilityReduceMotion) var reduceMotion
  
  var body: some View {
    content
      .animation(reduceMotion ? .easeInOut(duration: 0.1) : .omSnappy, value: state)
  }
}
```

### G.11.3 Mission Success Animation

```swift
struct MissionSuccessView: View {
  @State private var isAnimating = false
  @Environment(\.accessibilityReduceMotion) var reduceMotion
  
  var body: some View {
    VStack {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 80))
        .foregroundStyle(.green)
        .scaleEffect(isAnimating ? 1 : 0.5)
        .rotationEffect(.degrees(isAnimating ? 0 : -180))
      Text("ミッション完了！")
    }
    .onAppear {
      if reduceMotion {
        isAnimating = true  // 即座に
      } else {
        withAnimation(.omBouncy) { isAnimating = true }
      }
      HapticEngine.success()
    }
  }
}
```

## G.12 結局のところ — 開発者の心得

設計の細部はあくまで「最初の意思決定」。実装中に必ず仕様変更や新発見が起きるので、本計画も生きたドキュメントとして §33 のチェックポイントで継続更新する。

