import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class TimersTests: XCTestCase {
  let mainQueue = TestScheduler()

  func testStart() {
    let store = TestStore(
      initialState: TimersState(),
      reducer: timersReducer,
      environment: TimersEnvironment(
        mainQueue: self.mainQueue
      )
    )

    store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = true
    }
    self.mainQueue.advance(by: 1)
    store.receive(.timerTicked) {
      $0.secondsElapsed = 1
    }
    self.mainQueue.advance(by: 5)
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
