import Foundation
import ReactiveSwift

extension Effect {
  /// Turns an effect into one that can be debounced.
  ///
  /// To turn an effect into a debounce-able one you must provide an identifier, which is used to
  /// determine which in-flight effect should be canceled in order to start a new effect. Any
  /// hashable value can be used for the identifier, such as a string, but you can add a bit of
  /// protection against typos by defining a new type that conforms to `Hashable`, such as an empty
  /// struct:
  ///
  /// ```swift
  /// case let .textChanged(text):
  ///   enum SearchID {}
  ///
  ///   return self.apiClient.search(text)
  ///     .debounce(id: SearchID.self, for: 0.5, scheduler: self.mainQueue)
  ///     .map(Action.searchResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - dueTime: The duration you want to debounce for.
  ///   - scheduler: The scheduler you want to deliver the debounced output to.
  /// - Returns: An effect that publishes events only after a specified time elapses.
  @available(
    iOS,
    deprecated: 9999.0,
    message: "Use 'withTaskCancellation(id: _, cancelInFlight: true)' in 'Effect.run', instead."
  )
  @available(
    macOS,
    deprecated: 9999.0,
    message: "Use 'withTaskCancellation(id: _, cancelInFlight: true)' in 'Effect.run', instead."
  )
  @available(
    tvOS,
    deprecated: 9999.0,
    message: "Use 'withTaskCancellation(id: _, cancelInFlight: true)' in 'Effect.run', instead."
  )
  @available(
    watchOS,
    deprecated: 9999.0,
    message: "Use 'withTaskCancellation(id: _, cancelInFlight: true)' in 'Effect.run', instead."
  )
  public func debounce(
    id: AnyHashable,
    for dueTime: TimeInterval,
    scheduler: DateScheduler
  ) -> Self {
    switch self.operation {
    case .none:
      return .none
    case .producer, .run:
      return Self(
        operation: .producer(
          SignalProducer<Void, Never>.init(value: ())
            .promoteError(Failure.self)
            .delay(dueTime, on: scheduler)
            .flatMap(.latest) { self.producer.observe(on: scheduler) }
        )
      )
      .cancellable(id: id, cancelInFlight: true)
    }
  }

  /// Turns an effect into one that can be debounced.
  ///
  /// A convenience for calling ``Effect/debounce(id:for:scheduler:options:)-76yye`` with a static
  /// type as the effect's unique identifier.
  ///
  /// - Parameters:
  ///   - id: A unique type identifying the effect.
  ///   - dueTime: The duration you want to debounce for.
  ///   - scheduler: The scheduler you want to deliver the debounced output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that publishes events only after a specified time elapses.
  public func debounce(
    id: Any.Type,
    for dueTime: TimeInterval,
    scheduler: DateScheduler
  ) -> Self {
    self.debounce(id: ObjectIdentifier(id), for: dueTime, scheduler: scheduler)
  }
}