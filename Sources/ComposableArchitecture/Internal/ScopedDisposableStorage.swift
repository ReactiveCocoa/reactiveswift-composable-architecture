import ReactiveSwift
import Foundation

@propertyWrapper
class DisposablesScopedStorage {
  var wrappedValue: [UUID: Disposable]
  
  init(wrappedValue: [UUID: Disposable] = [:]) {
    self.wrappedValue = wrappedValue
  }
  
  func disposeAll() {
    wrappedValue.values.forEach { $0.dispose() }
  }
  
  deinit { disposeAll() }
}
