import Foundation
import ReactiveSwift

extension Effect {
  /// Returns an effect that will be executed after given `dueTime`.
  ///
  /// ```swift
  /// case let .textChanged(text):
  ///   return environment.search(text)
  ///     .map(Action.searchResponse)
  ///     .deferred(for: 0.5, scheduler: environment.mainQueue)
  /// ```
  ///
  /// - Parameters:
  ///   - upstream: the effect you want to defer.
  ///   - dueTime: The duration you want to defer for.
  ///   - scheduler: The scheduler you want to deliver the defer output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that will be executed after `dueTime`
  public func deferred(
    for dueTime: TimeInterval,
    scheduler: DateScheduler
  ) -> Effect<Value, Error> {
    SignalProducer<Void, Never>(value: ())
      .delay(dueTime, on: scheduler)
      .flatMap(.latest) { self }
  }
}
