#if canImport(SwiftUI)
  import SwiftUI
  import ReactiveSwift

  extension Scheduler {
    /// Specifies an animation to perform when an action is scheduled.
    ///
    /// - Parameter animation: An animation to be performed.
    /// - Returns: A scheduler that performs an animation when a scheduled action is run.
    public func animation(_ animation: Animation? = .default) -> Scheduler {
      ActionWrappingScheduler(scheduler: self, wrapper: .animation(animation))
    }

    /// Wraps scheduled actions in a transaction.
    ///
    /// - Parameter transaction: A transaction.
    /// - Returns: A scheduler that wraps scheduled actions in a transaction.
    public func transaction(_ transaction: Transaction) -> Scheduler {
      ActionWrappingScheduler(scheduler: self, wrapper: .transaction(transaction))
    }
  }

  extension DateScheduler {
    /// Specifies an animation to perform when an action is scheduled.
    ///
    /// - Parameter animation: An animation to be performed.
    /// - Returns: A scheduler that performs an animation when a scheduled action is run.
    public func animation(_ animation: Animation? = .default) -> DateScheduler {
      ActionWrappingDateScheduler(scheduler: self, wrapper: .animation(animation))
    }

    /// Wraps scheduled actions in a transaction.
    ///
    /// - Parameter transaction: A transaction.
    /// - Returns: A scheduler that wraps scheduled actions in a transaction.
    public func transaction(_ transaction: Transaction) -> DateScheduler {
      ActionWrappingDateScheduler(scheduler: self, wrapper: .transaction(transaction))
    }
  }

  private enum ActionWrapper {
    case animation(Animation?)
    case transaction(Transaction)
  }

  public final class ActionWrappingScheduler: Scheduler {
    private let scheduler: Scheduler
    private let wrapper: ActionWrapper

    fileprivate init(scheduler: Scheduler, wrapper: ActionWrapper) {
      self.scheduler = scheduler
      self.wrapper = wrapper
    }

    public func schedule(_ action: @escaping () -> Void) -> Disposable? {
      scheduler.schedule {
        switch self.wrapper {
        case let .animation(animation):
          withAnimation(animation, action)
        case let .transaction(transaction):
          withTransaction(transaction, action)
        }
      }
    }
  }

  public final class ActionWrappingDateScheduler: DateScheduler {
    public var currentDate: Date {
      scheduler.currentDate
    }

    private let scheduler: DateScheduler
    private let wrapper: ActionWrapper

    fileprivate init(scheduler: DateScheduler, wrapper: ActionWrapper) {
      self.scheduler = scheduler
      self.wrapper = wrapper
    }

    public func schedule(_ action: @escaping () -> Void) -> Disposable? {
      scheduler.schedule {
        switch self.wrapper {
        case let .animation(animation):
          withAnimation(animation, action)
        case let .transaction(transaction):
          withTransaction(transaction, action)
        }
      }
    }

    public func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
      scheduler.schedule(after: date) {
        switch self.wrapper {
        case let .animation(animation):
          withAnimation(animation, action)
        case let .transaction(transaction):
          withTransaction(transaction, action)
        }
      }
    }

    public func schedule(
      after date: Date, interval: DispatchTimeInterval, leeway: DispatchTimeInterval,
      action: @escaping () -> Void
    ) -> Disposable? {
      scheduler.schedule(after: date, interval: interval, leeway: leeway) {
        switch self.wrapper {
        case let .animation(animation):
          withAnimation(animation, action)
        case let .transaction(transaction):
          withTransaction(transaction, action)
        }
      }
    }
  }
#endif
