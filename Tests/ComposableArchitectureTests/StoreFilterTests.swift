// `@MainActor` introduces issues gathering tests on Linux
#if DEBUG && !os(Linux)
  import ReactiveSwift
  import XCTest

  @testable import ComposableArchitecture

  @MainActor
  final class StoreFilterTests: XCTestCase {

    func testFilter() {
      let store = Store<Int?, Void>(initialState: nil, reducer: EmptyReducer())
        .filter { state, _ in state != nil }

      let viewStore = ViewStore(store)
      var count = 0
      viewStore.produced.producer
        .startWithValues { _ in count += 1 }

      XCTAssertEqual(count, 1)
      viewStore.send(())
      XCTAssertEqual(count, 1)
      viewStore.send(())
      XCTAssertEqual(count, 1)
    }
  }
#endif
