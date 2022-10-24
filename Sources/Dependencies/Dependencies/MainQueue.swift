  import Foundation
import ReactiveSwift
import XCTestDynamicOverlay

  extension DependencyValues {
    /// The "main" queue.
    ///
    /// Introduce controllable timing to your features by using the ``Dependency`` property wrapper
  /// with a key path to this property. The wrapped value is a ReactiveSwift scheduler with the time
    /// type and options of a dispatch queue. By default, `DispatchQueue.main` will be provided,
    /// with the exception of XCTest cases, in which an "unimplemented" scheduler will be provided.
    ///
    /// For example, you could introduce controllable timing to a Composable Architecture reducer
    /// that counts the number of seconds it's onscreen:
    ///
    /// ```
    /// struct TimerReducer: ReducerProtocol {
    ///   struct State {
    ///     var elapsed = 0
    ///   }
    ///
    ///   enum Action {
    ///     case task
    ///     case timerTicked
    ///   }
    ///
    ///   @Dependency(\.mainQueue) var mainQueue
    ///
    ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    ///     switch action {
    ///     case .task:
    ///       return .run { send in
    ///         for await _ in self.mainQueue.timer(interval: .seconds(1)) {
    ///           send(.timerTicked)
    ///         }
    ///       }
    ///
    ///     case .timerTicked:
    ///       state.elapsed += 1
    ///       return .none
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// And you could test this reducer by overriding its main queue with a test scheduler:
    ///
    /// ```
  /// let mainQueue = TestScheduler()
    ///
    /// let store = TestStore(
    ///   initialState: TimerReducer.State()
    ///   reducer: TimerReducer()
  ///     .dependency(\.mainQueue, mainQueue)
    /// )
    ///
    /// let task = store.send(.task)
    ///
    /// mainQueue.advance(by: .seconds(1)
    /// await store.receive(.timerTicked) {
    ///   $0.elapsed = 1
    /// }
    /// mainQueue.advance(by: .seconds(1)
    /// await store.receive(.timerTicked) {
    ///   $0.elapsed = 2
    /// }
    /// await task.cancel()
    /// ```
    @available(
      iOS, deprecated: 9999.0, message: "Use '\\.continuousClock' or '\\.suspendingClock' instead."
    )
    @available(
      macOS, deprecated: 9999.0,
      message: "Use '\\.continuousClock' or '\\.suspendingClock' instead."
    )
    @available(
      tvOS,
      deprecated: 9999.0,
      message: "Use '\\.continuousClock' or '\\.suspendingClock' instead."
    )
    @available(
      watchOS,
      deprecated: 9999.0,
      message: "Use '\\.continuousClock' or '\\.suspendingClock' instead."
    )
    public var mainQueue: DateScheduler {
      get { self[MainQueueKey.self] }
      set { self[MainQueueKey.self] = newValue }
    }

    private enum MainQueueKey: DependencyKey {
    static let liveValue = QueueScheduler.main as DateScheduler
    static let testValue = UnimplementedScheduler() as DateScheduler
    }
  }

public final class UnimplementedScheduler: DateScheduler {

  public var currentDate: Date {
    XCTFail(
      """
      \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
      An unimplemented scheduler was asked its current date.
      """
    )
    return _now
  }

  public let prefix: String
  private let _now: Date

  public init(_ prefix: String = "", now: Date = .init(timeIntervalSinceReferenceDate: 0)) {
    self._now = now
    self.prefix = prefix
  }

  public func schedule(_ action: @escaping () -> Void) -> Disposable? {
    XCTFail(
      """
      \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
      An unimplemented scheduler scheduled an action to run immediately.
      """
    )
    return nil
  }

  public func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
    XCTFail(
      """
      \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
      An unimplemented scheduler scheduled an action to run later.
      """
    )
    return nil
  }

  public func schedule(
    after date: Date,
    interval: DispatchTimeInterval,
    leeway: DispatchTimeInterval,
    action: @escaping () -> Void
  ) -> Disposable? {
    XCTFail(
      """
      \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
      An unimplemented scheduler scheduled an action to run on a timer.
      """
    )
    return nil
  }
}
