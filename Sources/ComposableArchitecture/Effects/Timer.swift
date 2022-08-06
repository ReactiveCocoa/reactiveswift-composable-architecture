import Foundation
import ReactiveSwift

extension Effect where Value == Date, Error == Never {
  /// Returns an effect that repeatedly emits the current time of the given scheduler on the given
  /// interval.
  ///
  /// This is basically a wrapper around the ReactiveSwift `SignalProducer.timer` function
  /// and which adds the the ability to be cancelled via the `id`.
  ///
  /// That is why we provide `Effect.timer`. It allows you to create a timer that works with any
  /// scheduler, not just a run loop, which means you can use a `DispatchQueue` or `RunLoop` when
  /// running your live app, but use a `TestScheduler` in tests.
  ///
  /// To start and stop a timer in your feature you can create the timer effect from an action
  /// and then use the ``Effect/cancel(id:)-iun1`` effect to stop the timer:
  ///
  ///    ```swift
  ///     struct AppState {
  ///       var count = 0
  ///     }
  ///
  ///     enum AppAction {
  ///       case startButtonTapped, stopButtonTapped, timerTicked
  ///     }
  ///
  ///     struct AppEnvironment {
  ///       var mainQueue: AnySchedulerOf<DispatchQueue>
  ///     }
  ///
  ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
  ///       struct TimerId: Hashable {}
  ///
  ///       switch action {
  ///       case .startButtonTapped:
  ///         return Effect.timer(id: TimerId(), every: 1, on: env.mainQueue)
  ///           .map { _ in .timerTicked }
  ///
  ///       case .stopButtonTapped:
  ///         return .cancel(id: TimerId())
  ///
  ///       case let .timerTicked:
  ///         state.count += 1
  ///         return .none
  ///     }
  ///    ```
  ///
  /// Then to test the timer in this feature you can use a test scheduler to advance time:
  ///
  ///    ```swift
  ///     func testTimer() {
  ///       let mainQueue = TestScheduler()
  ///
  ///       let store = TestStore(
  ///         initialState: .init(),
  ///         reducer: appReducer,
  ///     environment: .init(
  ///           mainQueue: mainQueue
  ///         )
  ///       )
  ///
  ///       store.send(.startButtonTapped)
  ///
  ///       mainQueue.advance(by: 1)
  ///       store.receive(.timerTicked) { $0.count = 1 }
  ///
  ///       mainQueue.advance(by: 5)
  ///       store.receive(.timerTicked) { $0.count = 2 }
  ///       store.receive(.timerTicked) { $0.count = 3 }
  ///       store.receive(.timerTicked) { $0.count = 4 }
  ///       store.receive(.timerTicked) { $0.count = 5 }
  ///       store.receive(.timerTicked) { $0.count = 6 }
  ///
  ///       store.send(.stopButtonTapped)
  ///     }
  ///    ```
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - interval: The time interval on which to publish events. For example, a value of `0.5`
  ///     publishes an event approximately every half-second.
  ///   - scheduler: The scheduler on which the timer runs.
  ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which
  ///     allows any variance.
  ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
  public static func timer(
    id: AnyHashable,
    every interval: DispatchTimeInterval,
    tolerance: DispatchTimeInterval? = nil,
    on scheduler: DateScheduler
  ) -> Self {
    return SignalProducer.timer(
      interval: interval, on: scheduler, leeway: tolerance ?? .seconds(.max)
    )
    .cancellable(id: id, cancelInFlight: true)
  }

  /// Returns an effect that repeatedly emits the current time of the given scheduler on the given
  /// interval.
  ///
  /// A convenience for calling ``Effect/timer(id:every:tolerance:on:options:)-4exe6`` with a
  /// static type as the effect's unique identifier.
  ///
  /// - Parameters:
  ///   - id: A unique type identifying the effect.
  ///   - interval: The time interval on which to publish events. For example, a value of `0.5`
  ///     publishes an event approximately every half-second.
  ///   - scheduler: The scheduler on which the timer runs.
  ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which
  ///     allows any variance.
  ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
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
