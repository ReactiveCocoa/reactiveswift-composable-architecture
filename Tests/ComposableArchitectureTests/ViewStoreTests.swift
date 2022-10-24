import ComposableArchitecture
import ReactiveSwift
import XCTest

#if canImport(Combine)
  import Combine
#endif

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
  @MainActor
  final class ViewStoreTests: XCTestCase {
    override func setUp() {
      super.setUp()
      equalityChecks = 0
      subEqualityChecks = 0
    }

    func testPublisherFirehose() {
      let store = Store(
        initialState: 0,
        reducer: EmptyReducer<Int, Void>()
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
        reducer: EmptyReducer<State, Void>()
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
      let reducer = Reduce<Int, Void> { count, _ in
        count += 1
        return .none
      }

      let store = Store(initialState: 0, reducer: reducer)
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
      func testWillSet() {
        var cancellables: Set<AnyCancellable> = []

        let reducer = Reduce<Int, Void> { count, _ in
          count += 1
          return .none
        }

        let store = Store(initialState: 0, reducer: reducer)
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

    // disabled as the fix for this would be onerous with
    // ReactiveSwift, forcing explicit disposable of any use of
    // `ViewStore.produced.producer`
    func disabled_testPublisherOwnsViewStore() {
      let reducer = Reduce<Int, Void> { count, _ in
        count += 1
        return .none
      }
      let store = Store(initialState: 0, reducer: reducer)

      var results: [Int] = []
      ViewStore(store)
        .produced.producer
        .startWithValues { results.append($0) }

      ViewStore(store).send(())
      XCTAssertEqual(results, [0, 1])
    }

    func testStorePublisherSubscriptionOrder() {
      let reducer = Reduce<Int, Void> { count, _ in
        count += 1
        return .none
      }
      let store = Store(initialState: 0, reducer: reducer)
      let viewStore = ViewStore(store)

      var results: [Int] = []

      viewStore.produced.producer
        .startWithValues { _ in results.append(0) }

      viewStore.produced.producer
        .startWithValues { _ in results.append(1) }

      viewStore.produced.producer
        .startWithValues { _ in results.append(2) }

      XCTAssertEqual(results, [0, 1, 2])

      for _ in 0..<9 {
        viewStore.send(())
      }

      XCTAssertEqual(results, Array(repeating: [0, 1, 2], count: 10).flatMap { $0 })
    }

    #if canImport(_Concurrency) && compiler(>=5.5.2)
      func testSendWhile() async {
        let expectation = self.expectation(description: "await")
        Task {
          enum Action {
            case response
            case tapped
          }
          let reducer = Reduce<Bool, Action> { state, action in
            switch action {
            case .response:
              state = false
              return .none
            case .tapped:
              state = true
              return .task { .response }
            }
          }

          let store = Store(initialState: false, reducer: reducer)
          let viewStore = ViewStore(store)

          XCTAssertEqual(viewStore.state, false)
          await viewStore.send(.tapped, while: { $0 })
          XCTAssertEqual(viewStore.state, false)
          expectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [expectation], timeout: 1)
      }

      func testSuspend() async {
        let expectation = self.expectation(description: "await")
        Task {
          enum Action {
            case response
            case tapped
          }
          let reducer = Reduce<Bool, Action> { state, action in
            switch action {
            case .response:
              state = false
              return .none
            case .tapped:
              state = true
              return .task { .response }
            }
          }

          let store = Store(initialState: false, reducer: reducer)
          let viewStore = ViewStore(store)

          XCTAssertEqual(viewStore.state, false)
          _ = { viewStore.send(.tapped) }()
          XCTAssertEqual(viewStore.state, true)
          await viewStore.yield(while: { $0 })
          XCTAssertEqual(viewStore.state, false)
          expectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [expectation], timeout: 1)
      }

      func testAsyncSend() async throws {
        enum Action {
          case tap
          case response(Int)
        }
        let store = Store(
          initialState: 0,
          reducer: Reduce<Int, Action> { state, action in
            switch action {
            case .tap:
              return .task {
                return .response(42)
              }
            case let .response(value):
              state = value
              return .none
            }
          }
        )

        let viewStore = ViewStore(store)

        XCTAssertEqual(viewStore.state, 0)
        await viewStore.send(.tap).finish()
        XCTAssertEqual(viewStore.state, 42)
      }

      func testAsyncSendCancellation() async throws {
        enum Action {
          case tap
          case response(Int)
        }
        let store = Store(
          initialState: 0,
          reducer: Reduce<Int, Action> { state, action in
            switch action {
            case .tap:
              return .task {
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
                return .response(42)
              }
            case let .response(value):
              state = value
              return .none
            }
          }
        )

        let viewStore = ViewStore(store)

        XCTAssertEqual(viewStore.state, 0)
        let task = viewStore.send(.tap)
        await task.cancel()
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        XCTAssertEqual(viewStore.state, 0)
      }
    #endif
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
#endif

private var equalityChecks = 0
private var subEqualityChecks = 0
