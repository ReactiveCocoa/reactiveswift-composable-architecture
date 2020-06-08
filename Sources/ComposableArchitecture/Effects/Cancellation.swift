import Foundation
import ReactiveSwift

extension Disposable {
  /// Adds this Disposable to the specified CompositeDisposable
  /// Parameters:
  ///    - composite: The CompositeDisposable to which to add this Disposable.
  internal func add(to composite: inout CompositeDisposable) {
    composite.add(self)
  }
}

extension Effect {
  /// Turns an effect into one that is capable of being canceled.
  ///
  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
  /// `Effect.cancel(id:)` to identify which in-flight effect should be canceled. Any hashable
  /// value can be used for the identifier, such as a string, but you can add a bit of protection
  /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
  ///
  ///     struct LoadUserId: Hashable {}
  ///
  ///     case .reloadButtonTapped:
  ///       // Start a new effect to load the user
  ///       return environment.loadUser
  ///         .map(Action.userResponse)
  ///         .cancellable(id: LoadUserId(), cancelInFlight: true)
  ///
  ///     case .cancelButtonTapped:
  ///       // Cancel any in-flight requests to load the user
  ///       return .cancel(id: LoadUserId())
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: A new effect that is capable of being canceled by an identifier.
  public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> Effect {
    return .deferred { () -> SignalProducer<Value, Error> in
      let subject = Signal<Value, Error>.pipe()

      var values: [Value] = []
      var isCaching = true

      cancellablesLock.sync {
        if cancelInFlight {
          cancellationCancellables[id]?.dispose()
          cancellationCancellables[id] = nil
        }

        let disposable =
          self
          .on {
            guard isCaching else { return }
            values.append($0)
          }
          .start(subject.input)

        disposable.add(to: &cancellationCancellables[id, default: CompositeDisposable()])
      }

      func cleanUp() {
        cancellablesLock.sync {
          guard !isCancelling.contains(id) else { return }
          isCancelling.insert(id)
          defer { isCancelling.remove(id) }

          cancellationCancellables[id]?.dispose()
          cancellationCancellables[id] = nil
        }
      }

      let prefix = SignalProducer(values)
      let output = subject.output.producer
        .on(
          started: { isCaching = false },
          completed: cleanUp,
          interrupted: cleanUp,
          terminated: cleanUp,
          disposed: cleanUp
        )

      return prefix.concat(output)
    }
  }

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel(id: AnyHashable) -> Effect {
    .fireAndForget {
      cancellablesLock.sync {
        cancellationCancellables[id]?.dispose()
        cancellationCancellables[id] = nil
      }
    }
  }
}

var cancellationCancellables: [AnyHashable: CompositeDisposable] = [:]
let cancellablesLock = NSRecursiveLock()
var isCancelling: Set<AnyHashable> = []
