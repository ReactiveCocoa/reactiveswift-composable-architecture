import ComposableArchitecture
import OrderedCollections

// Example data structure which is usable with `Reducer.forEach` in iOS < 13 (`IdentifiableArray` is iOS 13+)

struct IdentifiedStateContainer<ID: Hashable, Element>: IdentifiedContainer {

  typealias Index = Int

  typealias ID = ID
  typealias Element = Element

  private var _storage: OrderedDictionary<ID, Element>

  var elements: [Element] { _storage.elements.map(\.value) }

  init<S: Sequence>(
    elements: S,
    id: KeyPath<Element, ID>
  ) where S.Element == Element {
    self._storage = .init(uniqueKeysWithValues: elements.map { ($0[keyPath: id], $0) })
    self.id = id
  }

  // IdentifiedContainer

  let id: KeyPath<Element, ID>

  subscript(id id: ID) -> Element? {
    // NB: `_read` crashes Xcode Preview compilation.
    get { self._storage[id] }
    _modify { yield &self._storage[id] }
  }

  // Collection

  var startIndex: Index { _storage.elements.startIndex }
  var endIndex: Index { _storage.elements.endIndex }

  public func index(after index: Index) -> Index { _storage.elements.index(after: index) }

  subscript(position: Index) -> Element { self._storage.elements[position].value }

  // Partial MutableCollection

  mutating func shuffle() {
    self._storage.shuffle()
  }

  // Partial RangeReplaceableCollection

  mutating func append(_ newElement: Element) {
    let id = newElement[keyPath: self.id]
    self._storage[id] = newElement
  }

  mutating func append<S>(contentsOf newElements: S) where S : Sequence, Element == S.Element {
    self._storage.reserveCapacity(self._storage.count + newElements.underestimatedCount)
    newElements.forEach { self.append($0) }
  }

  mutating func remove(at i: Index) -> Element {
    self._storage.remove(at: i).value
  }

  // Helpers

  @discardableResult
  mutating func remove(id: ID) -> Element {
    let element = self._storage[id]
    assert(element != nil, "Unexpectedly found nil while removing an identified element.")
    self._storage[id] = nil
    return element!
  }
}

extension IdentifiedStateContainer: Equatable where Element: Equatable {}
extension IdentifiedStateContainer: Hashable where Element: Hashable {}

extension IdentifiedStateContainer: ExpressibleByArrayLiteral where Element: Identifiable, Element.ID == ID {

  typealias ArrayLiteralElement = Element

  init(arrayLiteral elements: ArrayLiteralElement...) {
    self.init(elements: elements, id: \.id)
  }
}
