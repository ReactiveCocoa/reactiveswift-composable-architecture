import SwiftUI

@available(iOS 13, macOS 10.15, macCatalyst 13, tvOS 13, watchOS 6, *)
extension Binding {
  func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
    .init(
      get: { self.wrappedValue != nil },
      set: { isPresent, transaction in
        guard !isPresent else { return }
        self.transaction(transaction).wrappedValue = nil
      }
    )
  }
}
