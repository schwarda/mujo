#if DEBUG
import Foundation
import OSLog
import QuartzCore

private final class PerformanceDiagnosticsThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var lastLogByKey: [String: TimeInterval] = [:]
    private var suppressedCountByKey: [String: Int] = [:]

    func consume(
        key: String,
        now: TimeInterval,
        minimumInterval: TimeInterval
    ) -> Int? {
        lock.lock()
        defer { lock.unlock() }

        if let lastLog = lastLogByKey[key],
           now - lastLog < minimumInterval {
            suppressedCountByKey[key, default: 0] += 1
            return nil
        }

        lastLogByKey[key] = now
        return suppressedCountByKey.removeValue(forKey: key) ?? 0
    }
}

private final class PerformanceFrameMonitor: NSObject, @unchecked Sendable {
    static let shared = PerformanceFrameMonitor()

    private var displayLink: CADisplayLink?
    private var runLoopTimer: Timer?
    private var lastFrameCallbackTime: TimeInterval?
    private var lastRunLoopTimerTime: TimeInterval?
    private var currentPhase = "not-set"
    private var phaseStartedAt = ProcessInfo.processInfo.systemUptime
    private var framesSincePhaseChange = 0

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard displayLink == nil else { return }

        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(displayLinkFired(_:))
        )
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink

        let timer = Timer(
            timeInterval: 0.05,
            target: self,
            selector: #selector(runLoopTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        runLoopTimer = timer

        PerformanceDiagnostics.log(
            "frame-monitor",
            "started"
        )
    }

    func markPhase(_ phase: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        start()
        currentPhase = phase
        phaseStartedAt = PerformanceDiagnostics.now
        framesSincePhaseChange = 0
        PerformanceDiagnostics.log("phase", "BEGIN \(phase)")
    }

    @objc
    private func displayLinkFired(_ displayLink: CADisplayLink) {
        let now = PerformanceDiagnostics.now
        if let lastFrameCallbackTime {
            let gap = now - lastFrameCallbackTime
            if gap >= 0.10 {
                PerformanceDiagnostics.log(
                    "frame-monitor",
                    "FRAME GAP \(milliseconds(gap)) ms; phase=\(currentPhase); displayDuration=\(milliseconds(displayLink.duration)) ms"
                )
            }
        }
        lastFrameCallbackTime = now

        framesSincePhaseChange += 1
        if framesSincePhaseChange <= 3 {
            PerformanceDiagnostics.log(
                "frame-monitor",
                "frame \(framesSincePhaseChange) after phase \(currentPhase); elapsed=\(PerformanceDiagnostics.elapsedMilliseconds(since: phaseStartedAt)) ms"
            )
        }
    }

    @objc
    private func runLoopTimerFired(_ timer: Timer) {
        let now = PerformanceDiagnostics.now
        if let lastRunLoopTimerTime {
            let gap = now - lastRunLoopTimerTime
            if gap >= 0.10 {
                PerformanceDiagnostics.log(
                    "run-loop",
                    "TIMER GAP \(milliseconds(gap)) ms; phase=\(currentPhase)"
                )
            }
        }
        lastRunLoopTimerTime = now
    }

    private func milliseconds(_ duration: TimeInterval) -> String {
        String(format: "%.2f", duration * 1_000)
    }
}

enum PerformanceDiagnostics {
    nonisolated private static let logger = Logger(
        subsystem: "AikariStudio.Mujo",
        category: "Performance"
    )
    nonisolated private static let throttle = PerformanceDiagnosticsThrottle()

    nonisolated static var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    nonisolated static func log(
        _ source: String,
        _ message: String
    ) {
        let timestamp = String(format: "%.6f", now)
        logger.notice(
            "[MUJO-PERF][\(source, privacy: .public)][\(timestamp, privacy: .public)] \(message, privacy: .public)"
        )
    }

    static func throttledLog(
        key: String,
        minimumInterval: TimeInterval = 0.25,
        _ source: String,
        _ message: String
    ) {
        let timestamp = now
        guard let suppressedCount = throttle.consume(
            key: key,
            now: timestamp,
            minimumInterval: minimumInterval
        ) else { return }

        let suffix = suppressedCount == 0
            ? ""
            : "; suppressed=\(suppressedCount)"
        log(source, message + suffix)
    }

    static func startFrameMonitoring() {
        PerformanceFrameMonitor.shared.start()
    }

    static func markPhase(_ phase: String) {
        PerformanceFrameMonitor.shared.markPhase(phase)
    }

    nonisolated static func elapsedMilliseconds(
        since start: TimeInterval
    ) -> String {
        String(format: "%.2f", (now - start) * 1_000)
    }

    nonisolated static func mainQueueProbe(
        _ source: String,
        _ label: String,
        startedAt: TimeInterval
    ) {
        DispatchQueue.main.async {
            log(
                source,
                "\(label) | main queue resumed after \(elapsedMilliseconds(since: startedAt)) ms"
            )
        }
    }
}

struct DiagnosticEvent: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let source: String
    let message: String
}

enum DiagnosticsStore {
    nonisolated private static let eventsKeyPrefix =
        "mujo.debug.diagnosticEvents"
    nonisolated private static let knownSources = [
        "app", "monitor", "widget", "report"
    ]
    nonisolated private static let maximumEventsPerSource = 100

    nonisolated static func record(
        source: String,
        message: String,
        defaults: UserDefaults?
    ) {
        guard let defaults else { return }
        var events = load(source: source, defaults: defaults)
        events.append(DiagnosticEvent(
            id: UUID(),
            date: .now,
            source: source,
            message: message
        ))
        if events.count > maximumEventsPerSource {
            events.removeFirst(events.count - maximumEventsPerSource)
        }
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: eventsKey(source))
    }

    nonisolated static func load(
        defaults: UserDefaults?
    ) -> [DiagnosticEvent] {
        knownSources
            .flatMap { load(source: $0, defaults: defaults) }
            .sorted { $0.date < $1.date }
    }

    nonisolated static func clear(defaults: UserDefaults?) {
        knownSources.forEach {
            defaults?.removeObject(forKey: eventsKey($0))
        }
    }

    nonisolated private static func load(
        source: String,
        defaults: UserDefaults?
    ) -> [DiagnosticEvent] {
        guard let data = defaults?.data(forKey: eventsKey(source)),
              let events = try? JSONDecoder().decode(
                  [DiagnosticEvent].self,
                  from: data
              )
        else { return [] }
        return events
    }

    nonisolated private static func eventsKey(_ source: String) -> String {
        "\(eventsKeyPrefix).\(source)"
    }
}

enum DiagnosticsScenarioStore {
    nonisolated private static let forceNoHistoryKey =
        "mujo.debug.forceNoHistoryOnboarding"

    nonisolated static func scheduleNoHistoryOnboarding() {
        UserDefaults.standard.set(true, forKey: forceNoHistoryKey)
    }

    nonisolated static func consumeNoHistoryOnboarding() -> Bool {
        guard UserDefaults.standard.bool(forKey: forceNoHistoryKey) else {
            return false
        }
        UserDefaults.standard.removeObject(forKey: forceNoHistoryKey)
        return true
    }
}
#endif
