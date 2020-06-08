import ComposableArchitecture
import ReactiveSwift
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" simultaneously presents a sheet that depends on optional counter \
  state and fires off an effect that will load this state a second later.
  """

struct EagerSheetState: Equatable {
  var optionalCounter: CounterState?
  var isSheetPresented = false
}

enum EagerSheetAction {
  case optionalCounter(CounterAction)
  case setSheet(isPresented: Bool)
  case setSheetIsPresentedDelayCompleted
}

struct EagerSheetEnvironment {
  var mainQueue: DateScheduler
}

let eagerSheetReducer = counterReducer
  .optional
  .pullback(
    state: \.optionalCounter,
    action: /EagerSheetAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      EagerSheetState, EagerSheetAction, EagerSheetEnvironment
    > { state, action, environment in
      switch action {
      case .setSheet(isPresented: true):
        state.isSheetPresented = true
        return Effect(value: .setSheetIsPresentedDelayCompleted)
          .delay(1, on: environment.mainQueue)

      case .setSheet(isPresented: false):
        state.isSheetPresented = false
        state.optionalCounter = nil
        return .none

      case .setSheetIsPresentedDelayCompleted:
        state.optionalCounter = CounterState()
        return .none

      case .optionalCounter:
        return .none
      }
    }
  )

struct EagerSheetView: View {
  let store: Store<EagerSheetState, EagerSheetAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          Button("Load optional counter") {
            viewStore.send(.setSheet(isPresented: true))
          }
        }
      }
      .sheet(
        isPresented: viewStore.binding(
          get: { $0.isSheetPresented },
          send: EagerSheetAction.setSheet(isPresented:)
        )
      ) {
        IfLetStore(
          self.store.scope(state: { $0.optionalCounter }, action: EagerSheetAction.optionalCounter),
          then: CounterView.init(store:),
          else: ActivityIndicator()
        )
      }
      .navigationBarTitle("Present and load")
    }
  }
}

struct EagerSheetView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      EagerSheetView(
        store: Store(
          initialState: EagerSheetState(),
          reducer: eagerSheetReducer,
          environment: EagerSheetEnvironment(
            mainQueue: QueueScheduler.main
          )
        )
      )
    }
  }
}
