import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class EffectsBasicsTests: XCTestCase {
  let scheduler = TestScheduler()

  func testCountDown() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        mainQueue: self.scheduler,
        numberFact: { _ in fatalError("Unimplemented") }
      )
    )

    store.assert(
      .send(.incrementButtonTapped) {
        $0.count = 1
      },
      .send(.decrementButtonTapped) {
        $0.count = 0
      },
      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.incrementButtonTapped) {
        $0.count = 1
      }
    )
  }

  func testNumberFact() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        mainQueue: self.scheduler,
        numberFact: { n in Effect(value: "\(n) is a good number Brent") }
      )
    )

    store.assert(
      .send(.incrementButtonTapped) {
        $0.count = 1
      },
      .send(.numberFactButtonTapped) {
        $0.isNumberFactRequestInFlight = true
      },
      .do { self.scheduler.advance() },
      .receive(.numberFactResponse(.success("1 is a good number Brent"))) {
        $0.isNumberFactRequestInFlight = false
        $0.numberFact = "1 is a good number Brent"
      }
    )
  }
}
