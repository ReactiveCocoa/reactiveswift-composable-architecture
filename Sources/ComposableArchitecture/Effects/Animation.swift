#if canImport(SwiftUI)
  import ReactiveSwift
  import SwiftUI

  extension Effect {
    /// Wraps the emission of each element with SwiftUI's `withAnimation`.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return .task {
    ///     .activityResponse(await environment.apiClient.fetchActivity())
    ///   }
    ///   .animation()
    /// ```
    ///
    /// - Parameter animation: An animation.
    /// - Returns: A publisher.
    public func animation(_ animation: Animation? = .default) -> Self {
      SignalProducer<Output, Failure> { observer, _ in
        self.producer.start { action in
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
      .eraseToEffect()
    }
  }
#endif
