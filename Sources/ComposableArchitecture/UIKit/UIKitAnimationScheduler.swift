#if canImport(UIKit) && !os(watchOS)
  import UIKit
  import ReactiveSwift

  extension Scheduler {
    /// Wraps scheduled actions in `UIView.animate`.
    ///
    /// - Parameter duration: The `duration` parameter passed to `UIView.animate`.
    /// - Parameter delay: The `delay` parameter passed to `UIView.animate`.
    /// - Parameter animationOptions: The `options` parameter passed to `UIView.animate`
    /// - Returns: A scheduler that wraps scheduled actions in `UIView.animate`.
    public func animate(
      withDuration duration: TimeInterval,
      delay: TimeInterval = 0,
      options animationOptions: UIView.AnimationOptions = []
    ) -> Scheduler {
      UIKitAnimationScheduler(
        scheduler: self,
        params: .init(
          duration: duration,
          delay: delay,
          options: animationOptions,
          mode: .normal
        )
      )
    }

    /// Wraps scheduled actions in `UIView.animate`.
    ///
    /// - Parameter duration: The `duration` parameter passed to `UIView.animate`.
    /// - Parameter delay: The `delay` parameter passed to `UIView.animate`.
    /// - Parameter dampingRatio: The `dampingRatio` parameter passed to `UIView.animate`
    /// - Parameter velocity: The `velocity` parameter passed to `UIView.animate`
    /// - Parameter animationOptions: The `options` parameter passed to `UIView.animate`
    /// - Returns: A scheduler that wraps scheduled actions in `UIView.animate`.
    public func animate(
      withDuration duration: TimeInterval,
      delay: TimeInterval = 0,
      usingSpringWithDamping dampingRatio: CGFloat,
      initialSpringVelocity velocity: CGFloat,
      options animationOptions: UIView.AnimationOptions
    ) -> Scheduler {
      UIKitAnimationScheduler(
        scheduler: self,
        params: .init(
          duration: duration,
          delay: delay,
          options: animationOptions,
          mode: .spring(dampingRatio: dampingRatio, velocity: velocity)
        )
      )
    }
  }

  extension DateScheduler {
    /// Wraps scheduled actions in `UIView.animate`.
    ///
    /// - Parameter duration: The `duration` parameter passed to `UIView.animate`.
    /// - Parameter delay: The `delay` parameter passed to `UIView.animate`.
    /// - Parameter animationOptions: The `options` parameter passed to `UIView.animate`
    /// - Returns: A scheduler that wraps scheduled actions in `UIView.animate`.
    public func animate(
      withDuration duration: TimeInterval,
      delay: TimeInterval = 0,
      options animationOptions: UIView.AnimationOptions = []
    ) -> DateScheduler {
      UIKitAnimationDateScheduler(
        scheduler: self,
        params: .init(
          duration: duration,
          delay: delay,
          options: animationOptions,
          mode: .normal
        )
      )
    }

    /// Wraps scheduled actions in `UIView.animate`.
    ///
    /// - Parameter duration: The `duration` parameter passed to `UIView.animate`.
    /// - Parameter delay: The `delay` parameter passed to `UIView.animate`.
    /// - Parameter dampingRatio: The `dampingRatio` parameter passed to `UIView.animate`
    /// - Parameter velocity: The `velocity` parameter passed to `UIView.animate`
    /// - Parameter animationOptions: The `options` parameter passed to `UIView.animate`
    /// - Returns: A scheduler that wraps scheduled actions in `UIView.animate`.
    public func animate(
      withDuration duration: TimeInterval,
      delay: TimeInterval = 0,
      usingSpringWithDamping dampingRatio: CGFloat,
      initialSpringVelocity velocity: CGFloat,
      options animationOptions: UIView.AnimationOptions
    ) -> DateScheduler {
      UIKitAnimationDateScheduler(
        scheduler: self,
        params: .init(
          duration: duration,
          delay: delay,
          options: animationOptions,
          mode: .spring(dampingRatio: dampingRatio, velocity: velocity)
        )
      )
    }
  }

  private struct AnimationParams {
    let duration: TimeInterval
    let delay: TimeInterval
    let options: UIView.AnimationOptions
    let mode: Mode

    enum Mode {
      case normal
      case spring(dampingRatio: CGFloat, velocity: CGFloat)
    }
  }

  public final class UIKitAnimationScheduler: Scheduler {
    private let scheduler: Scheduler
    private let params: AnimationParams

    fileprivate init(scheduler: Scheduler, params: AnimationParams) {
      self.scheduler = scheduler
      self.params = params
    }

    public func schedule(_ action: @escaping () -> Void) -> Disposable? {
      scheduler.schedule { [params = self.params] in
        switch params.mode {
        case .normal:
          UIView.animate(
            withDuration: params.duration,
            delay: params.duration,
            options: params.options,
            animations: action
          )
        case let .spring(dampingRatio, velocity):
          UIView.animate(
            withDuration: params.duration,
            delay: params.delay,
            usingSpringWithDamping: dampingRatio,
            initialSpringVelocity: velocity,
            options: params.options,
            animations: action
          )
        }
      }
    }
  }

  public final class UIKitAnimationDateScheduler: DateScheduler {
    public var currentDate: Date {
      scheduler.currentDate
    }

    private let scheduler: DateScheduler
    private let params: AnimationParams

    fileprivate init(scheduler: DateScheduler, params: AnimationParams) {
      self.scheduler = scheduler
      self.params = params
    }

    private func animatedAction(_ action: @escaping () -> Void) -> () -> Void {
      { [params = self.params] in
        switch params.mode {
        case .normal:
          UIView.animate(
            withDuration: params.duration,
            delay: params.duration,
            options: params.options,
            animations: action
          )
        case let .spring(dampingRatio, velocity):
          UIView.animate(
            withDuration: params.duration,
            delay: params.delay,
            usingSpringWithDamping: dampingRatio,
            initialSpringVelocity: velocity,
            options: params.options,
            animations: action
          )
        }
      }
    }

    public func schedule(_ action: @escaping () -> Void) -> Disposable? {
      scheduler.schedule(animatedAction(action))
    }

    public func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
      scheduler.schedule(after: date, action: animatedAction(action))
    }

    public func schedule(
      after date: Date, interval: DispatchTimeInterval, leeway: DispatchTimeInterval,
      action: @escaping () -> Void
    ) -> Disposable? {
      scheduler.schedule(
        after: date, interval: interval, leeway: leeway, action: animatedAction(action))
    }
  }

#endif
