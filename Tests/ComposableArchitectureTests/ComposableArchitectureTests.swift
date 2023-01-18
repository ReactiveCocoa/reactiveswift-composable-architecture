import ComposableArchitecture
import ReactiveSwift
import XCTest

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
@MainActor
final class ComposableArchitectureTests: XCTestCase {
  func testScheduling() async {
    struct Counter: ReducerProtocol {
      typealias State = Int
      enum Action: Equatable {
        case incrAndSquareLater
        case incrNow
        case squareNow
      }
        @Dependency(\.mainQueueScheduler) var mainQueue
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .incrAndSquareLater:
          return .merge(
            EffectTask(value: .incrNow)
                .deferred(for: 2, scheduler: self.mainQueue),
            EffectTask(value: .squareNow)
                .deferred(for: 1, scheduler: self.mainQueue),
            EffectTask(value: .squareNow)
                .deferred(for: 2, scheduler: self.mainQueue)
          )
        case .incrNow:
          state += 1
          return .none
        case .squareNow:
          state *= state
          return .none
        }
      }
    }

    let mainQueue = TestScheduler()

    let store = TestStore(
      initialState: 2,
      reducer: Counter()
    ) {
      $0.mainQueue = mainQueue
    }

    await store.send(.incrAndSquareLater)
    await mainQueue.advance(by: 1)
    await store.receive(.squareNow) { $0 = 4 }
    await mainQueue.advance(by: 1)
    await store.receive(.incrNow) { $0 = 5 }
    await store.receive(.squareNow) { $0 = 25 }

    await store.send(.incrAndSquareLater)
    await mainQueue.advance(by: 2)
    await store.receive(.squareNow) { $0 = 625 }
    await store.receive(.incrNow) { $0 = 626 }
    await store.receive(.squareNow) { $0 = 391876 }
  }

  func testSimultaneousWorkOrdering() {
      let mainQueue = TestScheduler()

    var values: [Int] = []
      mainQueue.schedule(after: .seconds(0), interval: .seconds(1)) { values.append(1) }
      mainQueue.schedule(after: .seconds(0), interval: .seconds(2)) { values.append(42) }

    XCTAssertEqual(values, [])
    mainQueue.advance()
    XCTAssertEqual(values, [1, 42])
    mainQueue.advance(by: 2)
      XCTAssertEqual(values, [1, 42, 1, 42, 1])
  }

  func testLongLivingEffects() async {
    enum Action { case end, incr, start }

    let effect = AsyncStream<Void>.streamWithContinuation()

    let reducer = Reduce<Int, Action> { state, action in
      switch action {
      case .end:
        return .fireAndForget {
          effect.continuation.finish()
        }
      case .incr:
        state += 1
        return .none
      case .start:
        return .run { send in
          for await _ in effect.stream {
            await send(.incr)
          }
        }
      }
    }

    let store = TestStore(initialState: 0, reducer: reducer)

    await store.send(.start)
    await store.send(.incr) { $0 = 1 }
    effect.continuation.yield()
    await store.receive(.incr) { $0 = 2 }
    await store.send(.end)
  }

  func testCancellation() async {
      let mainQueue = TestScheduler()

    enum Action: Equatable {
      case cancel
      case incr
      case response(Int)
    }

    let reducer = Reduce<Int, Action> { state, action in
      enum CancelID {}

      switch action {
      case .cancel:
        return .cancel(id: CancelID.self)

      case .incr:
        state += 1
        return .task { [state] in
          try await mainQueue.sleep(for: .seconds(1))
          return .response(state * state)
        }
        .cancellable(id: CancelID.self)

      case let .response(value):
        state = value
        return .none
      }
    }

    let store = TestStore(
      initialState: 0,
      reducer: reducer
    )

    await store.send(.incr) { $0 = 1 }
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.response(1))

    await store.send(.incr) { $0 = 2 }
    await store.send(.cancel)
      // NB: Wait a bit more time to handle effects so this test is less brittle in CI
      await store.finish(timeout: NSEC_PER_SEC)
  }
}
#endif
