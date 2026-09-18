//
//  SakuraPetalFlowStateTests.swift
//  MujoTests
//

import Testing
@testable import Mujo

@Suite("Sakura petal flow")
struct SakuraPetalFlowStateTests {
    @Test("Opening with remaining time starts an already flowing field")
    func openingWithTime() {
        var flow = SakuraPetalFlowState()
        flow.reconcile(emitsPetals: true, at: 0)
        flow.reconcile(emitsPetals: true, at: 30)

        #expect(flow.streams.count == 1)
        #expect(flow.streams[0].startTime == nil)
        #expect(flow.streams[0].stopTime == nil)
    }

    @Test("Zero stops old petals and a higher limit adds a new wave")
    func zeroThenHigherLimit() {
        var flow = SakuraPetalFlowState()
        flow.reconcile(emitsPetals: true, at: 0)
        flow.reconcile(emitsPetals: false, at: 10)
        flow.reconcile(emitsPetals: true, at: 12)
        flow.reconcile(emitsPetals: true, at: 13)

        #expect(flow.streams.count == 2)
        #expect(flow.streams[0].stopTime == 10)
        #expect(flow.streams[1].startTime == 12)
        #expect(flow.streams[1].stopTime == nil)
    }

    @Test("Opening at zero has no petals until remaining time rises")
    func openingAtZero() {
        var flow = SakuraPetalFlowState()
        flow.reconcile(emitsPetals: false, at: 0)
        #expect(flow.streams.isEmpty)

        flow.reconcile(emitsPetals: true, at: 5)
        #expect(flow.streams.count == 1)
        #expect(flow.streams[0].startTime == 5)
    }
}
