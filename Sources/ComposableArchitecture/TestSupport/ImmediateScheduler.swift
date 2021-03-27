import Foundation
import ReactiveSwift

/// Make `ImmediateScheduler` confirm to `DateScheduler`
/// so that it can be used for testing whenever a `DateScheduler`
/// is expected.
extension ImmediateScheduler: DateScheduler {
  public var currentDate: Date {
    Date(timeIntervalSince1970: 0)
  }

  public func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
    schedule(action)
  }

  public func schedule(after date: Date, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, action: @escaping () -> Void) -> Disposable? {
    schedule(action)
  }
}
