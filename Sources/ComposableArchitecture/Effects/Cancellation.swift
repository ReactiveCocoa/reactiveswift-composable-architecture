import Foundation
import ReactiveSwift

extension AnyDisposable: Hashable {
  public static func == (lhs: AnyDisposable, rhs: AnyDisposable) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
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
    let effect = Effect.deferred { () -> SignalProducer<Value, Error> in
      cancellablesLock.lock()
      defer { cancellablesLock.unlock() }

      let subject = Signal<Value, Error>.pipe()

      var values: [Value] = []
      var isCaching = true

      let disposable =
        self
        .on {
          guard isCaching else { return }
          values.append($0)
        }
        .start(subject.input)

      var cancellationDisposable: AnyDisposable!
      cancellationDisposable = AnyDisposable {
        cancellablesLock.sync {
          subject.input.sendCompleted()
          disposable.dispose()
          cancellationCancellables[id]?.remove(cancellationDisposable)
          if cancellationCancellables[id]?.isEmpty == .some(true) {
            cancellationCancellables[id] = nil
          }
        }
      }

      cancellationCancellables[id, default: []].insert(
        cancellationDisposable
      )

      return SignalProducer(values)
        .concat(subject.output.producer)
        .on(
          started: { isCaching = false },
          completed: cancellationDisposable.dispose,
          interrupted: cancellationDisposable.dispose,
          terminated: cancellationDisposable.dispose,
          disposed: cancellationDisposable.dispose
        )
    }

    return cancelInFlight ? .concatenate(.cancel(id: id), effect) : effect
  }

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel(id: AnyHashable) -> Effect {
    return .fireAndForget {
      cancellablesLock.sync {
        cancellationCancellables[id]?.forEach { $0.dispose() }
      }
    }
  }
}

var cancellationCancellables: [AnyHashable: Set<AnyDisposable>] = [:]
let cancellablesLock = NSRecursiveLock()
