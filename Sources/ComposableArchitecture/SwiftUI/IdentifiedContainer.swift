import Foundation

public protocol IdentifiedContainer: Collection {

  associatedtype ID: Hashable
  associatedtype Element

  var id: KeyPath<Element, ID> { get }

  subscript(id id: ID) -> Element? { get set }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension IdentifiedArray: IdentifiedContainer {}
