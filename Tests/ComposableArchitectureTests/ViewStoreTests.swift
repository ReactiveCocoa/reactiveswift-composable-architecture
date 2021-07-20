import ComposableArchitecture
import ReactiveSwift
import XCTest

#if canImport(Combine)
  import Combine
#endif

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
    XCTAssertEqual(4, equalityChecks)
    XCTAssertEqual(4, subEqualityChecks)
    viewStore4.send(())
    XCTAssertEqual(8, equalityChecks)
    XCTAssertEqual(8, subEqualityChecks)
    viewStore4.send(())
    XCTAssertEqual(12, equalityChecks)
    XCTAssertEqual(12, subEqualityChecks)
    viewStore4.send(())
    XCTAssertEqual(16, equalityChecks)
    XCTAssertEqual(16, subEqualityChecks)
  }

  func testAccessViewStoreStateInPublisherSink() {
    let reducer = Reducer<Int, Void, Void> { count, _, _ in
      count += 1
      return .none
    }

    let store = Store(initialState: 0, reducer: reducer, environment: ())
    let viewStore = ViewStore(store)

    var results: [Int] = []

    viewStore.produced.producer
      .startWithValues { _ in results.append(viewStore.state) }

    viewStore.send(())
    viewStore.send(())
    viewStore.send(())

    XCTAssertEqual([0, 1, 2, 3], results)
  }

  #if canImport(Combine)
    @available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
    func testWillSet() {
      var cancellables: Set<AnyCancellable> = []

      let reducer = Reducer<Int, Void, Void> { count, _, _ in
        count += 1
        return .none
      }

      let store = Store(initialState: 0, reducer: reducer, environment: ())
      let viewStore = ViewStore(store)

      var results: [Int] = []

      viewStore.objectWillChange
        .sink { _ in results.append(viewStore.state) }
        .store(in: &cancellables)

      viewStore.send(())
      viewStore.send(())
      viewStore.send(())

      XCTAssertEqual([0, 1, 2], results)
    }
  #endif

//  func testPublisherOwnsViewStore() {
//    let reducer = Reducer<Int, Void, Void> { count, _, _ in
//      count += 1
//      return .none
//    }
//    let store = Store(initialState: 0, reducer: reducer, environment: ())
//
//    var results: [Int] = []
//    ViewStore(store)
//      .produced.producer.logEvents(identifier: "test")
//      .startWithValues { results.append($0) }
//
//    ViewStore(store).send(())
//    XCTAssertEqual(results, [0, 1])
//  }
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
