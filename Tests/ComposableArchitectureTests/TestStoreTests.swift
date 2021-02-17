import ComposableArchitecture
import ReactiveSwift
import XCTest

class TestStoreTests: XCTestCase {
  func testEffectConcatenation() {
    struct State: Equatable {}

    enum Action: Equatable {
      case a, b1, b2, b3, c1, c2, c3, d
    }

    let testScheduler = TestScheduler()

    let reducer = Reducer<State, Action, DateScheduler> { _, action, scheduler in
      switch action {
      case .a:
        return .merge(
          Effect.concatenate(.init(value: .b1), .init(value: .c1))
            .delay(1, on: scheduler),
          Effect.none
            .cancellable(id: 1)
        )
      case .b1:
        return
          Effect
          .concatenate(.init(value: .b2), .init(value: .b3))
      case .c1:
        return
          Effect
          .concatenate(.init(value: .c2), .init(value: .c3))
      case .b2, .b3, .c2, .c3:
        return .none

      case .d:
        return .cancel(id: 1)
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer,
      environment: testScheduler
    )

    store.assert(
      .send(.a),

      .do { testScheduler.advance(by: .seconds(1)) },

      .receive(.b1),
      .receive(.b2),
      .receive(.b3),

      .sequence([
        .receive(.c1),
        .receive(.c2),
        .receive(.c3),
      ]),

      .send(.d)
    )
  }
}
