import Combine
import ComposableArchitecture
import ReactiveSwift
import SwiftUI
import UIKit

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" simultaneously navigates to a screen that depends on optional \
  counter state and fires off an effect that will load this state a second later.
  """

struct EagerNavigationState: Equatable {
  var isNavigationActive = false
  var optionalCounter: CounterState?
}

enum EagerNavigationAction: Equatable {
  case optionalCounter(CounterAction)
  case setNavigation(isActive: Bool)
  case setNavigationIsActiveDelayCompleted
}

struct EagerNavigationEnvironment {
  var mainQueue: DateScheduler
}

let eagerNavigationReducer = counterReducer
  .optional
  .pullback(
    state: \.optionalCounter,
    action: /EagerNavigationAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      EagerNavigationState, EagerNavigationAction, EagerNavigationEnvironment
    > { state, action, environment in
      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return Effect(value: .setNavigationIsActiveDelayCompleted)
          .delay(1, on: environment.mainQueue)

      case .setNavigation(isActive: false):
        state.isNavigationActive = false
        state.optionalCounter = nil
        return .none

      case .setNavigationIsActiveDelayCompleted:
        state.optionalCounter = CounterState()
        return .none

      case .optionalCounter:
        return .none
      }
    }
  )

struct EagerNavigationView: View {
  let store: Store<EagerNavigationState, EagerNavigationAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: { $0.optionalCounter }, action: EagerNavigationAction.optionalCounter),
              then: CounterView.init(store:),
              else: ActivityIndicator()
            ),
            isActive: viewStore.binding(
              get: { $0.isNavigationActive },
              send: EagerNavigationAction.setNavigation(isActive:)
            )
          ) {
            HStack {
              Text("Load optional counter")
            }
          }
        }
      }
    }
    .navigationBarTitle("Navigate and load")
  }
}

struct EagerNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      EagerNavigationView(
        store: Store(
          initialState: EagerNavigationState(),
          reducer: eagerNavigationReducer,
          environment: EagerNavigationEnvironment(
            mainQueue: QueueScheduler.main
          )
        )
      )
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}
