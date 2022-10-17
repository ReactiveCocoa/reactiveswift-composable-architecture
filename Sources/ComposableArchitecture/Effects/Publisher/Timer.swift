import Foundation
import ReactiveSwift

extension EffectProducer where Action == Date, Failure == Never {
  /// Returns an effect that repeatedly emits the current time of the given scheduler on the given
  /// interval.
  ///
  /// This is basically a wrapper around the ReactiveSwift `SignalProducer.timer` function
  /// and which adds the the ability to be cancelled via the `id`.
  ///
  /// That is why we provide `EffectTask.timer`. It allows you to create a timer that works with any
  /// scheduler, not just a run loop, which means you can use a `DispatchQueue` or `RunLoop` when
  /// running your live app, but use a `TestScheduler` in tests.
  ///
  /// To start and stop a timer in your feature you can create the timer effect from an action
  /// and then use the ``EffectProducer/cancel(id:)-6hzsl`` effect to stop the timer:
  ///
  /// ```swift
  /// struct Feature: ReducerProtocol {
  ///   struct State { var count = 0 }
  ///   enum Action { case startButtonTapped, stopButtonTapped, timerTicked }
  ///   @Dependency(\.mainQueue) var mainQueue
  ///   struct TimerID: Hashable {}
  ///
  ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
  ///     switch action {
  ///     case .startButtonTapped:
  ///       return EffectTask.timer(id: TimerID(), every: 1, on: self.mainQueue)
  ///         .map { _ in .timerTicked }
  ///
  ///     case .stopButtonTapped:
  ///       return .cancel(id: TimerID())
  ///
  ///     case .timerTicked:
  ///       state.count += 1
  ///       return .none
  ///   }
  /// }
  /// ```
  ///
  /// Then to test the timer in this feature you can use a test scheduler to advance time:
  ///
  /// ```swift
  /// @MainActor
  /// func testTimer() async {
  ///   let mainQueue = TestScheduler()
  ///
  ///   let store = TestStore(
  ///     initialState: Feature.State(),
  ///     reducer: Feature()
  ///   )
  ///
  ///   store.dependencies.mainQueue = mainQueue
  ///
  ///   await store.send(.startButtonTapped)
  ///
  ///   await mainQueue.advance(by: .seconds(1))
  ///   await store.receive(.timerTicked) { $0.count = 1 }
  ///
  ///   await mainQueue.advance(by: .seconds(5))
  ///   await store.receive(.timerTicked) { $0.count = 2 }
  ///   await store.receive(.timerTicked) { $0.count = 3 }
  ///   await store.receive(.timerTicked) { $0.count = 4 }
  ///   await store.receive(.timerTicked) { $0.count = 5 }
  ///   await store.receive(.timerTicked) { $0.count = 6 }
  ///
  ///   await store.send(.stopButtonTapped)
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - interval: The time interval on which to publish events. For example, a value of `0.5`
  ///     publishes an event approximately every half-second.
  ///   - scheduler: The scheduler on which the timer runs.
  ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which
  ///     allows any variance.
  ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
  @available(
    iOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'EffectTask.run', instead."
  )
  public static func timer(
    id: AnyHashable,
    every interval: DispatchTimeInterval,
    tolerance: DispatchTimeInterval? = nil,
    on scheduler: DateScheduler
  ) -> Self {
    return
      SignalProducer
      .timer(interval: interval, on: scheduler, leeway: tolerance ?? .seconds(.max))
      .eraseToEffect()
      .cancellable(id: id, cancelInFlight: true)
  }

  /// Returns an effect that repeatedly emits the current time of the given scheduler on the given
  /// interval.
  ///
  /// A convenience for calling ``EffectProducer/timer(id:every:tolerance:on:options:)-6yv2m`` with
  /// a static type as the effect's unique identifier.
  ///
  /// - Parameters:
  ///   - id: A unique type identifying the effect.
  ///   - interval: The time interval on which to publish events. For example, a value of `0.5`
  ///     publishes an event approximately every half-second.
  ///   - scheduler: The scheduler on which the timer runs.
  ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which
  ///     allows any variance.
  ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
  @available(
    iOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'EffectTask.run', instead."
  )
  public static func timer(
    id: Any.Type,
    every interval: DispatchTimeInterval,
    tolerance: DispatchTimeInterval? = nil,
    on scheduler: DateScheduler
  ) -> Self {
    self.timer(
      id: ObjectIdentifier(id),
      every: interval,
      tolerance: tolerance,
      on: scheduler
    )
  }
}
