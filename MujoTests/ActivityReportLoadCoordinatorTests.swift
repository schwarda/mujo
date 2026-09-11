//
//  ActivityReportLoadCoordinatorTests.swift
//  MujoTests
//

import Foundation
import Testing
@testable import Mujo

@Suite("Activity report loading")
@MainActor
struct ActivityReportLoadCoordinatorTests {
    @Test("A new request replaces stale loading state")
    func beginsNewRequest() throws {
        let context = try makeContext()
        defer { context.cleanUp() }

        let firstRequestID = context.coordinator.beginLoading()
        context.defaults.set(
            firstRequestID,
            forKey: MujoShared.DefaultsKey.readyActivityReportRequestID
        )
        let secondRequestID = context.coordinator.beginLoading()

        #expect(firstRequestID != secondRequestID)
        #expect(
            context.defaults.string(
                forKey: MujoShared.DefaultsKey.activityReportRequestID
            ) == secondRequestID
        )
        #expect(
            context.defaults.object(
                forKey: MujoShared.DefaultsKey.readyActivityReportRequestID
            ) == nil
        )
    }

    @Test("The matching response completes an active request")
    func acceptsMatchingResponse() async throws {
        let context = try makeContext()
        defer { context.cleanUp() }
        let requestID = context.coordinator.beginLoading()

        let response = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            context.defaults.set(
                requestID,
                forKey: MujoShared.DefaultsKey.readyActivityReportRequestID
            )
        }
        let isReady = await context.coordinator.waitUntilReady(
            requestID: requestID,
            timeout: .milliseconds(200)
        )
        await response.value

        #expect(isReady)
    }

    @Test("A response for another request is ignored")
    func ignoresStaleResponse() async throws {
        let context = try makeContext()
        defer { context.cleanUp() }
        let requestID = context.coordinator.beginLoading()
        context.defaults.set(
            UUID().uuidString,
            forKey: MujoShared.DefaultsKey.readyActivityReportRequestID
        )

        let isReady = await context.coordinator.waitUntilReady(
            requestID: requestID,
            timeout: .milliseconds(30)
        )

        #expect(!isReady)
    }

    @Test("Waiting times out when no response arrives")
    func timesOutWithoutResponse() async throws {
        let context = try makeContext()
        defer { context.cleanUp() }
        let requestID = context.coordinator.beginLoading()

        let isReady = await context.coordinator.waitUntilReady(
            requestID: requestID,
            timeout: .milliseconds(30)
        )

        #expect(!isReady)
    }

    @Test("Waiting stops when its task is cancelled")
    func stopsWhenCancelled() async throws {
        let context = try makeContext()
        defer { context.cleanUp() }
        let requestID = context.coordinator.beginLoading()
        let waitingTask = Task { @MainActor in
            await context.coordinator.waitUntilReady(
                requestID: requestID,
                timeout: .seconds(2)
            )
        }

        await Task.yield()
        waitingTask.cancel()
        let isReady = await waitingTask.value

        #expect(!isReady)
    }

    private func makeContext() throws -> TestContext {
        let suiteName = "AikariStudio.MujoTests.ActivityReportLoading."
            + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        return TestContext(
            suiteName: suiteName,
            defaults: defaults,
            coordinator: ActivityReportLoadCoordinator(
                sharedDefaults: defaults
            )
        )
    }

    private struct TestContext {
        let suiteName: String
        let defaults: UserDefaults
        let coordinator: ActivityReportLoadCoordinator

        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}
