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

    store.send(.onAppear)

      // Simulate a screenshot being taken
    screenshotTaken.input.send(value: ())
    store.receive(.userDidTakeScreenshotNotification) {
        $0.screenshotCount = 1
    }

    store.send(.onDisappear)

      // Simulate a screenshot being taken to show no effects
      // are executed.
    screenshotTaken.input.send(value: ())
  }
}
