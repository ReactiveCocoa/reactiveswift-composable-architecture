import ComposableArchitecture
import ReactiveSwift
import SwiftUI

@main
struct SpeechRecognitionApp: App {
  var body: some Scene {
    WindowGroup {
      SpeechRecognitionView(
        store: Store(
          initialState: AppState(),
          reducer: appReducer,
          environment: AppEnvironment(
            mainQueue: QueueScheduler.main,
            speechClient: .live
          )
        )
      )
    }
  }
}
