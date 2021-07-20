#if DEBUG
  import Foundation
  import ReactiveSwift
  import XCTestDynamicOverlay

  public final class FailingScheduler: DateScheduler {
    public init() {}

    public var currentDate: Date {
      XCTFail(
        """
        A failing scheduler was asked the current time.
        """
      )
      return Date()
    }

    public func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
      XCTFail(
        """
        A failing scheduler scheduled an action to run later.
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
        A failing scheduler scheduled an action to run later.
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
