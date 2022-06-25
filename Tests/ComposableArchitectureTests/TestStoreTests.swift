import ComposableArchitecture
import ReactiveSwift
import XCTest

class TestStoreTests: XCTestCase {
  func testEffectConcatenation() {
    struct State: Equatable {}

    enum Action: Equatable {
      case a, b1, b2, b3, c1, c2, c3, d
    }

    let testScheduler = TestScheduler()

    let reducer = Reducer<State, Action, DateScheduler> { _, action, scheduler in
      switch action {
      case .a:
        return .merge(
          Effect.concatenate(.init(value: .b1), .init(value: .c1))
            .delay(1, on: scheduler),
          Effect.none
            .cancellable(id: 1)
        )
      case .b1:
        return
          Effect
          .concatenate(.init(value: .b2), .init(value: .b3))
      case .c1:
        return
          Effect
          .concatenate(.init(value: .c2), .init(value: .c3))
      case .b2, .b3, .c2, .c3:
        return .none

      case .d:
        return .cancel(id: 1)
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer,
      environment: testScheduler
    )

    store.send(.a)

    testScheduler.advance(by: 1)

    store.receive(.b1)
    store.receive(.b2)
    store.receive(.b3)

    store.receive(.c1)
    store.receive(.c2)
    store.receive(.c3)

    store.send(.d)
  }

  // XCTExpectFailure is not supported on Linux
  #if !os(Linux)
  func testExpectedStateEquality() {
    struct State: Equatable {
      var count: Int = 0
      var isChanging: Bool = false
    }

    enum Action: Equatable {
      case increment, changed(from: Int, to: Int)
    }

    let reducer = Reducer<State, Action, Void> { state, action, scheduler in
      switch action {
      case .increment:
        state.isChanging = true
        return Effect(value: .changed(from: state.count, to: state.count + 1))
      case .changed(let from, let to):
        state.isChanging = false
        if state.count == from {
          state.count = to
        }
        return .none
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer,
      environment: ()
    )

    store.send(.increment) {
      $0.isChanging = true
    }
    store.receive(.changed(from: 0, to: 1)) {
      $0.isChanging = false
      $0.count = 1
    }

    XCTExpectFailure {
      store.send(.increment) {
        $0.isChanging = false
      }
    }
    XCTExpectFailure {
      store.receive(.changed(from: 1, to: 2)) {
        $0.isChanging = true
        $0.count = 1100
      }
    }
  }
  
  func testExpectedStateEqualityMustModify() {
    struct State: Equatable {
      var count: Int = 0
    }

    enum Action: Equatable {
      case noop, finished
    }

    let reducer = Reducer<State, Action, Void> { state, action, scheduler in
      switch action {
      case .noop:
        return Effect(value: .finished)
      case .finished:
        return .none
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer,
      environment: ()
    )

    store.send(.noop)
    store.receive(.finished)

    XCTExpectFailure {
      store.send(.noop) {
        $0.count = 0
      }
    }
    XCTExpectFailure {
      store.receive(.finished) {
        $0.count = 0
      }
    }
  }
  #endif

  func testStateAccess() {
    enum Action { case a, b, c, d }
    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Action, Void> { count, action, _ in
        switch action {
        case .a:
          count += 1
          return .merge(Effect(value: .b), Effect(value: .c), Effect(value: .d))
        case .b, .c, .d:
          count += 1
          return .none
        }
      },
      environment: ()
    )

    store.send(.a) {
      $0 = 1
      XCTAssertEqual(store.state, 0)
    }
    XCTAssertEqual(store.state, 1)
    store.receive(.b) {
      $0 = 2
      XCTAssertEqual(store.state, 1)
    }
    XCTAssertEqual(store.state, 2)
    store.receive(.c) {
      $0 = 3
      XCTAssertEqual(store.state, 2)
    }
    XCTAssertEqual(store.state, 3)
    store.receive(.d) {
      $0 = 4
      XCTAssertEqual(store.state, 3)
    }
    XCTAssertEqual(store.state, 4)
  }
}
