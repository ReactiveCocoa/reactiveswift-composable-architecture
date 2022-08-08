#if DEBUG
  import Foundation
  import ReactiveSwift
  import XCTestDynamicOverlay

  public final class UnimplementedScheduler: DateScheduler {
    public init() {}

    public var currentDate: Date {
      XCTFail(
        """
        An unimplemented scheduler was asked the current time.
        """
      )
      return Date()
    }

    public func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
      XCTFail(
        """
        An unimplemented scheduler scheduled an action to run later.
        """
      )
      return nil
    }

    public func schedule(
      after date: Date, interval: DispatchTimeInterval, leeway: DispatchTimeInterval,
      action: @escaping () -> Void
    ) -> Disposable? {
      XCTFail(
        """
        An unimplemented scheduler scheduled an action to run later.
        """
      )
      return nil
    }

    public func schedule(_ action: @escaping () -> Void) -> Disposable? {
      XCTFail(
        """
        A failing scheduler scheduled an action to run immediately.
        """
      )

      return nil
    }
  }
#endif

#if canImport(_Concurrency) && compiler(>=5.5.2)
  import Foundation
  import ReactiveSwift

  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, *)
  extension DateScheduler {

    /// Suspends the current task for at least the given duration.
    ///
    /// If the task is cancelled before the time ends, this function throws `CancellationError`.
    ///
    /// This function doesn't block the scheduler.
    ///
    /// ```
    /// try await in scheduler.sleep(for: .seconds(1))
    /// ```
    ///
    /// - Parameters:
    ///   - duration: The time interval on which to sleep between yielding.
    ///   - leeway: The allowed timing variance when emitting events. Defaults to `.seconds(0)`.
    public func sleep(
      for interval: DispatchTimeInterval,
      leeway: DispatchTimeInterval = .seconds(0)
    ) async throws {
      try Task.checkCancellation()
      _ = await self.timer(interval: interval, leeway: leeway)
        .first { _ in true }
      try Task.checkCancellation()
    }

    /// Suspend task execution until a given deadline within a tolerance.
    ///
    /// If the task is cancelled before the time ends, this function throws `CancellationError`.
    ///
    /// This function doesn't block the scheduler.
    ///
    /// ```
    /// try await in scheduler.sleep(until: scheduler.now + .seconds(1))
    /// ```
    /// - Parameters:
    ///   - deadline: An instant of time to suspend until.
    ///   - leeway: The allowed timing variance when emitting events. Defaults to `.seconds(0)`.
    public func sleep(
      until deadline: Date,
      leeway: DispatchTimeInterval = .seconds(0)
    ) async throws {
      precondition(deadline > currentDate)
      try await self.sleep(
        for: deadline.timeIntervalSince(currentDate).dispatchTimeInterval,
        leeway: leeway
      )
    }

    /// Returns a stream that repeatedly yields the current time of the scheduler on a given interval.
    ///
    /// If the task is cancelled, the sequence will terminate.
    ///
    /// ```
    /// for await instant in scheduler.timer(interval: .seconds(1)) {
    ///   print("now:", instant)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - interval: The time interval on which to sleep between yielding the current instant in
    ///     time. For example, a value of `0.5` yields an instant approximately every half-second.
    ///   - leeway: The allowed timing variance when emitting events. Defaults to `.seconds(0)`.
    /// - Returns: A stream that repeatedly yields the current time.
    public func timer(
      interval: DispatchTimeInterval,
      leeway: DispatchTimeInterval = .seconds(0)
    ) -> AsyncStream<Date> {
      .init { continuation in
        let disposable = self.schedule(
          after: currentDate.addingTimeInterval(interval.timeInterval),
          interval: interval,
          leeway: leeway
        ) {
          continuation.yield(self.currentDate)
        }
        continuation.onTermination =
          { _ in
            disposable?.dispose()
          }
          // NB: This explicit cast is needed to work around a compiler bug in Swift 5.5.2
          as @Sendable (AsyncStream<Date>.Continuation.Termination) -> Void
      }
    }
  }

  extension DispatchTimeInterval {

    var timeInterval: TimeInterval {
      switch self {
      case let .seconds(s):
        return TimeInterval(s)
      case let .milliseconds(ms):
        return TimeInterval(TimeInterval(ms) / 1000.0)
      case let .microseconds(us):
        return TimeInterval(Int64(us)) * TimeInterval(NSEC_PER_USEC) / TimeInterval(NSEC_PER_SEC)
      case let .nanoseconds(ns):
        return TimeInterval(ns) / TimeInterval(NSEC_PER_SEC)
      case .never:
        return .infinity
      @unknown default:
        return .infinity
      }
    }
  }

  extension TimeInterval {

    var dispatchTimeInterval: DispatchTimeInterval {
      .nanoseconds(Int(self * TimeInterval(NSEC_PER_SEC)))
    }
  }
#endif
