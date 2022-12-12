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
        reducer: Reducer<Int, Void, Void>.empty,
        environment: ()
      )

      let viewStore = ViewStore(store)

      var emissionCount = 0
      viewStore.produced.producer
        .startWithValues { _ in emissionCount += 1 }

      XCTAssertNoDifference(emissionCount, 1)
      viewStore.send(())
      XCTAssertNoDifference(emissionCount, 1)
      viewStore.send(())
      XCTAssertNoDifference(emissionCount, 1)
      viewStore.send(())
      XCTAssertNoDifference(emissionCount, 1)
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

      XCTAssertNoDifference(0, equalityChecks)
      XCTAssertNoDifference(0, subEqualityChecks)
      viewStore4.send(())
      XCTAssertNoDifference(4, equalityChecks)
      XCTAssertNoDifference(4, subEqualityChecks)
      viewStore4.send(())
      XCTAssertNoDifference(8, equalityChecks)
      XCTAssertNoDifference(8, subEqualityChecks)
      viewStore4.send(())
      XCTAssertNoDifference(12, equalityChecks)
      XCTAssertNoDifference(12, subEqualityChecks)
      viewStore4.send(())
      XCTAssertNoDifference(16, equalityChecks)
      XCTAssertNoDifference(16, subEqualityChecks)
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

      XCTAssertNoDifference([0, 1, 2, 3], results)
    }

    #if canImport(Combine)
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

        XCTAssertNoDifference([0, 1, 2], results)
      }
    #endif

    // disabled as the fix for this would be onerous with
    // ReactiveSwift, forcing explicit disposable of any use of
    // `ViewStore.produced.producer`
    func disabled_testPublisherOwnsViewStore() {
      let reducer = Reducer<Int, Void, Void> { count, _, _ in
        count += 1
        return .none
      }
      let store = Store(initialState: 0, reducer: reducer, environment: ())

      var results: [Int] = []
      ViewStore(store)
        .produced.producer
        .startWithValues { results.append($0) }

      ViewStore(store).send(())
      XCTAssertNoDifference(results, [0, 1])
    }

    func testStorePublisherSubscriptionOrder() {
      let reducer = Reducer<Int, Void, Void> { count, _, _ in
        count += 1
        return .none
      }
      let store = Store(initialState: 0, reducer: reducer, environment: ())
      let viewStore = ViewStore(store)

      var results: [Int] = []

      viewStore.produced.producer
        .startWithValues { _ in results.append(0) }

      viewStore.produced.producer
        .startWithValues { _ in results.append(1) }

      viewStore.produced.producer
        .startWithValues { _ in results.append(2) }

      XCTAssertNoDifference(results, [0, 1, 2])

      for _ in 0..<9 {
        viewStore.send(())
      }

      XCTAssertNoDifference(results, Array(repeating: [0, 1, 2], count: 10).flatMap { $0 })
    }

    #if canImport(_Concurrency) && compiler(>=5.5.2)
      func testSendWhile() async {
        Task {
          enum Action {
            case response
            case tapped
          }
          let reducer = Reducer<Bool, Action, Void> { state, action, environment in
            switch action {
            case .response:
              state = false
              return .none
            case .tapped:
              state = true
              return SignalProducer(value: .response)
                .observe(on: QueueScheduler.main)
                .eraseToEffect()
            }
          }

          let store = Store(initialState: false, reducer: reducer, environment: ())
          let viewStore = ViewStore(store)

          XCTAssertNoDifference(viewStore.state, false)
          await viewStore.send(.tapped, while: { $0 })
          XCTAssertNoDifference(viewStore.state, false)
        }
      }

      func testSuspend() async {
        let expectation = self.expectation(description: "await")
        Task {
          enum Action {
            case response
            case tapped
          }
          let reducer = Reducer<Bool, Action, Void> { state, action, environment in
            switch action {
            case .response:
              state = false
              return .none
            case .tapped:
              state = true
              return SignalProducer(value: .response)
                .observe(on: QueueScheduler.main)
                .eraseToEffect()
            }
          }

          let store = Store(initialState: false, reducer: reducer, environment: ())
          let viewStore = ViewStore(store)

          XCTAssertNoDifference(viewStore.state, false)
          _ = { viewStore.send(.tapped) }()
          XCTAssertNoDifference(viewStore.state, true)
          await viewStore.yield(while: { $0 })
          XCTAssertNoDifference(viewStore.state, false)
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
          reducer: Reducer<Int, Action, Void> { state, action, _ in
            switch action {
            case .tap:
              return .task {
                return .response(42)
              }
            case let .response(value):
              state = value
              return .none
            }
          },
          environment: ()
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
          reducer: Reducer<Int, Action, Void> { state, action, _ in
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
          },
          environment: ()
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
