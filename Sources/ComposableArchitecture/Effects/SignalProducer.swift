import ReactiveSwift

@available(iOS, deprecated: 9999.0)
@available(macOS, deprecated: 9999.0)
@available(tvOS, deprecated: 9999.0)
@available(watchOS, deprecated: 9999.0)
extension EffectProducer: SignalProducerConvertible {
  @inlinable
  public var producer: SignalProducer<Action, Failure> {
    switch self.operation {
    case .none:
      return .empty
    case let .producer(producer):
      return producer
    case let .run(priority, operation):
      return SignalProducer { observer, lifetime in
        let task = Task(priority: priority) { @MainActor in
          defer { observer.sendCompleted() }
          let send = Send { observer.send(value: $0) }
          await operation(send)
        }
        lifetime += AnyDisposable {
          task.cancel()
        }
      }
    }
  }
}

extension EffectProducer {
  /// Initializes an effect that wraps a producer.
  ///
  /// > Important: This ReactiveSwift interface has been soft-deprecated in favor of Swift concurrency.
  /// > Prefer performing asynchronous work directly in
  /// > ``EffectProducer/run(priority:operation:catch:file:fileID:line:)`` by adopting a
  /// > non-ReactiveSwift interface, or by iterating over the producer's asynchronous sequence of
  /// > `values`:
  /// >
  /// > ```swift
  /// > return .run { send in
  /// >   for await value in producer.values {
  /// >     send(.response(value))
  /// >   }
  /// > }
  /// > ```
  ///
  /// - Parameter producer: A `SignalProducer`.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  public init<P: SignalProducerConvertible>(_ producer: P)
  where P.Value == Action, P.Error == Failure {
    self.operation = .producer(producer.producer)
  }

  /// Initializes an effect that immediately emits the value passed in.
  ///
  /// - Parameter value: The value that is immediately emitted by the effect.
  @available(iOS, deprecated: 9999.0, message: "Wrap the value in 'EffectTask.task', instead.")
  @available(macOS, deprecated: 9999.0, message: "Wrap the value in 'EffectTask.task', instead.")
  @available(tvOS, deprecated: 9999.0, message: "Wrap the value in 'EffectTask.task', instead.")
  @available(watchOS, deprecated: 9999.0, message: "Wrap the value in 'EffectTask.task', instead.")
  public init(value: Action) {
    self.init(SignalProducer(value: value))
  }

  /// Initializes an effect that immediately fails with the error passed in.
  ///
  /// - Parameter error: The error that is immediately emitted by the effect.
  @available(
    iOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  public init(error: Failure) {
    // NB: Ideally we'd return a `Fail` producer here, but due to a bug in iOS 13 that producer
    //     can crash when used with certain combinations of operators such as `.retry.catch`. The
    //     bug was fixed in iOS 14, but to remain compatible with iOS 13 and higher we need to do
    //     a little trickery to fail in a slightly different way.
    self.init(SignalProducer(error: error))
  }

  /// Creates an effect that can supply a single value asynchronously in the future.
  ///
  /// This can be helpful for converting APIs that are callback-based into ones that deal with
  /// ``EffectProducer``s.
  ///
  /// For example, to create an effect that delivers an integer after waiting a second:
  ///
  /// ```swift
  /// EffectProducer<Int, Never>.future { callback in
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
  /// EffectProducer<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///     callback(.success(1729)) // Will not be emitted by the effect
  ///   }
  /// }
  /// ```
  ///
  ///  If you need to deliver more than one value to the effect, you should use the
  ///  ``EffectProducer`` initializer that accepts a ``Subscriber`` value.
  ///
  /// - Parameter attemptToFulfill: A closure that takes a `callback` as an argument which can be
  ///   used to feed it `Result<Action, Failure>` values.
  @available(iOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(macOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(tvOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(watchOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  public static func future(
    _ attemptToFulfill: @escaping (@escaping (Result<Action, Failure>) -> Void) -> Void
  ) -> Self {
    let dependencies = DependencyValues._current
    return SignalProducer.deferred {
      DependencyValues.$_current.withValue(dependencies) {
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
    }
    .eraseToEffect()
  }

  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// EffectProducer<User, Error>.result {
  ///   let fileUrl = URL(
  ///     fileURLWithPath: NSSearchPathForDirectoriesInDomains(
  ///       .documentDirectory, .userDomainMask, true
  ///     )[0]
  ///   )
  ///   .appendingPathComponent("user.json")
  ///
  ///   let result = Result<User, Error> {
  ///     let data = try Data(contentsOf: fileUrl)
  ///     return try JSONDecoder().decode(User.self, from: $0)
  ///   }
  ///
  ///   return result
  /// }
  /// ```
  ///
  /// - Parameter attemptToFulfill: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  @available(iOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(macOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(tvOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  @available(watchOS, deprecated: 9999.0, message: "Use 'EffectTask.task', instead.")
  public static func result(_ attemptToFulfill: @escaping () -> Result<Action, Failure>) -> Self {
    .future { $0(attemptToFulfill()) }
  }

  /// Initializes an effect from a callback that can send as many values as it wants, and can send
  /// a completion.
  ///
  /// This initializer is useful for bridging callback APIs, delegate APIs, and manager APIs to the
  /// ``EffectProducer`` type. One can wrap those APIs in an Effect so that its events are sent
  /// through the effect, which allows the reducer to handle them.
  ///
  /// For example, one can create an effect to ask for access to `MPMediaLibrary`. It can start by
  /// sending the current status immediately, and then if the current status is `notDetermined` it
  /// can request authorization, and once a status is received it can send that back to the effect:
  ///
  /// ```swift
  /// EffectProducer.run { subscriber in
  ///   subscriber.send(MPMediaLibrary.authorizationStatus())
  ///
  ///   guard MPMediaLibrary.authorizationStatus() == .notDetermined else {
  ///     observer.sendCompleted()
  ///     return AnyDisposable {}
  ///   }
  ///
  ///   MPMediaLibrary.requestAuthorization { status in
  ///     observer.send(value: status)
  ///     observer.sendCompleted()
  ///   }
  ///   return AnyDisposable {
  ///     // Typically clean up resources that were created here, but this effect doesn't
  ///     // have any.
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter work: A closure that accepts an ``Observer`` value and returns a disposable.
  ///   When the ``EffectProducer`` is completed, the disposable will be used to clean up any
  ///   resources created when the effect was started.
  @available(
    iOS, deprecated: 9999.0, message: "Use the async version of 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0, message: "Use the async version of 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0, message: "Use the async version of 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0, message: "Use the async version of 'Effect.run', instead."
  )
  public static func run(
    _ work: @escaping (Signal<Action, Failure>.Observer) -> Disposable
  ) -> Self {
    let dependencies = DependencyValues._current
    return SignalProducer<Action, Failure> { observer, lifetime in
      lifetime += DependencyValues.$_current.withValue(dependencies) {
        work(observer)
      }
    }
    .eraseToEffect()
  }

  /// Creates an effect that executes some work in the real world that doesn't need to feed data
  /// back into the store. If an error is thrown, the effect will complete and the error will be
  /// ignored.
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  @available(iOS, deprecated: 9999.0, message: "Use the async version, instead.")
  @available(macOS, deprecated: 9999.0, message: "Use the async version, instead.")
  @available(tvOS, deprecated: 9999.0, message: "Use the async version, instead.")
  @available(watchOS, deprecated: 9999.0, message: "Use the async version, instead.")
  public static func fireAndForget(_ work: @escaping () throws -> Void) -> Self {
    let dependencies = DependencyValues._current
    return SignalProducer.deferred {
      DependencyValues.$_current.withValue(dependencies) {
        SignalProducer { observer, lifetime in
          try? work()
          observer.sendCompleted()
        }
      }
    }
    .eraseToEffect()
  }
}

extension EffectProducer where Failure == Swift.Error {
  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// EffectProducer<User, Error>.catching {
  ///   let fileUrl = URL(
  ///     fileURLWithPath: NSSearchPathForDirectoriesInDomains(
  ///       .documentDirectory, .userDomainMask, true
  ///     )[0]
  ///   )
  ///   .appendingPathComponent("user.json")
  ///
  ///   let data = try Data(contentsOf: fileUrl)
  ///   return try JSONDecoder().decode(User.self, from: $0)
  /// }
  /// ```
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  @available(
    iOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Throw and catch errors directly in 'EffectTask.task' and 'EffectTask.run', instead."
  )
  public static func catching(_ work: @escaping () throws -> Action) -> Self {
    .future { $0(Result { try work() }) }
  }
}

extension Effect {

  /// Turns any effect into an ``Effect`` for any output and failure type by ignoring all output
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
  @available(iOS, deprecated: 9999.0, message: "Use the static async version, instead.")
  @available(macOS, deprecated: 9999.0, message: "Use the static async version, instead.")
  @available(tvOS, deprecated: 9999.0, message: "Use the static async version, instead.")
  @available(watchOS, deprecated: 9999.0, message: "Use the static async version, instead.")
  public func fireAndForget<NewValue, NewError>(
    outputType: NewValue.Type = NewValue.self,
    failureType: NewError.Type = NewError.self
  ) -> Effect<NewValue, NewError> {
    self
      .producer
      .flatMapError { _ in .empty }
      .flatMap(.latest) { _ in .empty }
      .eraseToEffect()
  }
}

extension SignalProducer {
  /// Turns any producer into an ``EffectProducer``.
  ///
  /// This can be useful for when you perform a chain of producer transformations in a reducer, and
  /// you need to convert that producer to an effect so that you can return it from the reducer:
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return fetchUser(id: 1)
  ///     .filter(\.isAdmin)
  ///     .eraseToEffect()
  /// ```
  ///
  /// - Returns: An effect that wraps `self`.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  public func eraseToEffect() -> EffectProducer<Value, Error> {
    EffectProducer(self)
  }

  /// Turns any producer into an ``EffectProducer``.
  ///
  /// This is a convenience operator for writing ``EffectProducer/eraseToEffect()`` followed by
  /// ``EffectProducer/map(_:)-28ghh`.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return fetchUser(id: 1)
  ///     .filter(\.isAdmin)
  ///     .eraseToEffect(ProfileAction.adminUserFetched)
  /// ```
  ///
  /// - Parameters:
  ///   - transform: A mapping function that converts `Value` to another type.
  /// - Returns: An effect that wraps `self` after mapping `Value` values.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  public func eraseToEffect<T>(
    _ transform: @escaping (Value) -> T
  ) -> EffectProducer<T, Error> {
    self.map(transform)
      .eraseToEffect()
  }

  /// Turns any producer into an ``EffectTask`` that cannot fail by wrapping its output and failure
  /// in a result.
  ///
  /// This can be useful when you are working with a failing API but want to deliver its data to an
  /// action that handles both success and failure.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return self.apiClient.fetchUser(id: 1)
  ///     .catchToEffect()
  ///     .map(ProfileAction.userResponse)
  /// ```
  ///
  /// - Returns: An effect that wraps `self`.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  public func catchToEffect() -> EffectTask<Result<Value, Error>> {
    self.catchToEffect { $0 }
  }

  /// Turns any producer into an ``EffectTask`` that cannot fail by wrapping its output and failure
  /// into a result and then applying passed in function to it.
  ///
  /// This is a convenience operator for writing ``EffectProducer/eraseToEffect()`` followed by
  /// ``EffectProducer/map(_:)-28ghh`.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return self.apiClient.fetchUser(id: 1)
  ///     .catchToEffect(ProfileAction.userResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - transform: A mapping function that converts `Result<Value,Error>` to another type.
  /// - Returns: An effect that wraps `self`.
  @available(
    iOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Iterate over 'SignalProducer.values' in an 'EffectTask.run', instead."
  )
  public func catchToEffect<T>(
    _ transform: @escaping (Result<Value, Error>) -> T
  ) -> EffectTask<T> {
    let dependencies = DependencyValues._current
    let transform = { action in
      DependencyValues.$_current.withValue(dependencies) {
        transform(action)
      }
    }
    return
      self
      .map { transform(.success($0)) }
      .flatMapError { SignalProducer<T, Never>(value: transform(.failure($0))) }
      .eraseToEffect()
  }

  /// Turns any producer into an ``EffectProducer`` for any output and failure type by ignoring
  /// all output and any failure.
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
  @available(
    iOS, deprecated: 9999.0,
    message:
      "Iterate over 'SignalProducer.values' in the static version of 'Effect.fireAndForget', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message:
      "Iterate over 'SignalProducer.values' in the static version of 'Effect.fireAndForget', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message:
      "Iterate over 'SignalProducer.values' in the static version of 'Effect.fireAndForget', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message:
      "Iterate over 'SignalProducer.values' in the static version of 'Effect.fireAndForget', instead."
  )
  public func fireAndForget<NewOutput, NewFailure>(
    outputType: NewOutput.Type = NewOutput.self,
    failureType: NewFailure.Type = NewFailure.self
  ) -> EffectProducer<NewOutput, NewFailure> {
    return
      self
      .flatMapError { _ in .empty }
      .flatMap(.latest) { _ in .empty }
      .eraseToEffect()
  }
}

extension SignalProducer where Self.Error == Never {

  /// Assigns each element from a ``SignalProducer`` to a property on an object.
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

extension SignalProducer {

  /// A ``SignalProducer`` that waits until it is started before running
  /// the supplied closure to create a new ``SignalProducer``, whose values
  /// are then sent to the subscriber of this effect.
  public static func deferred(_ createProducer: @escaping () -> Self) -> Self {
    SignalProducer<Void, Error>(value: ())
      .flatMap(.merge, createProducer)
  }

  /// Concatenates a variadic list of producers together into a single producer, which runs the producers
  /// one after the other.
  ///
  /// - Parameter effects: A variadic list of producers.
  /// - Returns: A new producer
  public static func concatenate(_ producers: Self...) -> Self {
    .concatenate(producers)
  }

  /// Concatenates a collection of producers together into a single effect, which runs the producers one
  /// after the other.
  ///
  /// - Parameter effects: A collection of producers.
  /// - Returns: A new producer
  public static func concatenate<C: Collection>(_ producers: C) -> Self where C.Element == Self {
    guard let first = producers.first else { return .empty }

    return
      producers
      .dropFirst()
      .reduce(into: first) { producers, producer in
        producers = producers.concat(producer)
      }
  }

  /// Creates a producer that executes some work in the real world that doesn't need to feed data
  /// back into the store. If an error is thrown, the producer will complete and the error will be
  /// ignored.
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  @available(
    iOS, deprecated: 9999.0,
    message: "Use the static async version of 'Effect.fireAndForget', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Use the static async version of 'Effect.fireAndForget', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Use the static async version of 'Effect.fireAndForget', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Use the static async version of 'Effect.fireAndForget', instead."
  )
  public static func fireAndForget(_ work: @escaping () throws -> Void) -> Self {

    SignalProducer { observer, lifetime in
      try? work()
      observer.sendCompleted()
    }
  }
}

// Credits to @Marcocanc, heavily inspired by:
// https://github.com/ReactiveCocoa/ReactiveSwift/tree/swift-concurrency
// https://github.com/ReactiveCocoa/ReactiveSwift/pull/847
#if canImport(_Concurrency) && compiler(>=5.5.2)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, *)
  extension SignalProducerConvertible {
    public var values: AsyncThrowingStream<Value, Swift.Error> {
      AsyncThrowingStream<Value, Swift.Error> { continuation in
        let disposable = producer.start { event in
          switch event {
          case .value(let value):
            continuation.yield(value)
          case .completed,
            .interrupted:
            continuation.finish()
          case .failed(let error):
            continuation.finish(throwing: error)
          }
        }
        continuation.onTermination = { @Sendable _ in
          disposable.dispose()
        }
      }
    }
  }

  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, *)
  extension SignalProducerConvertible where Error == Never {
    public var values: AsyncStream<Value> {
      AsyncStream<Value> { continuation in
        let disposable = producer.start { event in
          switch event {
          case .value(let value):
            continuation.yield(value)
          case .completed,
            .interrupted:
            continuation.finish()
          case .failed:
            fatalError("Never is impossible to construct")
          }
        }
        continuation.onTermination = { @Sendable _ in
          disposable.dispose()
        }
      }
    }
  }
#endif
