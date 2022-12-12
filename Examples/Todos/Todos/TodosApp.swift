import ComposableArchitecture
import ReactiveSwift
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: Store(
          initialState: AppState(),
          reducer: appReducer,
          environment: AppEnvironment(
            mainQueue: QueueScheduler.main,
            uuid: { UUID() }
          )
        )
      )
    }
  }
}
