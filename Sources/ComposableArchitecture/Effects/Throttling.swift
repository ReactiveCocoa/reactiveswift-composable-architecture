import Dispatch
import Foundation
import ReactiveSwift

extension Effect {
  /// Throttles an effect so that it only publishes one output per given interval.
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - for: The interval at which to find and emit the most recent element, expressed in
  ///     the time system of the scheduler.
  ///   - scheduler: The scheduler you want to deliver the throttled output to.
  ///   - latest: A boolean value that indicates whether to publish the most recent element. If
  ///     `false`, the producer emits the first element received during the interval.
  /// - Returns: An effect that emits either the most-recent or first element received during the
  ///   specified interval.
  public func throttle(
    id: AnyHashable,
    for interval: TimeInterval,
    scheduler: DateScheduler,
    latest: Bool
  ) -> Self {
    switch self.operation {
    case .none:
      return .none
    case .producer, .run:
      return self.producer
        .observe(on: scheduler)
        .flatMap(.latest) { value -> SignalProducer<Action, Failure> in
          throttleLock.lock()
          defer { throttleLock.unlock() }

          guard let throttleTime = throttleTimes[id] as! Date? else {
            throttleTimes[id] = scheduler.currentDate
            throttleValues[id] = nil
            return SignalProducer(value: value)
          }

          let value = latest ? value : (throttleValues[id] as! Action? ?? value)
          throttleValues[id] = value

          guard
            scheduler.currentDate.timeIntervalSince1970 - throttleTime.timeIntervalSince1970
              < interval
          else {
            throttleTimes[id] = scheduler.currentDate
            throttleValues[id] = nil
            return SignalProducer(value: value)
          }

          return SignalProducer(value: value)
            .delay(
              throttleTime.addingTimeInterval(interval).timeIntervalSince1970
                - scheduler.currentDate.timeIntervalSince1970,
              on: scheduler
            ).on(
              value: { _ in
                throttleLock.sync {
                  throttleTimes[id] = scheduler.currentDate
                  throttleValues[id] = nil
                }
              }
            )
        }
        .eraseToEffect()
        .cancellable(id: id, cancelInFlight: true)
    }
  }

  /// Throttles an effect so that it only publishes one output per given interval.
  ///
  /// A convenience for calling ``Effect/throttle(id:for:scheduler:latest:)-5jfpx`` with a static
  /// type as the effect's unique identifier.
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - interval: The interval at which to find and emit the most recent element, expressed in
  ///     the time system of the scheduler.
  ///   - scheduler: The scheduler you want to deliver the throttled output to.
  ///   - latest: A boolean value that indicates whether to publish the most recent element. If
  ///     `false`, the producer emits the first element received during the interval.
  /// - Returns: An effect that emits either the most-recent or first element received during the
  ///   specified interval.
  public func throttle(
    id: Any.Type,
    for interval: TimeInterval,
    scheduler: DateScheduler,
    latest: Bool
  ) -> Self {
    self.throttle(id: ObjectIdentifier(id), for: interval, scheduler: scheduler, latest: latest)
  }
}

var throttleTimes: [AnyHashable: Any] = [:]
var throttleValues: [AnyHashable: Any] = [:]
let throttleLock = NSRecursiveLock()
