import Foundation
import ReactiveSwift

extension Effect {
  /// Returns an effect that will be executed after given `dueTime`.
  ///
  /// ```swift
  /// case let .textChanged(text):
  ///   return self.apiClient.search(text)
  ///     .deferred(for: 0.5, scheduler: self.mainQueue)
  ///     .map(Action.searchResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - dueTime: The duration you want to defer for.
  ///   - scheduler: The scheduler you want to deliver the defer output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that will be executed after `dueTime`
  @available(iOS, deprecated: 9999.0, message: "Use 'scheduler.sleep' in 'Effect.run', instead.")
  @available(macOS, deprecated: 9999.0, message: "Use 'scheduler.sleep' in 'Effect.run', instead.")
  @available(tvOS, deprecated: 9999.0, message: "Use 'scheduler.sleep' in 'Effect.run', instead.")
  @available(
    watchOS, deprecated: 9999.0, message: "Use 'scheduler.sleep' in 'Effect.run', instead."
  )
  public func deferred(
    for dueTime: TimeInterval,
    scheduler: DateScheduler
  ) -> Self {
    switch self.operation {
    case .none:
      return .none
    case .producer, .run:
      return Self(
        operation: .producer(
          SignalProducer<Void, Never>(value: ())
            .delay(dueTime, on: scheduler)
            .flatMap(.latest) { self.producer.observe(on: scheduler) }
        )
      )
    }
  }
}
