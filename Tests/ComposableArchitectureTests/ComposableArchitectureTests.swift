import ComposableArchitecture
import ReactiveSwift
import XCTest

final class ComposableArchitectureTests: XCTestCase {
  func testScheduling() {
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
          Effect(value: .incrNow)
            .delay(2, on: scheduler),
          Effect(value: .squareNow)
            .delay(1, on: scheduler),
          Effect(value: .squareNow)
            .delay(2, on: scheduler)
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

    store.send(.incrAndSquareLater)
    mainQueue.advance(by: 1)
    store.receive(.squareNow) { $0 = 4 }
    mainQueue.advance(by: 1)
    store.receive(.incrNow) { $0 = 5 }
    store.receive(.squareNow) { $0 = 25 }

    store.send(.incrAndSquareLater)
    mainQueue.advance(by: 2)
    store.receive(.squareNow) { $0 = 625 }
    store.receive(.incrNow) { $0 = 626 }
    store.receive(.squareNow) { $0 = 391876 }
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

  func testLongLivingEffects() {
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
        startEffect: subject.output.producer,
        stopEffect: .fireAndForget { subject.input.sendCompleted() }
      )
    )

    store.send(.start)
    store.send(.incr) { $0 = 1 }
    subject.input.send(value: ())
    store.receive(.incr) { $0 = 2 }
    store.send(.end)
  }

  func testCancellation() {
    enum Action: Equatable {
      case cancel
      case incr
      case response(Int)
    }

    struct Environment {
      let fetch: (Int) -> Effect<Int, Never>
      let mainQueue: DateScheduler
    }

    let reducer = Reducer<Int, Action, Environment> { state, action, environment in
      enum CancelId {}

      switch action {
      case .cancel:
        return .cancel(id: CancelId.self)

      case .incr:
        state += 1
        return environment.fetch(state)
          .observe(on: environment.mainQueue)
          .map(Action.response)
          .cancellable(id: CancelId.self)

      case let .response(value):
        state = value
        return .none
      }
    }

    let mainQueue = TestScheduler()

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: Environment(
        fetch: { value in Effect(value: value * value) },
        mainQueue: mainQueue
      )
    )

    store.send(.incr) { $0 = 1 }
    mainQueue.advance()
    store.receive(.response(1))

    store.send(.incr) { $0 = 2 }
    store.send(.cancel)
    mainQueue.run()
  }
}
