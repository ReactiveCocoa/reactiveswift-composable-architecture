import Foundation
import ReactiveSwift

/// The ``Effect`` type encapsulates a unit of work that can be run in the outside world, and can feed
/// data back to the ``Store``. It is the perfect place to do side effects, such as network requests,
/// saving/loading from disk, creating timers, interacting with dependencies, and more.
///
/// Effects are returned from reducers so that the ``Store`` can perform the effects after the reducer
/// is done running. It is important to note that ``Store`` is not thread safe, and so all effects
/// must receive values on the same thread, **and** if the store is being used to drive UI then it
/// must receive values on the main thread.
///
/// An effect is simply a typealias for a ReactiveSwift `SignalProducer`
public typealias Effect<Value, Error: Swift.Error> = SignalProducer<Value, Error>

extension Effect {
  /// An effect that does nothing and completes immediately. Useful for situations where you must
  /// return an effect, but you don't need to do anything.
  public static var none: Effect {
    .empty
  }

  /// Creates an effect that executes some work in the real world that doesn't need to feed data
  /// back into the store.
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public static func fireAndForget(_ work: @escaping () -> Void) -> Effect {
    .deferred { () -> SignalProducer<Value, Error> in
      work()
      return .empty
    }
  }

  /// Concatenates a variadic list of effects together into a single effect, which runs the effects
  /// one after the other.
  ///
  /// - Parameter effects: A variadic list of effects.
  /// - Returns: A new effect
  public static func concatenate(_ effects: Effect...) -> Effect {
    .concatenate(effects)
  }

  /// Concatenates a collection of effects together into a single effect, which runs the effects one
  /// after the other.
  ///
  /// - Parameter effects: A collection of effects.
  /// - Returns: A new effect
  public static func concatenate<C: Collection>(
    _ effects: C
  ) -> Effect where C.Element == Effect {
    guard let first = effects.first else { return .none }

    return
      effects
      .dropFirst()
      .reduce(into: first) { effects, effect in
        effects = effects.concat(effect)
      }
  }

  /// An ``Effect`` that waits until it is started before running
  /// the supplied closure to create a new ``Effect``, whose values
  /// are then sent to the subscriber of this effect.
  public static func deferred(_ createProducer: @escaping () -> SignalProducer<Value, Error>)
    -> SignalProducer<Value, Error>
  {
    Effect<Void, Error>(value: ())
      .flatMap(.merge, createProducer)
  }

  /// Creates an effect that can supply a single value asynchronously in the future.
  ///
  /// This can be helpful for converting APIs that are callback-based into ones that deal with
  /// ``Effect``s.
  ///
  /// For example, to create an effect that delivers an integer after waiting a second:
  ///
  /// ```swift
  /// Effect<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///   }
  /// }
  /// ```
  ///
  /// Note that you can only deliver a single value to the `callback`. If you send more they will be
  /// discarded:
  ///
  /// ```swift
  /// Effect<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///     callback(.success(1729)) // Will not be emitted by the effect
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter attemptToFulfill: A closure that takes a `callback` as an argument which can be
  ///   used to feed it `Result<Output, Failure>` values.
  public static func future(
    _ attemptToFulfill: @escaping (@escaping (Result<Value, Error>) -> Void) -> Void
  ) -> Effect {
    SignalProducer { observer, _ in
      attemptToFulfill { result in
        switch result {
        case let .success(value):
          observer.send(value: value)
          observer.sendCompleted()
        case let .failure(error):
          observer.send(error: error)
        }
      }
    }
  }

  /// Turns any publisher into an ``Effect`` that cannot fail by wrapping its output and failure in
  /// a result.
  ///
  /// This can be useful when you are working with a failing API but want to deliver its data to an
  /// action that handles both success and failure.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return fetchUser(id: 1)
  ///     .catchToEffect()
  ///     .map(ProfileAction.userResponse)
  /// ```
  ///
  /// - Returns: An effect that wraps `self`.
  public func catchToEffect() -> Effect<Result<Value, Error>, Never> {
    self.map(Result<Value, Error>.success)
      .flatMapError { Effect<Result<Value, Error>, Never>(value: Result.failure($0)) }
  }

  /// Turns any `SignalProducer` into an ``Effect`` for any output and failure type by ignoring all output
  /// and any failure.
  ///
  /// This is useful for times you want to fire off an effect but don't want to feed any data back
  /// into the system. It can automatically promote an effect to your reducer's domain.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return analyticsClient.track("Button Tapped")
  ///     .fireAndForget()
  /// ```
  ///
  /// - Parameters:
  ///   - outputType: An output type.
  ///   - failureType: A failure type.
  /// - Returns: An effect that never produces output or errors.
  public func fireAndForget<NewValue, NewError>(
    outputType: NewValue.Type = NewValue.self,
    failureType: NewError.Type = NewError.self
  ) -> Effect<NewValue, NewError> {
    self.flatMapError { _ in .empty }
      .flatMap(.latest) { _ in
        .empty
      }
  }
}

extension Effect where Self.Error == Never {

  /// Assigns each element from an ``Effect`` to a property on an object.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the property to assign.
  ///   - object: The object on which to assign the value.
  /// - Returns: Disposable instance
  @discardableResult
  public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Self.Value>, on object: Root)
    -> Disposable
  {
    self.startWithValues { value in
      object[keyPath: keyPath] = value
    }
  }
}
