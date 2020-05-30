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

    store.assert(
      .send(.toggleTimerButtonTapped) {
        $0.isTimerActive = true
      },
      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.timerTicked) {
        $0.secondsElapsed = 1
      },
      .do { self.scheduler.advance(by: .seconds(5)) },
      .receive(.timerTicked) {
        $0.secondsElapsed = 2
      },
      .receive(.timerTicked) {
        $0.secondsElapsed = 3
      },
      .receive(.timerTicked) {
        $0.secondsElapsed = 4
      },
      .receive(.timerTicked) {
        $0.secondsElapsed = 5
      },
      .receive(.timerTicked) {
        $0.secondsElapsed = 6
      },
      .send(.toggleTimerButtonTapped) {
        $0.isTimerActive = false
      }
    )
  }
}
