import Combine
import Testing
@testable import Mujo

@Suite("Private report loading")
@MainActor
struct ReportContentLoaderTests {
    @Test("Loading is replaced by data and repeated appearances do not reload")
    func loadsOnce() async {
        var calls = 0
        let loader = ReportContentLoader<Int>(timeout: .seconds(60)) {
            calls += 1
            return 42
        }
        guard case .loading = loader.state else {
            Issue.record("A new report must start in loading")
            return
        }
        loader.start()
        loader.start()
        for await state in loader.$state.values {
            if case .loaded(let value) = state {
                #expect(value == 42)
                break
            }
        }
        loader.start()
        #expect(calls == 1)
    }

    @Test("Empty results are distinct from loading and timeout")
    func noData() async {
        let loader = ReportContentLoader<Int> { nil }
        loader.start()
        for await state in loader.$state.values {
            if case .noData = state { break }
        }
        guard case .noData = loader.state else {
            Issue.record("An empty result must resolve as noData")
            return
        }
    }

    @Test("A timeout never erases a result that already loaded")
    func loadedResultSurvivesDeadline() async throws {
        let loader = ReportContentLoader<Int>(timeout: .milliseconds(10)) { 42 }
        loader.start()
        for await state in loader.$state.values {
            if case .loaded = state { break }
        }
        try await Task.sleep(for: .milliseconds(40))
        guard case .loaded(let value) = loader.state else {
            Issue.record("The deadline erased loaded content")
            return
        }
        #expect(value == 42)
    }

    @Test("Slow data can replace the timeout fallback without restarting")
    func lateResult() async {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let loader = ReportContentLoader<Int>(timeout: .milliseconds(10)) {
            for await value in stream { return value }
            return nil
        }
        loader.start()
        for await state in loader.$state.values {
            if case .timedOut = state { break }
        }
        continuation.yield(42)
        continuation.finish()
        for await state in loader.$state.values {
            if case .loaded(let value) = state {
                #expect(value == 42)
                break
            }
        }
    }

    @Test("An old report finishing cannot overwrite a different report")
    func independentReports() async {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let first = ReportContentLoader<Int> {
            for await value in stream { return value }
            return nil
        }
        let second = ReportContentLoader<Int> { 7 }
        first.start()
        second.start()
        for await state in second.$state.values {
            if case .loaded = state { break }
        }
        continuation.yield(42)
        continuation.finish()
        for await state in first.$state.values {
            if case .loaded = state { break }
        }
        guard case .loaded(let value) = second.state else {
            Issue.record("The second report lost its result")
            return
        }
        #expect(value == 7)
    }
}
