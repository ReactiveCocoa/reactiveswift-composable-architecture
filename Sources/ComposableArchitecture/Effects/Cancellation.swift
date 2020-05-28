import ReactiveSwift
import Foundation

extension AnyDisposable: Hashable {
  public static func == (lhs: AnyDisposable, rhs: AnyDisposable) -> Bool {
      return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }

  public func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self))
  }
}

extension AnyDisposable {
    /// Stores this AnyDisposable in the specified collection.
    /// Parameters:
    ///    - collection: The collection to store this AnyCancellable.
    public func store<Disposables: RangeReplaceableCollection>(
        in collection: inout Disposables
    ) where Disposables.Element == AnyDisposable {
        collection.append(self)
    }

    /// Stores this AnyCancellable in the specified set.
    /// Parameters:
    ///    - set: The set to store this AnyCancellable.
    public func store(in set: inout Set<AnyDisposable>) {
        set.insert(self)
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

      var disposable: Disposable?
      var values: [Value] = []
      var isCaching = true

      cancellablesLock.sync {
        if cancelInFlight {
          cancellationCancellables[id]?.forEach { cancellable in cancellable.dispose() }
          cancellationCancellables[id] = nil
        }

        disposable = self
          .on {
            guard isCaching else { return }
            values.append($0)
          }
          .start(subject.input)

        AnyDisposable {
          disposable?.dispose()
          subject.input.sendCompleted()
        }
        .store(in: &cancellationCancellables[id, default: []])
      }

      func cleanUp() {
        disposable?.dispose()
        cancellablesLock.sync {
          guard !isCancelling.contains(id) else { return }
          isCancelling.insert(id)
          defer { isCancelling.remove(id) }
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
        cancellationCancellables[id]?.forEach { cancellable in cancellable.dispose() }
        cancellationCancellables[id] = nil
      }
    }
  }
}

var cancellationCancellables: [AnyHashable: Set<AnyDisposable>] = [:]
let cancellablesLock = NSRecursiveLock()
var isCancelling: Set<AnyHashable> = []
