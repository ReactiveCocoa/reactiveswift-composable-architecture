import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class TimersTests: XCTestCase {
  let scheduler = TestScheduler()

  func testStart() {
    let store = TestStore(
      initialState: TimersState(),
      reducer: timersReducer,
      environment: TimersEnvironment(
        mainQueue: self.scheduler
      )
    )

    store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = true
    }
    self.scheduler.advance(by: .seconds(1))
    store.receive(.timerTicked) {
      $0.secondsElapsed = 1
    }
    self.scheduler.advance(by: .seconds(5))
    store.receive(.timerTicked) {
      $0.secondsElapsed = 2
    }
    store.receive(.timerTicked) {
      $0.secondsElapsed = 3
    }
    store.receive(.timerTicked) {
      $0.secondsElapsed = 4
    }
    store.receive(.timerTicked) {
      $0.secondsElapsed = 5
    }
    store.receive(.timerTicked) {
      $0.secondsElapsed = 6
    }
    store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = false
    }
  }
}
