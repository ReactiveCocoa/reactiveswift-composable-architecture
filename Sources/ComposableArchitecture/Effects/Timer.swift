import Foundation
import ReactiveSwift

extension Effect where Value == Date, Error == Never {
  /// Returns an effect that repeatedly emits the current time of the given scheduler on the given
  /// interval.
  ///
  /// This is basically a wrapper around the ReactiveSwift `SignalProducer.timer` function
  /// and which adds the the ability to be cancelled via the `id`.
  ///
  /// To start and stop a timer in your feature you can create the timer effect from an action
  /// and then use the `.cancel(id:)` effect to stop the timer:
  ///
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
  ///
  /// Then to test the timer in this feature you can use a test scheduler to advance time:
  ///
  ///   func testTimer() {
  ///     let scheduler = TestScheduler()
  ///
  ///     let store = TestStore(
  ///       initialState: .init(),
  ///       reducer: appReducer,
  ///       envirnoment: .init(
  ///         mainQueue: scheduler
  ///       )
  ///     )
  ///
  ///     store.send(.startButtonTapped)
  ///
  ///     scheduler.advance(by: .seconds(1))
  ///     store.receive(.timerTicked) { $0.count = 1 }
  ///
  ///     scheduler.advance(by: .seconds(5))
  ///     store.receive(.timerTicked) { $0.count = 2 }
  ///     store.receive(.timerTicked) { $0.count = 3 }
  ///     store.receive(.timerTicked) { $0.count = 4 }
  ///     store.receive(.timerTicked) { $0.count = 5 }
  ///     store.receive(.timerTicked) { $0.count = 6 }
  ///
  ///     store.send(.stopButtonTapped)
  ///   }
  ///
  /// - Parameters:
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
  ) -> Effect<Value, Error> {
    return SignalProducer.timer(
      interval: interval, on: scheduler, leeway: tolerance ?? .seconds(.max)
    )
      .cancellable(id: id, cancelInFlight: true)
  }
}
