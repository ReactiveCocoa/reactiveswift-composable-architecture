import Combine
import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class LifecycleTests: XCTestCase {
  func testLifecycle() {
    let scheduler = TestScheduler()

    let store = TestStore(
      initialState: .init(),
      reducer: lifecycleDemoReducer,
      environment: .init(
        mainQueue: scheduler
      )
    )

    store.assert(
      .send(.toggleTimerButtonTapped) {
        $0.count = 0
      },

      .send(.timer(.onAppear)),

      .do { scheduler.advance(by: .seconds(1)) },
      .receive(.timer(.action(.tick))) {
        $0.count = 1
      },

      .do { scheduler.advance(by: .seconds(1)) },
      .receive(.timer(.action(.tick))) {
        $0.count = 2
      },

      .send(.timer(.action(.incrementButtonTapped))) {
        $0.count = 3
      },

      .send(.timer(.action(.decrementButtonTapped))) {
        $0.count = 2
      },

      .send(.toggleTimerButtonTapped) {
        $0.count = nil
      },

      .send(.timer(.onDisappear))
    )
  }
}
