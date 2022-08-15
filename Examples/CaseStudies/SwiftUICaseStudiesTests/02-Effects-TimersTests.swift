import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class TimersTests: XCTestCase {
  func testStart() async {
    let mainQueue = TestScheduler()

    let store = TestStore(
      initialState: TimersState(),
      reducer: timersReducer,
      environment: TimersEnvironment(
        mainQueue: mainQueue
      )
    )

    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = true
    }
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 1
    }
    await mainQueue.advance(by: .seconds(5))
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 2
    }
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 3
    }
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 4
    }
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 5
    }
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 6
    }
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = false
    }
  }
}
