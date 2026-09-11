//
//  TimeFormattingTests.swift
//  MujoTests
//

import Foundation
import Testing
@testable import Mujo

@Suite("Time formatting")
struct TimeFormattingTests {
    @Test("Zero and negative durations use the empty-time symbol")
    func formatsEmptyTime() {
        #expect(TimeInterval(0).formatted() == "Ø")
        #expect(TimeInterval(59).formatted() == "Ø")
        #expect(TimeInterval(-60).formatted() == "Ø")
    }

    @Test("Durations are truncated to whole minutes")
    func formatsHoursAndMinutes() {
        #expect(TimeInterval(60).formatted() == "0:01")
        #expect(TimeInterval(3_599).formatted() == "0:59")
        #expect(TimeInterval(3_600).formatted() == "1:00")
        #expect(TimeInterval(13_379).formatted() == "3:42")
    }
}
