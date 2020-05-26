import ReactiveSwift
import Foundation

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
      let uuid = UUID()

      var isCleaningUp = false
      var cancellable: Disposable?
      
      cancellablesLock.sync {
        if cancelInFlight {
          cancellationCancellables[id]?.forEach { _, cancellable in cancellable.dispose() }
          cancellationCancellables[id] = nil
        }

        cancellable = self.start(subject.input)

        cancellationCancellables[id] = cancellationCancellables[id] ?? [:]
        cancellationCancellables[id]?[uuid] = AnyDisposable {
          cancellable?.dispose()
          if !isCleaningUp {
            subject.input.sendCompleted()
          }
        }
      }

      func cleanup() {
        cancellable?.dispose()
        isCleaningUp = true
        cancellablesLock.sync {                    
          cancellationCancellables[id]?[uuid] = nil
          if cancellationCancellables[id]?.isEmpty == true {
            cancellationCancellables[id] = nil
          }
        }
      }

      return subject.output.on(
        completed: cleanup, 
        interrupted: cleanup, 
        terminated: cleanup, 
        disposed: cleanup
      ).producer
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
        cancellationCancellables[id]?.forEach { _, cancellable in cancellable.dispose() }
        cancellationCancellables[id] = nil
      }
    }
  }
}

var cancellationCancellables: [AnyHashable: [UUID: Disposable]] = [:]
let cancellablesLock = NSRecursiveLock()
