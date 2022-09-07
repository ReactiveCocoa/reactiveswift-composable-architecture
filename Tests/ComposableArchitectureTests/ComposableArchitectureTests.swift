import ComposableArchitecture
import ReactiveSwift
import XCTest

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
@MainActor
final class ComposableArchitectureTests: XCTestCase {
  func testScheduling() async {
    enum CounterAction: Equatable {
      case incrAndSquareLater
      case incrNow
      case squareNow
    }

    let counterReducer = Reducer<Int, CounterAction, DateScheduler> {
      state, action, scheduler in
      switch action {
      case .incrAndSquareLater:
        return .merge(
          Effect(value: .incrNow).deferred(for: 2, scheduler: scheduler),
          Effect(value: .squareNow).deferred(for: 1, scheduler: scheduler),
          Effect(value: .squareNow).deferred(for: 2, scheduler: scheduler)
        )
      case .incrNow:
        state += 1
        return .none
      case .squareNow:
        state *= state
        return .none
      }
    }

    let mainQueue = TestScheduler()

    let store = TestStore(
      initialState: 2,
      reducer: counterReducer,
      environment: mainQueue
    )

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
    let testScheduler = TestScheduler()

    var values: [Int] = []
    testScheduler.schedule(after: .seconds(0), interval: .seconds(1)) { values.append(1) }
    testScheduler.schedule(after: .seconds(0), interval: .seconds(2)) { values.append(42) }

    XCTAssertNoDifference(values, [])
    testScheduler.advance()
    XCTAssertNoDifference(values, [1, 42])
    testScheduler.advance(by: 2)
    XCTAssertNoDifference(values, [1, 42, 1, 42, 1])
  }

  func testLongLivingEffects() async {
    typealias Environment = (
      startEffect: Effect<Void, Never>,
      stopEffect: Effect<Never, Never>
    )

    enum Action { case end, incr, start }

    let reducer = Reducer<Int, Action, Environment> { state, action, environment in
      switch action {
      case .end:
        return environment.stopEffect.fireAndForget()
      case .incr:
        state += 1
        return .none
      case .start:
        return environment.startEffect.map { Action.incr }
      }
    }

    let subject = Signal<Void, Never>.pipe()

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: (
        startEffect: subject.output.producer.eraseToEffect(),
        stopEffect: .fireAndForget { subject.input.sendCompleted() }
      )
    )

    await store.send(.start)
    await store.send(.incr) { $0 = 1 }
    subject.input.send(value: ())
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

    struct Environment {
      let fetch: (Int) async -> Int
    }

    let reducer = Reducer<Int, Action, Environment> { state, action, environment in
      enum CancelID {}

      switch action {
      case .cancel:
        return .cancel(id: CancelID.self)

      case .incr:
        state += 1
        return .task { [state] in
          try await mainQueue.sleep(for: .seconds(1))
          return .response(await environment.fetch(state))
        }
        .cancellable(id: CancelID.self)

      case let .response(value):
        state = value
        return .none
      }
    }

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: Environment(
        fetch: { value in value * value }
      )
    )

    await store.send(.incr) { $0 = 1 }
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.response(1))

    await store.send(.incr) { $0 = 2 }
    await store.send(.cancel)
    await store.finish()
  }
}
#endif
