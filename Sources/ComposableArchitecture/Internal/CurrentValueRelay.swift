import Foundation
import ReactiveSwift

class CurrentValueRelay<Output>: SignalProducerConvertible {
  typealias Error = Never

  private var currentValue: Output
  private let valuePipe = Signal<Output, Error>.pipe()

  var value: Output {
    get { self.currentValue }
    set {
      self.currentValue = newValue
      self.valuePipe.input.send(value: newValue)
    }
  }

  var producer: SignalProducer<Output, Error> {
    valuePipe.output.producer.prefix(value: currentValue)
  }

  init(_ value: Output) {
    self.currentValue = value
  }
}
