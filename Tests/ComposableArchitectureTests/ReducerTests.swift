import ComposableArchitecture
import CustomDump
import ReactiveSwift
import XCTest

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
  @MainActor
  final class ReducerTests: XCTestCase {
    func testCallableAsFunction() {
      let reducer = Reduce<Int, Void> { state, _ in
        state += 1
        return .none
      }

      var state = 0
      _ = reducer.reduce(into: &state, action: ())
      XCTAssertEqual(state, 1)
    }

    func testCombine_EffectsAreMerged() async throws {
      typealias Scheduler = DateScheduler
      enum Action: Equatable {
        case increment
      }

      struct Delayed: ReducerProtocol {
        typealias State = Int

        @Dependency(\.mainQueue) var mainQueue

        let delay: DispatchTimeInterval
        let setValue: @Sendable () async -> Void

        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          state += 1
          return .fireAndForget {
            try await self.mainQueue.sleep(for: self.delay)
            await self.setValue()
          }
        }
      }

      var fastValue: Int? = nil
      var slowValue: Int? = nil

      let store = TestStore(
        initialState: 0,
        reducer: CombineReducers {
          Delayed(delay: .seconds(1), setValue: { @MainActor in fastValue = 42 })
          Delayed(delay: .seconds(2), setValue: { @MainActor in slowValue = 1729 })
        }
      )

      let mainQueue = TestScheduler()
      store.dependencies.mainQueue = mainQueue

      await store.send(.increment) {
        $0 = 2
      }
      // Waiting a second causes the fast effect to fire.
      await mainQueue.advance(by: 1)
      try await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
      XCTAssertEqual(fastValue, 42)
      XCTAssertEqual(slowValue, nil)
      // Waiting one more second causes the slow effect to fire. This proves that the effects
      // are merged together, as opposed to concatenated.
      await mainQueue.advance(by: 1)
      await store.finish()
      XCTAssertEqual(fastValue, 42)
      XCTAssertEqual(slowValue, 1729)
    }

    func testCombine() async {
      enum Action: Equatable {
        case increment
      }

      struct One: ReducerProtocol {
        typealias State = Int
        let effect: @Sendable () async -> Void
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          state += 1
          return .fireAndForget {
            await self.effect()
          }
        }
      }

      var first = false
      var second = false

      let store = TestStore(
        initialState: 0,
        reducer: CombineReducers {
          One(effect: { @MainActor in first = true })
          One(effect: { @MainActor in second = true })
        }
      )

      await store
        .send(.increment) { $0 = 2 }
        .finish()

      XCTAssertTrue(first)
      XCTAssertTrue(second)
    }

    #if DEBUG
      func testDebug() async {
        enum DebugAction: Equatable {
          case incrWithBool(Bool)
          case incr, noop
        }
        struct DebugState: Equatable { var count = 0 }

        var logs: [String] = []
        let logsExpectation = self.expectation(description: "logs")
        logsExpectation.expectedFulfillmentCount = 2

        let reducer = AnyReducer<DebugState, DebugAction, Void> { state, action, _ in
          switch action {
          case .incrWithBool:
            return .none
          case .incr:
            state.count += 1
            return .none
          case .noop:
            return .none
          }
        }
        .debug("[prefix]") { _ in
          DebugEnvironment(
            printer: {
              logs.append($0)
              logsExpectation.fulfill()
            }
          )
        }

        let store = TestStore(
          initialState: .init(),
          reducer: reducer,
          environment: ()
        )
        await store.send(.incr) { $0.count = 1 }
        await store.send(.noop)

        self.wait(for: [logsExpectation], timeout: 5)

        XCTAssertEqual(
          logs,
          [
            #"""
            [prefix]: received action:
              ReducerTests.DebugAction.incr
            - ReducerTests.DebugState(count: 0)
            + ReducerTests.DebugState(count: 1)

            """#,
            #"""
            [prefix]: received action:
              ReducerTests.DebugAction.noop
              (No state changes)

            """#,
          ]
        )
      }

      func testDebug_ActionFormat_OnlyLabels() {
        enum DebugAction: Equatable {
          case incrWithBool(Bool)
          case incr, noop
        }
        struct DebugState: Equatable { var count = 0 }

        var logs: [String] = []
        let logsExpectation = self.expectation(description: "logs")

        let reducer = AnyReducer<DebugState, DebugAction, Void> { state, action, _ in
          switch action {
          case let .incrWithBool(bool):
            state.count += bool ? 1 : 0
            return .none
          default:
            return .none
          }
        }
        .debug("[prefix]", actionFormat: .labelsOnly) { _ in
          DebugEnvironment(
            printer: {
              logs.append($0)
              logsExpectation.fulfill()
            }
          )
        }

        let viewStore = ViewStore(
          Store(
            initialState: .init(),
            reducer: reducer,
            environment: ()
          )
        )
        viewStore.send(.incrWithBool(true))

        self.wait(for: [logsExpectation], timeout: 5)

        XCTAssertEqual(
          logs,
          [
            #"""
            [prefix]: received action:
              ReducerTests.DebugAction.incrWithBool
            - ReducerTests.DebugState(count: 0)
            + ReducerTests.DebugState(count: 1)

            """#
          ]
        )
      }
    #endif

    #if canImport(os)
      @available(iOS 12.0, *)
      func testDefaultSignpost() {
        let reducer = EmptyReducer<Int, Void>().signpost(log: .default)
        var n = 0
        let effect = reducer.reduce(into: &n, action: ())
        let expectation = self.expectation(description: "effect")
        effect
          .producer
          .startWithCompleted {
            expectation.fulfill()
          }
        self.wait(for: [expectation], timeout: 0.1)
      }

      @available(iOS 12.0, *)
      func testDisabledSignpost() {
        let reducer = EmptyReducer<Int, Void>().signpost(log: .disabled)
        var n = 0
        let effect = reducer.reduce(into: &n, action: ())
        let expectation = self.expectation(description: "effect")
        effect
          .producer
          .startWithCompleted {
            expectation.fulfill()
          }
        self.wait(for: [expectation], timeout: 0.1)
      }
    #endif
  }
#endif
