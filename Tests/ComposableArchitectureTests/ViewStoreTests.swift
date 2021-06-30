import ComposableArchitecture
import ReactiveSwift
import XCTest

final class ViewStoreTests: XCTestCase {
  override func setUp() {
    super.setUp()
    equalityChecks = 0
    subEqualityChecks = 0
  }

  func testPublisherFirehose() {
    let store = Store(
      initialState: 0,
      reducer: Reducer<Int, Void, Void>.empty,
      environment: ()
    )

    let viewStore = ViewStore(store)

    var emissionCount = 0
    viewStore.produced.producer
      .startWithValues { _ in emissionCount += 1 }

    XCTAssertEqual(emissionCount, 1)
    viewStore.send(())
    XCTAssertEqual(emissionCount, 1)
    viewStore.send(())
    XCTAssertEqual(emissionCount, 1)
    viewStore.send(())
    XCTAssertEqual(emissionCount, 1)
  }

  func testEqualityChecks() {
    let store = Store(
      initialState: State(),
      reducer: Reducer<State, Void, Void>.empty,
      environment: ()
    )

    let store1 = store.scope(state: { $0 })
    let store2 = store1.scope(state: { $0 })
    let store3 = store2.scope(state: { $0 })
    let store4 = store3.scope(state: { $0 })

    let viewStore1 = ViewStore(store1)
    let viewStore2 = ViewStore(store2)
    let viewStore3 = ViewStore(store3)
    let viewStore4 = ViewStore(store4)

    viewStore1.produced.producer.startWithValues { _ in }
    viewStore2.produced.producer.startWithValues { _ in }
    viewStore3.produced.producer.startWithValues { _ in }
    viewStore4.produced.producer.startWithValues { _ in }
    viewStore1.produced.substate.startWithValues { _ in }
    viewStore2.produced.substate.startWithValues { _ in }
    viewStore3.produced.substate.startWithValues { _ in }
    viewStore4.produced.substate.startWithValues { _ in }

    XCTAssertEqual(0, equalityChecks)
    XCTAssertEqual(0, subEqualityChecks)
    viewStore4.send(())
    XCTAssertEqual(12, equalityChecks)
    XCTAssertEqual(12, subEqualityChecks)
    viewStore4.send(())
    XCTAssertEqual(24, equalityChecks)
    XCTAssertEqual(24, subEqualityChecks)
    viewStore4.send(())
    XCTAssertEqual(36, equalityChecks)
    XCTAssertEqual(36, subEqualityChecks)
    viewStore4.send(())
    XCTAssertEqual(48, equalityChecks)
    XCTAssertEqual(48, subEqualityChecks)
  }
}

private struct State: Equatable {
  var substate = Substate()

  static func == (lhs: Self, rhs: Self) -> Bool {
    equalityChecks += 1
    return lhs.substate == rhs.substate
  }
}

private struct Substate: Equatable {
  var name = "Blob"

  static func == (lhs: Self, rhs: Self) -> Bool {
    subEqualityChecks += 1
    return lhs.name == rhs.name
  }
}

private var equalityChecks = 0
private var subEqualityChecks = 0
