import ComposableArchitecture
import ReactiveSwift
import XCTest

@MainActor
final class CompatibilityTests: XCTestCase {
  func testCaseStudy_ReentrantActionsFromBuffer() {
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

  func testCaseStudy_ReentrantActionsFromProducer() {
    struct State: Equatable {
      var city: String
      var country: String
    }

    enum Action: Equatable {
      case updateCity(String)
      case updateCountry(String)
    }

    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case let .updateCity(city):
        state.city = city
        return .none
      case let .updateCountry(country):
        state.country = country
        return .none
      }
    }

    let store = Store(
      initialState: State(city: "New York", country: "USA"),
      reducer: reducer,
      environment: ()
    )
    let viewStore = ViewStore(store)

    viewStore.produced.city
      .startWithValues { city in
        if city == "London" {
          viewStore.send(.updateCountry("UK"))
        }
      }

    var countryUpdates = [String]()
    viewStore.produced.country
      .startWithValues { country in
        countryUpdates.append(country)
      }

    viewStore.send(.updateCity("London"))

    XCTAssertEqual(countryUpdates, ["USA", "UK"])
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
