import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class LongLivingEffectsTests: XCTestCase {
  func testReducer() {
    // A passthrough subject to simulate the screenshot notification
    let screenshotTaken = Signal<Void, Never>.pipe()

    let store = TestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        userDidTakeScreenshot: screenshotTaken.output.producer
      )
    )

    store.assert(
      .send(.onAppear),

      // Simulate a screenshot being taken
      .do { screenshotTaken.input.send(value: ()) },
      .receive(.userDidTakeScreenshotNotification) {
        $0.screenshotCount = 1
      },

      .send(.onDisappear),

      // Simulate a screenshot being taken to show no effects
      // are executed.
      .do { screenshotTaken.input.send(value: ()) }
    )
  }
}
