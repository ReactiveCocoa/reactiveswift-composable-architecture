import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

final class StoreTests: XCTestCase {

  func testProducedMapping() {
    struct ChildState: Equatable {
      var value: Int = 0
    }
    struct ParentState: Equatable {
      var child: ChildState = .init()
    }

    let store = Store<ParentState, Void>(
      initialState: ParentState(),
      reducer: Reducer { state, _, _ in
        state.child.value += 1
        return .none
      },
      environment: ()
    )

    let viewStore = ViewStore(store)
    var values: [Int] = []

    viewStore.produced.child.value.startWithValues { value in
      values.append(value)
    }

    viewStore.send(())
    viewStore.send(())
    viewStore.send(())

    XCTAssertEqual(values, [0, 1, 2, 3])
  }

  func testEffectDisposablesDeinitialization() {
    enum Action {
      case triggerDelay
      case delayDidComplete
    }
    let delayedReducer = Reducer<Void, Action, DateScheduler> { _, action, mainQueue in
      switch action {
      case .triggerDelay:
        return Effect(value: .delayDidComplete).delay(1, on: mainQueue)

      case .delayDidComplete:
        return .none
      }
    }

    let store = Store(
      initialState: (),
      reducer: delayedReducer,
      environment: QueueScheduler.main
    )

    store.send(.triggerDelay)
    store.send(.triggerDelay)
    store.send(.triggerDelay)
    store.send(.delayDidComplete)

    XCTAssertEqual(store.effectDisposables.count, 3)

    XCTWaiter().wait(for: [XCTestExpectation()], timeout: 1.1)

    XCTAssertEqual(store.effectDisposables.count, 0)
  }

  func testScopedStoreReceivesUpdatesFromParent() {
    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())
    let parentViewStore = ViewStore(parentStore)
    let childStore = parentStore.scope(state: String.init)

    var values: [String] = []
    childStore.$state.producer
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, ["0"])

    parentViewStore.send(())

    XCTAssertEqual(values, ["0", "1"])
  }

  func testParentStoreReceivesUpdatesFromChild() {
    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())
    let childStore = parentStore.scope(state: String.init)
    let childViewStore = ViewStore(childStore)

    var values: [Int] = []
    parentStore.$state.producer
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, [0])

    childViewStore.send(())

    XCTAssertEqual(values, [0, 1])
  }

  func testScopeWithPublisherTransform() {
    let counterReducer = Reducer<Int, Int, Void> { state, action, _ in
      state = action
      return .none
    }
    let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())

    var outputs: [String] = []

    parentStore
      .producerScope(state: { $0.map { "\($0)" }.skipRepeats() })
      .startWithValues { childStore in
        childStore.$state.producer
          .startWithValues { outputs.append($0) }
      }

    parentStore.send(0)
    XCTAssertEqual(outputs, ["0"])
    parentStore.send(0)
    XCTAssertEqual(outputs, ["0"])
    parentStore.send(1)
    XCTAssertEqual(outputs, ["0", "1"])
    parentStore.send(1)
    XCTAssertEqual(outputs, ["0", "1"])
    parentStore.send(2)
    XCTAssertEqual(outputs, ["0", "1", "2"])
  }

  func testScopeCallCount() {
    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in state += 1
      return .none
    }

    var numCalls1 = 0
    _ = Store(initialState: 0, reducer: counterReducer, environment: ())
      .scope(state: { (count: Int) -> Int in
        numCalls1 += 1
        return count
      })

    XCTAssertEqual(numCalls1, 1)
  }

  func testScopeCallCount2() {
    let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    var numCalls1 = 0
    var numCalls2 = 0
    var numCalls3 = 0

    let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
    let store2 =
      store1
      .scope(state: { (count: Int) -> Int in
        numCalls1 += 1
        return count
      })
    let store3 =
      store2
      .scope(state: { (count: Int) -> Int in
        numCalls2 += 1
        return count
      })
    let store4 =
      store3
      .scope(state: { (count: Int) -> Int in
        numCalls3 += 1
        return count
      })

    _ = ViewStore(store1)
    _ = ViewStore(store2)
    _ = ViewStore(store3)
    let viewStore4 = ViewStore(store4)

    XCTAssertEqual(numCalls1, 1)
    XCTAssertEqual(numCalls2, 1)
    XCTAssertEqual(numCalls3, 1)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 2)
    XCTAssertEqual(numCalls2, 2)
    XCTAssertEqual(numCalls3, 2)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 3)
    XCTAssertEqual(numCalls2, 3)
    XCTAssertEqual(numCalls3, 3)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 4)
    XCTAssertEqual(numCalls2, 4)
    XCTAssertEqual(numCalls3, 4)

    viewStore4.send(())

    XCTAssertEqual(numCalls1, 5)
    XCTAssertEqual(numCalls2, 5)
    XCTAssertEqual(numCalls3, 5)
  }

  func testSynchronousEffectsSentAfterSinking() {
    enum Action {
      case tap
      case next1
      case next2
      case end
    }
    var values: [Int] = []
    let counterReducer = Reducer<Void, Action, Void> { state, action, _ in
      switch action {
      case .tap:
        return .merge(
          Effect(value: .next1),
          Effect(value: .next2),
          Effect.fireAndForget { values.append(1) }
        )
      case .next1:
        return .merge(
          Effect(value: .end),
          Effect.fireAndForget { values.append(2) }
        )
      case .next2:
        return .fireAndForget { values.append(3) }
      case .end:
        return .fireAndForget { values.append(4) }
      }
    }

    let store = Store(initialState: (), reducer: counterReducer, environment: ())

    store.send(.tap)

    XCTAssertEqual(values, [1, 2, 3, 4])
  }

  func testLotsOfSynchronousActions() {
    enum Action { case incr, noop }
    let reducer = Reducer<Int, Action, ()> { state, action, _ in
      switch action {
      case .incr:
        state += 1
        return state >= 100_000 ? Effect(value: .noop) : Effect(value: .incr)
      case .noop:
        return .none
      }
    }

    let store = Store(initialState: 0, reducer: reducer, environment: ())
    store.send(.incr)
    XCTAssertEqual(ViewStore(store).state, 100_000)
  }

  func testPublisherScope() {
    let appReducer = Reducer<Int, Bool, Void> { state, action, _ in
      state += action ? 1 : 0
      return .none
    }

    let parentStore = Store(initialState: 0, reducer: appReducer, environment: ())

    var outputs: [Int] = []

    parentStore
      .producerScope { $0.skipRepeats() }
      .startWithValues { outputs.append($0.$state.value) }

    XCTAssertEqual(outputs, [0])

    parentStore.send(true)
    XCTAssertEqual(outputs, [0, 1])

    parentStore.send(false)
    XCTAssertEqual(outputs, [0, 1])
    parentStore.send(false)
    XCTAssertEqual(outputs, [0, 1])
    parentStore.send(false)
    XCTAssertEqual(outputs, [0, 1])
    parentStore.send(false)
    XCTAssertEqual(outputs, [0, 1])
  }

  func testIfLetAfterScope() {
    struct AppState {
      var count: Int?
    }

    let appReducer = Reducer<AppState, Int?, Void> { state, action, _ in
      state.count = action
      return .none
    }

    let parentStore = Store(initialState: AppState(), reducer: appReducer, environment: ())

    // NB: This test needs to hold a strong reference to the emitted stores
    var outputs: [Int?] = []
    var stores: [Any] = []

    parentStore
      .scope(state: \.count)
      .ifLet(
        then: { store in
          stores.append(store)
          outputs.append(store.state)
        },
        else: {
          outputs.append(nil)
        })

    XCTAssertEqual(outputs, [nil])

    parentStore.send(1)
    XCTAssertEqual(outputs, [nil, 1])

    parentStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil])

    parentStore.send(1)
    XCTAssertEqual(outputs, [nil, 1, nil, 1])

    parentStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil])

    parentStore.send(1)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1])

    parentStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1, nil])
  }

  func testIfLetTwo() {
    let parentStore = Store(
      initialState: 0,
      reducer: Reducer<Int?, Bool, Void> { state, action, _ in
        if action {
          state? += 1
          return .none
        } else {
          return Effect(value: true).observe(on: QueueScheduler.main)
        }
      },
      environment: ()
    )

    parentStore
      .ifLet(then: { childStore in
        let vs = ViewStore(childStore)

        vs
          .produced.producer
          .startWithValues { _ in }

        vs.send(false)
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
        vs.send(false)
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
        vs.send(false)
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
        XCTAssertEqual(vs.state, 3)
      })
  }

  func testActionQueuing() {
    let subject = Signal<Void, Never>.pipe()

    enum Action: Equatable {
      case incrementTapped
      case `init`
      case doIncrement
    }

    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Action, Void> { state, action, _ in
        switch action {
        case .incrementTapped:
          subject.input.send(value: ())
          return .none

        case .`init`:
          return subject.output.producer.map { .doIncrement }

        case .doIncrement:
          state += 1
          return .none
        }
      },
      environment: ()
    )

    store.send(.`init`)
    store.send(.incrementTapped)
    store.receive(.doIncrement) {
      $0 = 1
    }
    store.send(.incrementTapped)
    store.receive(.doIncrement) {
      $0 = 2
    }
    subject.input.sendCompleted()
  }

  func testCoalesceSynchronousActions() {
    let store = Store(
      initialState: 0,
      reducer: Reducer<Int, Int, Void> { state, action, _ in
        switch action {
        case 0:
          return .merge(
            Effect(value: 1),
            Effect(value: 2),
            Effect(value: 3)
          )
        default:
          state = action
          return .none
        }
      },
      environment: ()
    )

    var emissions: [Int] = []
    let viewStore = ViewStore(store)
    viewStore.produced.producer
      .startWithValues { emissions.append($0) }

    XCTAssertEqual(emissions, [0])

    viewStore.send(0)

    XCTAssertEqual(emissions, [0, 1, 2, 3])
  }
}
