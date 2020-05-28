import Foundation
import Dispatch
import ReactiveSwift

extension Effect {
  /// Turns an effect into one that can be throttled.
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - interval: The interval at which to find and emit the most recent element, expressed in
  ///     the time system of the scheduler.
  ///   - scheduler: The scheduler you want to deliver the throttled output to.
  ///   - latest: A boolean value that indicates whether to publish the most recent element. If
  ///     `false`, the publisher emits the first element received during the interval.
  /// - Returns: An effect that emits either the most-recent or first element received during the
  ///   specified interval.
  func throttle(
    id: AnyHashable,
    interval: TimeInterval, 
    on scheduler: DateScheduler,
    latest: Bool
  ) -> Effect<Value, Error> {
    self.flatMap(.latest) { value -> Effect<Value, Error> in
      guard let throttleTime = throttleTimes[id] as! Date? else {
        throttleTimes[id] = scheduler.currentDate
        throttleValues[id] = nil
        return Effect(value: value)
      }

      guard scheduler.currentDate.timeIntervalSince1970 - throttleTime.timeIntervalSince1970 < interval else {
        throttleTimes[id] = scheduler.currentDate
        throttleValues[id] = nil
        return Effect(value: value)
      }

      let value = latest ? value : (throttleValues[id] as! Value? ?? value)
      throttleValues[id] = value

      return Effect(value: value)
        .delay(
          throttleTime.addingTimeInterval(interval).timeIntervalSince1970 - scheduler.currentDate.timeIntervalSince1970,
          on: scheduler
        )
    }
    .cancellable(id: id, cancelInFlight: true)
  }
}

var throttleTimes: [AnyHashable: Any] = [:]
var throttleValues: [AnyHashable: Any] = [:]
