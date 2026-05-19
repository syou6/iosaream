import Foundation
import OkiMissionCore
import OkiMissionVoicePack

public actor MissionExperience {
    public struct Configuration: Sendable {
        public var antiCheatPolicy: AntiCheatPolicy
        public var clock: any AppClock
        public var voiceCue: MissionVoiceCue?

        public init(
            antiCheatPolicy: AntiCheatPolicy = .default,
            clock: any AppClock = SystemClock(),
            voiceCue: MissionVoiceCue? = nil
        ) {
            self.antiCheatPolicy = antiCheatPolicy
            self.clock = clock
            self.voiceCue = voiceCue
        }
    }

    public let runId: UUID
    public let template: GeneratedMissionTemplate
    public let configuration: Configuration

    private var machine: MissionStateMachine
    private var antiCheatContext: AntiCheatContext
    private let evaluator: AntiCheatEvaluator
    private var lastAntiCheatScore: Int = 0
    private var lastAntiCheatSignals: [AntiCheatSignal] = []

    private var mathEngine: MathMissionEngine?
    private var pushupEngine: PushupMissionEngine?
    private var squatEngine: PushupMissionEngine?
    private var shakeEngine: ShakeMissionEngine?
    private var huntEngine: ObjectHuntMissionEngine?
    private var barcodeEngine: BarcodeMissionEngine?

    private let continuation: AsyncStream<MissionEvent>.Continuation
    public nonisolated let events: AsyncStream<MissionEvent>

    public init(
        template: GeneratedMissionTemplate,
        configuration: Configuration = Configuration(),
        runId: UUID = UUID()
    ) throws {
        self.runId = runId
        self.template = template
        self.configuration = configuration
        self.machine = MissionStateMachine()
        let now = configuration.clock.now()
        let uptime = configuration.clock.uptime()
        self.antiCheatContext = AntiCheatContext(
            sessionStart: now,
            sessionStartUptime: uptime,
            clockReadings: [.init(uptime: uptime, wallClock: now)]
        )
        self.evaluator = AntiCheatEvaluator(policy: configuration.antiCheatPolicy)

        let (stream, continuation) = AsyncStream.makeStream(of: MissionEvent.self)
        self.events = stream
        self.continuation = continuation

        switch template.kind {
        case .math:
            let params = try MissionParameterDecoder.decode(template.parametersJSON, as: MathParams.self)
            var rng = SeededRandom(seed: UInt64(template.id.uuidString.hashValue & Int.max))
            let problems = MathProblemGenerator(params: params).generate(using: &rng)
            self.mathEngine = MathMissionEngine(problems: problems)
        case .pushup:
            let params = try MissionParameterDecoder.decode(template.parametersJSON, as: PushupParams.self)
            self.pushupEngine = PushupMissionEngine(targetReps: params.reps)
        case .squat:
            let params = try MissionParameterDecoder.decode(template.parametersJSON, as: SquatParams.self)
            self.squatEngine = PushupMissionEngine(targetReps: params.reps)
        case .shake:
            let params = try MissionParameterDecoder.decode(template.parametersJSON, as: ShakeParams.self)
            self.shakeEngine = ShakeMissionEngine(params: params)
        case .objectHunt:
            let params = try MissionParameterDecoder.decode(template.parametersJSON, as: ObjectHuntParams.self)
            self.huntEngine = ObjectHuntMissionEngine(
                targetClasses: params.targetClasses,
                requiredCount: params.requiredCount
            )
        case .barcode:
            let params = try MissionParameterDecoder.decode(template.parametersJSON, as: BarcodeParams.self)
            self.barcodeEngine = BarcodeMissionEngine(params: params)
        }
    }

    // MARK: - Lifecycle

    public func start() {
        let next = machine.start()
        emit(.stateChanged(next))
        fireCue(.missionStart)
    }

    public func reportCapability(_ capability: Capability, authorized: Bool) {
        let next = machine.capabilityResolved(capability, authorized: authorized)
        emit(.stateChanged(next))
    }

    public func reportFraming(progress: Double) {
        let previous = machine.state
        let next = machine.updateFraming(progress: progress)
        if next != previous {
            emit(.stateChanged(next))
        }
    }

    public func pause(reason: PauseReason) {
        let next = machine.pause(reason: reason)
        emit(.stateChanged(next))
    }

    public func resume() {
        let next = machine.resume()
        emit(.stateChanged(next))
    }

    public func cancel() {
        let next = machine.cancel()
        emit(.stateChanged(next))
        continuation.finish()
    }

    // MARK: - Anti-cheat signals

    public func recordBackgrounded() {
        antiCheatContext.backgroundEvents.append(configuration.clock.now())
        let next = machine.pause(reason: .appBackgrounded)
        emit(.stateChanged(next))
    }

    public func recordScreenshot() {
        antiCheatContext.screenshotEvents.append(configuration.clock.now())
        emit(.warning("screenshot_taken"))
    }

    public func recordFrameGap(seconds: TimeInterval) {
        antiCheatContext.frameGapsSeconds.append(seconds)
    }

    public func recordClockReading() {
        antiCheatContext.clockReadings.append(.init(
            uptime: configuration.clock.uptime(),
            wallClock: configuration.clock.now()
        ))
    }

    // MARK: - Per-kind inputs

    public var problems: [MathProblem] {
        mathEngine?.problems ?? []
    }

    @discardableResult
    public func submitMathAnswer(_ answer: Int, at index: Int) -> Bool {
        guard let engine = mathEngine else { return false }
        let correct = engine.submit(answer: answer, at: index)
        checkCompletion(progress: engine.progress)
        return correct
    }

    public func reportPoseAngle(_ angle: Double, leftConfidence: Double, rightConfidence: Double) {
        let engine = pushupEngine ?? squatEngine
        guard let engine else { return }
        if let event = engine.consume(rawElbowAngle: angle, leftConfidence: leftConfidence, rightConfidence: rightConfidence) {
            switch event {
            case .repCompleted(let count, _):
                emit(.repCompleted(count: count))
            case .lowConfidence:
                emit(.warning("low_confidence"))
            default:
                break
            }
        }
        checkCompletion(progress: engine.progress)
    }

    public func reportMotionSample(_ sample: AccelerationSample) {
        guard let engine = shakeEngine else { return }
        _ = engine.consume(sample)
        checkCompletion(progress: engine.progress)
    }

    public func reportDetectedClasses(_ classes: Set<String>) {
        guard let engine = huntEngine else { return }
        let newlyFound = engine.consume(detectedClasses: classes)
        if !newlyFound.isEmpty {
            emit(.warning("found:\(newlyFound.sorted().joined(separator: ","))"))
        }
        checkCompletion(progress: engine.progress)
    }

    public func reportBarcode(_ payload: String) {
        guard let engine = barcodeEngine else { return }
        _ = engine.consume(payload: payload)
        checkCompletion(progress: engine.progress)
    }

    // MARK: - State

    public var currentState: MissionState {
        machine.state
    }

    public func fail(_ reason: MissionFailureReason) {
        let next = machine.fail(reason)
        emit(.stateChanged(next))
        fireCue(.missionFailure)
        continuation.finish()
    }

    // MARK: - Internals

    private func emit(_ event: MissionEvent) {
        continuation.yield(event)
    }

    private func checkCompletion(progress: Double) {
        emit(.progressUpdated(progress))
        guard isCurrentEngineComplete(), case .running = machine.state else { return }

        let verifying = machine.conditionsMet()
        emit(.stateChanged(verifying))

        antiCheatContext.clockReadings.append(.init(
            uptime: configuration.clock.uptime(),
            wallClock: configuration.clock.now()
        ))
        let duration = configuration.clock.now().timeIntervalSince(antiCheatContext.sessionStart)
        let verdict = evaluator.evaluate(
            context: antiCheatContext,
            kind: template.kind,
            durationSeconds: duration
        )

        let finalState: MissionState
        switch verdict {
        case .clean:
            lastAntiCheatSignals = []
            lastAntiCheatScore = 0
            finalState = machine.verified(clean: true)
        case .cheated(let signals):
            lastAntiCheatSignals = signals
            lastAntiCheatScore = MissionExperience.score(for: signals)
            finalState = machine.verified(clean: false, signals: signals)
        }
        emit(.stateChanged(finalState))
        switch verdict {
        case .clean: fireCue(.missionSuccess)
        case .cheated: fireCue(.missionFailure)
        }
        continuation.finish()
    }

    private func fireCue(_ context: VoiceContext, pickIndex: Int = 0) {
        guard let cue = configuration.voiceCue else { return }
        Task { await cue.fire(context, pickIndex: pickIndex) }
    }

    public func finalRecord(alarmId: UUID? = nil, networkLatencyMs: Int? = nil) -> MissionRunRecord {
        let outcome: MissionOutcome
        var failureReason: MissionFailureReason?
        switch machine.state {
        case .completed:
            outcome = .success
        case .failed(let reason):
            outcome = .failure
            failureReason = reason
        case .cancelled:
            outcome = .cancelled
        case .cheated:
            outcome = .cheated
        default:
            outcome = .cancelled
        }
        let now = configuration.clock.now()
        let duration = now.timeIntervalSince(antiCheatContext.sessionStart)
        return MissionRunRecord(
            id: runId,
            alarmId: alarmId,
            templateId: template.id,
            missionKind: template.kind,
            startedAt: antiCheatContext.sessionStart,
            completedAt: machine.state.isTerminal ? now : nil,
            outcome: outcome,
            failureReason: failureReason,
            durationSeconds: duration,
            repsCompleted: completedReps(),
            antiCheatScore: lastAntiCheatScore,
            signals: lastAntiCheatSignals,
            networkLatencyMs: networkLatencyMs
        )
    }

    private func completedReps() -> Int {
        if let engine = mathEngine { return engine.correctCount }
        if let engine = pushupEngine { return engine.completedReps }
        if let engine = squatEngine { return engine.completedReps }
        if let engine = shakeEngine { return engine.completedShakes }
        if let engine = huntEngine { return engine.foundCount }
        if let engine = barcodeEngine { return engine.scannedPayloads.count }
        return 0
    }

    private static func score(for signals: [AntiCheatSignal]) -> Int {
        signals.reduce(0) { total, signal in
            switch signal {
            case .backgrounded(let count): return total + 2 * count
            case .clockTampered: return total + 5
            case .screenshotsTaken(let count): return total + count
            case .frameGaps: return total + 3
            case .tooFast: return total + 4
            }
        }
    }

    private func isCurrentEngineComplete() -> Bool {
        if let engine = mathEngine, engine.isComplete { return true }
        if let engine = pushupEngine, engine.isComplete { return true }
        if let engine = squatEngine, engine.isComplete { return true }
        if let engine = shakeEngine, engine.isComplete { return true }
        if let engine = huntEngine, engine.isComplete { return true }
        if let engine = barcodeEngine, engine.isComplete { return true }
        return false
    }
}
