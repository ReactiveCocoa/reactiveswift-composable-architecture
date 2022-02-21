import ReactiveSwift
#if canImport(_Concurrency) && compiler(>=5.5.2)
  extension Effect {
    /// Wraps an asynchronous unit of work in an effect.
    ///
    /// This function is useful for executing work in an asynchronous context and capture the
    /// result in an ``Effect`` so that the reducer, a non-asynchronous context, can process it.
    ///
    /// ```swift
    /// Effect.task {
    ///   guard case let .some((data, _)) = try? await URLSession.shared
    ///     .data(from: .init(string: "http://numbersapi.com/42")!)
    ///   else {
    ///     return "Could not load"
    ///   }
    ///
    ///   return String(decoding: data, as: UTF8.self)
    /// }
    /// ```
    ///
    /// Note that due to the lack of tools to control the execution of asynchronous work in Swift,
    /// it is not recommended to use this function in reducers directly. Doing so will introduce
    /// thread hops into your effects that will make testing difficult. You will be responsible
    /// for adding explicit expectations to wait for small amounts of time so that effects can
    /// deliver their output.
    ///
    /// Instead, this function is most helpful for calling `async`/`await` functions from the live
    /// implementation of dependencies, such as `URLSession.data`, `MKLocalSearch.start` and more.
    ///
    /// - Parameters:
    ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
    ///     `Task.currentPriority`.
    ///   - operation: The operation to execute.
    /// - Returns: An effect wrapping the given asynchronous work.
    public static func task(
      priority: TaskPriority? = nil,
      operation: @escaping @Sendable () async -> Value
    ) -> Self where Error == Never {
      var task: Task<Void, Never>?
      return .future { callback in
        task = Task(priority: priority) {
          guard !Task.isCancelled else { return }
          let output = await operation()
          guard !Task.isCancelled else { return }
          callback(.success(output))
        }
      }
      .on(disposed: { task?.cancel() })
    }

    /// Wraps an asynchronous unit of work in an effect.
    ///
    /// This function is useful for executing work in an asynchronous context and capture the
    /// result in an ``Effect`` so that the reducer, a non-asynchronous context, can process it.
    ///
    /// ```swift
    /// Effect.task {
    ///   let (data, _) = try await URLSession.shared
    ///     .data(from: .init(string: "http://numbersapi.com/42")!)
    ///
    ///   return String(decoding: data, as: UTF8.self)
    /// }
    /// ```
    ///
    /// Note that due to the lack of tools to control the execution of asynchronous work in Swift,
    /// it is not recommended to use this function in reducers directly. Doing so will introduce
    /// thread hops into your effects that will make testing difficult. You will be responsible
    /// for adding explicit expectations to wait for small amounts of time so that effects can
    /// deliver their output.
    ///
    /// Instead, this function is most helpful for calling `async`/`await` functions from the live
    /// implementation of dependencies, such as `URLSession.data`, `MKLocalSearch.start` and more.
    ///
    /// - Parameters:
    ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
    ///     `Task.currentPriority`.
    ///   - operation: The operation to execute.
    /// - Returns: An effect wrapping the given asynchronous work.
    public static func task(
      priority: TaskPriority? = nil,
      operation: @escaping @Sendable () async throws -> Value
    ) -> Self where Error == Swift.Error {
      deferred {
        var task: Task<(), Never>?
        let producer = SignalProducer { observer, lifetime in
          task = Task(priority: priority) {
            do {
              try Task.checkCancellation()
              let output = try await operation()
              try Task.checkCancellation()
              observer.send(value: output)
              observer.sendCompleted()
            } catch is CancellationError {
              observer.sendCompleted()
            } catch {
              observer.send(error: error)
            }
          }
        }

        return producer.on(disposed: task?.cancel)
      }
    }
  }
#endif
