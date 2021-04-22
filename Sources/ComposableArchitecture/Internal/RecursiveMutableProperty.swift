import Foundation
import ReactiveSwift

extension Signal.Observer {
  internal convenience init(mappingInterruptedToCompleted observer: Signal<Value, Error>.Observer) {
    self.init { event in
      switch event {
      case .value, .completed, .failed:
        observer.send(event)
      case .interrupted:
        observer.sendCompleted()
      }
    }
  }
}

@propertyWrapper
internal final class RecursiveMutableProperty<Value> {
  private let lock: Lock.PthreadLock

  private let token: Lifetime.Token
  private let observer: Signal<Value, Never>.Observer

  private var currentValue: Value

  /// The current value of the property.
  ///
  /// Setting this to a new value will notify all observers of `signal`, or
  /// signals created using `producer`.
  public var value: Value {
    get {
      lock.lock()
      defer { lock.unlock() }
      return currentValue

    }
    set {
      lock.lock()
      currentValue = newValue
      lock.unlock()

      observer.send(value: newValue)
    }
  }

  @inlinable
  public var wrappedValue: Value {
    get { value }
    set { value = newValue }
  }

  @inlinable
  public var projectedValue: RecursiveMutableProperty<Value> {
    return self
  }


  /// The lifetime of the property.
  public let lifetime: Lifetime

  /// A signal that will send the property's changes over time,
  /// then complete when the property has deinitialized.
  public let signal: Signal<Value, Never>

  /// A producer for Signals that will send the property's current value,
  /// followed by all changes over time, then complete when the property has
  /// deinitialized.
  public var producer: SignalProducer<Value, Never> {
    return SignalProducer { [signal, value] observer, lifetime in
      let _value: Value
      _value = value

      observer.send(value: _value)
      lifetime += signal.observe(Signal.Observer(mappingInterruptedToCompleted: observer))
    }
  }


  public init(_ initialValue: Value) {
    (signal, observer) = Signal.pipe()
    (lifetime, token) = Lifetime.make()

    lock = Lock.PthreadLock(recursive: true)
    currentValue = initialValue
  }

  /// Initializes a mutable property that first takes on `initialValue`
  ///
  /// - parameters:
  ///   - initialValue: Starting value for the mutable property.
  public convenience init(wrappedValue: Value) {
    self.init(wrappedValue)
  }
}
