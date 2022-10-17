@_spi(Internals) import ComposableArchitecture
import ReactiveSwift
import XCTest

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
@MainActor
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

      XCTAssertNoDifference(values, [0, 1, 2, 3])
    }

    #if DEBUG
  func testCancellableIsRemovedOnImmediatelyCompletingEffect() {
    let store = Store(initialState: (), reducer: EmptyReducer<Void, Void>())

        XCTAssertEqual(store.effectDisposables.count, 0)

    _ = store.send(())

        XCTAssertEqual(store.effectDisposables.count, 0)
  }
    #endif

  func testCancellableIsRemovedWhenEffectCompletes() {
      let mainQueue = TestScheduler()
    let effect = EffectTask<Void>(value: ())
        .deferred(for: 1, scheduler: mainQueue)

    enum Action { case start, end }

    let reducer = Reduce<Void, Action>({ _, action in
      switch action {
      case .start:
        return effect.map { .end }
      case .end:
        return .none
      }
    })
    let store = Store(initialState: (), reducer: reducer)

      XCTAssertEqual(store.effectDisposables.count, 0)

    _ = store.send(.start)

      XCTAssertEqual(store.effectDisposables.count, 1)

    mainQueue.advance(by: 2)

      XCTAssertEqual(store.effectDisposables.count, 0)
  }

  func testScopedStoreReceivesUpdatesFromParent() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    let parentStore = Store(initialState: 0, reducer: counterReducer)
    let parentViewStore = ViewStore(parentStore)
    let childStore = parentStore.scope(state: String.init)

    var values: [String] = []
      let childViewStore = ViewStore(childStore)
      childViewStore.produced.producer
        .startWithValues { values.append($0) }

    XCTAssertEqual(values, ["0"])

    parentViewStore.send(())

    XCTAssertEqual(values, ["0", "1"])
  }

  func testParentStoreReceivesUpdatesFromChild() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    let parentStore = Store(initialState: 0, reducer: counterReducer)
    let childStore = parentStore.scope(state: String.init)
    let childViewStore = ViewStore(childStore)

    var values: [Int] = []
      let parentViewStore = ViewStore(parentStore)
      parentViewStore.produced.producer
        .startWithValues { values.append($0) }

    XCTAssertEqual(values, [0])

    childViewStore.send(())

    XCTAssertEqual(values, [0, 1])
  }

  func testScopeCallCount() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    var numCalls1 = 0
    _ = Store(initialState: 0, reducer: counterReducer)
      .scope(state: { (count: Int) -> Int in
        numCalls1 += 1
        return count
      })

    XCTAssertEqual(numCalls1, 1)
  }

  func testScopeCallCount2() {
    let counterReducer = Reduce<Int, Void>({ state, _ in
      state += 1
      return .none
    })

    var numCalls1 = 0
    var numCalls2 = 0
    var numCalls3 = 0

    let store1 = Store(initialState: 0, reducer: counterReducer)
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

    let viewStore1 = ViewStore(store1)
    let viewStore2 = ViewStore(store2)
    let viewStore3 = ViewStore(store3)
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

    _ = viewStore1
    _ = viewStore2
    _ = viewStore3
  }

  func testSynchronousEffectsSentAfterSinking() {
    enum Action {
      case tap
      case next1
      case next2
      case end
    }
    var values: [Int] = []
    let counterReducer = Reduce<Void, Action>({ state, action in
      switch action {
      case .tap:
        return .merge(
          EffectTask(value: .next1),
          EffectTask(value: .next2),
            Effect.fireAndForget { values.append(1) }
        )
      case .next1:
        return .merge(
          EffectTask(value: .end),
            Effect.fireAndForget { values.append(2) }
        )
      case .next2:
        return .fireAndForget { values.append(3) }
      case .end:
        return .fireAndForget { values.append(4) }
      }
    })

    let store = Store(initialState: (), reducer: counterReducer)

    _ = ViewStore(store).send(.tap)

    XCTAssertEqual(values, [1, 2, 3, 4])
  }

  func testLotsOfSynchronousActions() {
    enum Action { case incr, noop }
    let reducer = Reduce<Int, Action>({ state, action in
      switch action {
      case .incr:
        state += 1
        return state >= 100_000 ? EffectTask(value: .noop) : EffectTask(value: .incr)
      case .noop:
        return .none
      }
    })

    let store = Store(initialState: 0, reducer: reducer)
    _ = ViewStore(store).send(.incr)
    XCTAssertEqual(ViewStore(store).state, 100_000)
  }

  func testIfLetAfterScope() {
    struct AppState: Equatable {
      var count: Int?
    }

    let appReducer = Reduce<AppState, Int?>({ state, action in
      state.count = action
      return .none
    })

    let parentStore = Store(initialState: AppState(), reducer: appReducer)
    let parentViewStore = ViewStore(parentStore)

    // NB: This test needs to hold a strong reference to the emitted stores
    var outputs: [Int?] = []
    var stores: [Any] = []

    parentStore
        .scope(state: \.count)
      .ifLet(
        then: { store in
          stores.append(store)
          outputs.append(ViewStore(store).state)
        },
        else: {
          outputs.append(nil)
          })

    XCTAssertEqual(outputs, [nil])

    _ = parentViewStore.send(1)
    XCTAssertEqual(outputs, [nil, 1])

    _ = parentViewStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil])

    _ = parentViewStore.send(1)
    XCTAssertEqual(outputs, [nil, 1, nil, 1])

    _ = parentViewStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil])

    _ = parentViewStore.send(1)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1])

    _ = parentViewStore.send(nil)
    XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1, nil])
  }

  func testIfLetTwo() {
    let parentStore = Store(
      initialState: 0,
      reducer: Reduce<Int?, Bool>({ state, action in
        if action {
          state? += 1
          return .none
        } else {
            return SignalProducer(value: true)
              .observe(on: QueueScheduler.main)
              .eraseToEffect()
        }
      })
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

  func testActionQueuing() async {
      let subject = Signal<Void, Never>.pipe()

    enum Action: Equatable {
      case incrementTapped
      case `init`
      case doIncrement
    }

    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Action>({ state, action in
        switch action {
        case .incrementTapped:
            subject.input.send(value: ())
          return .none

        case .`init`:
            return subject.output.producer
              .map { .doIncrement }
              .eraseToEffect()

        case .doIncrement:
          state += 1
          return .none
        }
      })
    )

    await store.send(.`init`)
    await store.send(.incrementTapped)
    await store.receive(.doIncrement) {
      $0 = 1
    }
    await store.send(.incrementTapped)
    await store.receive(.doIncrement) {
      $0 = 2
    }
      subject.input.sendCompleted()
  }

  func testCoalesceSynchronousActions() {
    let store = Store(
      initialState: 0,
      reducer: Reduce<Int, Int>({ state, action in
        switch action {
        case 0:
          return .merge(
            EffectTask(value: 1),
            EffectTask(value: 2),
            EffectTask(value: 3)
          )
        default:
          state = action
          return .none
        }
      })
    )

    var emissions: [Int] = []
    let viewStore = ViewStore(store)
      viewStore.produced.producer
        .startWithValues { emissions.append($0) }

    XCTAssertEqual(emissions, [0])

    viewStore.send(0)

    XCTAssertEqual(emissions, [0, 3])
  }

  func testBufferedActionProcessing() {
    struct ChildState: Equatable {
      var count: Int?
    }

    struct ParentState: Equatable {
      var count: Int?
      var child: ChildState?
    }

    enum ParentAction: Equatable {
      case button
      case child(Int?)
    }

    var handledActions: [ParentAction] = []
    let parentReducer = Reduce<ParentState, ParentAction>({ state, action in
      handledActions.append(action)

      switch action {
      case .button:
        state.child = .init(count: nil)
        return .none

      case .child(let childCount):
        state.count = childCount
        return .none
      }
    })
    .ifLet(\.child, action: /ParentAction.child) {
      Reduce({ state, action in
        state.count = action
        return .none
      })
    }

    let parentStore = Store(
      initialState: ParentState(),
      reducer: parentReducer
    )

    parentStore
      .scope(
        state: \.child,
        action: ParentAction.child
      )
      .ifLet { childStore in
        ViewStore(childStore).send(2)
      }

    XCTAssertEqual(handledActions, [])

    _ = ViewStore(parentStore).send(.button)
    XCTAssertEqual(
      handledActions,
      [
        .button,
        .child(2),
      ])
  }

  func testCascadingTaskCancellation() async {
    enum Action { case task, response, response1, response2 }
    let reducer = Reduce<Int, Action>({ state, action in
      switch action {
      case .task:
        return .task { .response }
      case .response:
        return .merge(
            SignalProducer { _, _ in }.eraseToEffect(),
          .task { .response1 }
        )
      case .response1:
        return .merge(
            SignalProducer { _, _ in }.eraseToEffect(),
          .task { .response2 }
        )
      case .response2:
          return SignalProducer { _, _ in }.eraseToEffect()
      }
    })

    let store = TestStore(
      initialState: 0,
      reducer: reducer
    )

    let task = await store.send(.task)
    await store.receive(.response)
    await store.receive(.response1)
    await store.receive(.response2)
    await task.cancel()
  }

  func testTaskCancellationEmpty() async {
    enum Action { case task }

    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Action>({ state, action in
        switch action {
        case .task:
          return .fireAndForget { try await Task.never() }
        }
      })
    )

    await store.send(.task).cancel()
  }

  func testScopeCancellation() async throws {
    let neverEndingTask = Task<Void, Error> { try await Task.never() }

    let store = Store(
      initialState: (),
      reducer: Reduce<Void, Void>({ _, _ in
        .fireAndForget {
          try await neverEndingTask.value
        }
      })
    )
    let scopedStore = store.scope(state: { $0 })

    let sendTask = scopedStore.send(())
    await Task.yield()
    neverEndingTask.cancel()
    try await XCTUnwrap(sendTask).value
      XCTAssertEqual(store.effectDisposables.count, 0)
      XCTAssertEqual(scopedStore.effectDisposables.count, 0)
  }
}
#endif
