import Foundation
import ReactiveSwift

extension Effect {
  /// Returns an effect that will be executed after given `dueTime`.
  ///
  /// ```swift
  /// case let .textChanged(text):
  ///   return environment.search(text)
  ///     .deferred(for: 0.5, scheduler: environment.mainQueue)
  ///     .map(Action.searchResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - dueTime: The duration you want to defer for.
  ///   - scheduler: The scheduler you want to deliver the defer output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that will be executed after `dueTime`
  public func deferred(
    for dueTime: TimeInterval,
    scheduler: DateScheduler
  ) -> Self {
    switch self.operation {
    case .none:
      return .none
    case let .producer(producer):
      return Self(
        operation: .producer(
          SignalProducer<Void, Never>(value: ())
            .delay(dueTime, on: scheduler)
            .flatMap(.latest) { producer.observe(on: scheduler) }
        )
      )
    case let .run(priority, operation):
      return Self(
        operation: .run(priority) { send in
          do {
            try await scheduler.sleep(for: .nanoseconds(Int(dueTime * TimeInterval(NSEC_PER_SEC))))
            await operation(send)
          } catch {}
        }
      )
    }
  }
}
