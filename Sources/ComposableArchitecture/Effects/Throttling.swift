import Dispatch
import Foundation
import ReactiveSwift

extension Effect {
  /// Throttles an effect so that it only publishes one output per given interval.
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
<<<<<<< ours:Sources/ComposableArchitecture/Internal/Throttling.swift
  func throttle(
=======
  public func throttle<S>(
>>>>>>> theirs:Sources/ComposableArchitecture/Effects/Throttling.swift
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

<<<<<<< ours:Sources/ComposableArchitecture/Internal/Throttling.swift
      guard
        scheduler.currentDate.timeIntervalSince1970 - throttleTime.timeIntervalSince1970 < interval
      else {
        throttleTimes[id] = scheduler.currentDate
=======
      let value = latest ? value : (throttleValues[id] as! Output? ?? value)
      throttleValues[id] = value

      guard throttleTime.distance(to: scheduler.now) < interval else {
        throttleTimes[id] = scheduler.now
>>>>>>> theirs:Sources/ComposableArchitecture/Effects/Throttling.swift
        throttleValues[id] = nil
        return Effect(value: value)
      }

<<<<<<< ours:Sources/ComposableArchitecture/Internal/Throttling.swift
      let value = latest ? value : (throttleValues[id] as! Value? ?? value)
      throttleValues[id] = value

      return Effect(value: value)
=======
      return Just(value)
>>>>>>> theirs:Sources/ComposableArchitecture/Effects/Throttling.swift
        .delay(
          throttleTime.addingTimeInterval(interval).timeIntervalSince1970
            - scheduler.currentDate.timeIntervalSince1970,
          on: scheduler
        )
<<<<<<< ours:Sources/ComposableArchitecture/Internal/Throttling.swift
=======
        .handleEvents(receiveOutput: { _ in throttleTimes[id] = scheduler.now })
        .setFailureType(to: Failure.self)
        .eraseToAnyPublisher()
>>>>>>> theirs:Sources/ComposableArchitecture/Effects/Throttling.swift
    }
    .cancellable(id: id, cancelInFlight: true)
  }
}

var throttleTimes: [AnyHashable: Any] = [:]
var throttleValues: [AnyHashable: Any] = [:]
