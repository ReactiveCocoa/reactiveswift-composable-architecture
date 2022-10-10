import ComposableArchitecture
import ReactiveSwift
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: Store(
          initialState: Todos.State(),
          reducer: Todos()._printChanges()
        )
      )
    }
  }
}
