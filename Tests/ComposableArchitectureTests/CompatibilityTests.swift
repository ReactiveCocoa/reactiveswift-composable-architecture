import ComposableArchitecture
import ReactiveSwift
import XCTest

@MainActor
final class CompatibilityTests: XCTestCase {
  func testCaseStudy_ReentrantEffect() {
    let cancelID = UUID()

    struct State: Equatable {}
    enum Action: Equatable {
      case start
      case kickOffAction
      case actionSender(OnDeinit)
      case stop

      var description: String {
        switch self {
        case .start:
          return "start"
        case .kickOffAction:
          return "kickOffAction"
        case .actionSender:
          return "actionSender"
        case .stop:
          return "stop"
        }
      }
    }
    let (signal, observer) = Signal<Action, Never>.pipe()

    var handledActions: [String] = []

    let reducer = Reducer<State, Action, Void> { state, action, env in
      handledActions.append(action.description)

      switch action {
      case .start:
        return signal.producer
          .eraseToEffect()
          .cancellable(id: cancelID)

      case .kickOffAction:
        return Effect(value: .actionSender(OnDeinit { observer.send(value: .stop) }))

      case .actionSender:
        return .none

      case .stop:
        return .cancel(id: cancelID)
      }
    }

    let store = Store(
      initialState: .init(),
      reducer: reducer,
      environment: ()
    )

    let viewStore = ViewStore(store)

    viewStore.send(.start)
    viewStore.send(.kickOffAction)

    XCTAssertNoDifference(
      handledActions,
      [
        "start",
        "kickOffAction",
        "actionSender",
        "stop",
      ]
    )
  }
}

private final class OnDeinit: Equatable {
  private let onDeinit: () -> Void
  init(onDeinit: @escaping () -> Void) {
    self.onDeinit = onDeinit
  }
  deinit { self.onDeinit() }
  static func == (lhs: OnDeinit, rhs: OnDeinit) -> Bool { true }
}
