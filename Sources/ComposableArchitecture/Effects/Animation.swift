#if canImport(SwiftUI)
  import ReactiveSwift
  import SwiftUI

  extension EffectProducer {
    /// Wraps the emission of each element with SwiftUI's `withAnimation`.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return .task {
    ///     .activityResponse(await self.apiClient.fetchActivity())
    ///   }
    ///   .animation()
    /// ```
    ///
    /// - Parameter animation: An animation.
    /// - Returns: An effect.
    public func animation(_ animation: Animation? = .default) -> Self {
      switch self.operation {
      case .none:
        return .none
      case let .producer(producer):
        return Self(
          operation: .producer(
            SignalProducer<Action, Failure> { observer, _ in
              producer.start { action in
                switch action {
                case let .value(value):
                  withAnimation(animation) {
                    observer.send(value: value)
                  }
                case .completed:
                  observer.sendCompleted()
                case let .failed(error):
                  observer.send(error: error)
                case .interrupted:
                  observer.sendInterrupted()
                }
              }
            }
          )
        )
      case let .run(priority, operation):
        return Self(
          operation: .run(priority) { send in
            await operation(
              Send { value in
                withAnimation(animation) {
                  send(value)
                }
              }
            )
          }
        )
      }
    }
  }
#endif
