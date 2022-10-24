@_spi(Canary) import ComposableArchitecture
import ReactiveSwift
import XCTest

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
@MainActor
final class EffectTests: XCTestCase {
    let mainQueue = TestScheduler()

    func testEraseToEffectWithError() {
    struct Error: Swift.Error, Equatable {}

      SignalProducer<Int, Error>(result: .success(42))
        .startWithResult { XCTAssertNoDifference($0, .success(42)) }

      SignalProducer<Int, Error>(result: .failure(Error()))
        .startWithResult { XCTAssertNoDifference($0, .failure(Error())) }

      SignalProducer<Int, Never>(result: .success(42))
        .startWithResult { XCTAssertNoDifference($0, .success(42)) }

      SignalProducer<Int, Never>(result: .success(42))
      .catchToEffect {
        switch $0 {
        case let .success(val):
          return val
        case .failure:
          return -1
        }
      }
        .producer
        .startWithValues { XCTAssertNoDifference($0, 42) }

      SignalProducer<Int, Error>(result: .failure(Error()))
      .catchToEffect {
        switch $0 {
        case let .success(val):
          return val
        case .failure:
          return -1
        }
      }
        .producer
        .startWithValues { XCTAssertNoDifference($0, -1) }
  }

#if canImport(RoomPlan) || (!canImport(Darwin) && swift(>=5.7))
    func testConcatenate() async {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        let clock = TestClock()
    var values: [Int] = []

        let effect = Effect<Int, Never>.concatenate(
          (1...3).map { count in
            .task {
              try await clock.sleep(for: .seconds(count))
              return count
            }
          }
    )

      effect.producer.startWithValues { values.append($0) }

    XCTAssertEqual(values, [])

        await clock.advance(by: .seconds(1))
    XCTAssertEqual(values, [1])

        await clock.advance(by: .seconds(2))
    XCTAssertEqual(values, [1, 2])

        await clock.advance(by: .seconds(3))
    XCTAssertEqual(values, [1, 2, 3])

        await clock.run()
    XCTAssertEqual(values, [1, 2, 3])
  }
    }
  #endif

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = EffectTask<Int>.concatenate(
        EffectTask(value: 1).deferred(for: 1, scheduler: mainQueue)
    )

      effect.producer.startWithValues { values.append($0) }

    XCTAssertEqual(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.mainQueue.run()
    XCTAssertEqual(values, [1])
  }

#if canImport(RoomPlan) || (!canImport(Darwin) && swift(>=5.7))
  func testMerge() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      let clock = TestClock()

      let effect = Effect<Int, Never>.merge(
        (1...3).map { count in
          .task {
            try await clock.sleep(for: .seconds(count))
            return count
          }
        }
    )

    var values: [Int] = []
      effect.producer.startWithValues { values.append($0) }

    XCTAssertEqual(values, [])

      await clock.advance(by: .seconds(1))
    XCTAssertEqual(values, [1])

      await clock.advance(by: .seconds(1))
    XCTAssertEqual(values, [1, 2])

      await clock.advance(by: .seconds(1))
    XCTAssertEqual(values, [1, 2, 3])
  }
  }
  #endif

    func testEffectRunInitializer() {
      let effect = EffectTask<Int>.run { observer in
        observer.send(value: 1)
        observer.send(value: 2)
        self.mainQueue.schedule(after: self.mainQueue.currentDate.addingTimeInterval(1)) {
          observer.send(value: 3)
      }
        self.mainQueue.schedule(after: self.mainQueue.currentDate.addingTimeInterval(2)) {
          observer.send(value: 4)
          observer.sendCompleted()
      }

        return AnyDisposable()
    }

    var values: [Int] = []
    var isComplete = false
    effect
        .producer
        .on(completed: { isComplete = true }, value: { values.append($0) })
        .start()

    XCTAssertEqual(values, [1, 2])
    XCTAssertEqual(isComplete, false)

    self.mainQueue.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3])
    XCTAssertEqual(isComplete, false)

    self.mainQueue.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3, 4])
    XCTAssertEqual(isComplete, true)
  }

    func testEffectRunInitializer_WithCancellation() {
    enum CancelID {}

    let effect = EffectTask<Int>.run { subscriber in
        subscriber.send(value: 1)
        self.mainQueue.schedule(after: self.mainQueue.currentDate.addingTimeInterval(1)) {
          subscriber.send(value: 2)
      }
        return AnyDisposable()
    }
    .cancellable(id: CancelID.self)

    var values: [Int] = []
    var isComplete = false
    effect
        .producer
        .on(completed: { isComplete = true })
        .startWithValues { values.append($0) }

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, false)

    EffectTask<Void>.cancel(id: CancelID.self)
        .producer
        .startWithValues { _ in }

    self.mainQueue.advance(by: 1)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, true)
  }

  func testDoubleCancelInFlight() {
    var result: Int?

      _ = Effect(value: 42)
      .cancellable(id: "id", cancelInFlight: true)
      .cancellable(id: "id", cancelInFlight: true)
        .producer
        .startWithValues { result = $0 }

    XCTAssertEqual(result, 42)
  }

    #if DEBUG && !os(Linux)
    func testUnimplemented() {
        let effect = EffectTask<Never>.failing("unimplemented")
        _ = XCTExpectFailure {
        effect
            .producer
            .start()
      } issueMatcher: { issue in
        issue.compactDescription == "unimplemented - An unimplemented effect ran."
      }
    }
  #endif

    #if canImport(_Concurrency) && compiler(>=5.5.2)
  func testTask() async {
    guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }
    let effect = EffectTask<Int>.task { 42 }
        for await result in effect.producer.values {
      XCTAssertEqual(result, 42)
    }
  }

  func testCancellingTask_Infallible() {
    @Sendable func work() async -> Int {
      do {
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        XCTFail()
      } catch {
      }
      return 42
    }

        let disposable = EffectTask<Int>.task { await work() }
          .producer
          .on(
            completed: { XCTFail() },
            value: { _ in XCTFail() }
      )
          .start(on: QueueScheduler.main)
          .start()

        disposable.dispose()

    _ = XCTWaiter.wait(for: [.init()], timeout: 1.1)
  }
    #endif

  func testDependenciesTransferredToEffects_Task() async {
    struct Feature: ReducerProtocol {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      func reduce(into state: inout Int, action: Action) -> EffectTask<Action> {
        switch action {
        case .tap:
          return .task {
            .response(Int(self.date.now.timeIntervalSinceReferenceDate))
          }
        case let .response(value):
          state = value
          return .none
        }
      }
    }
    let store = TestStore(
      initialState: 0,
      reducer: Feature()
        .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
    )

    await store.send(.tap).finish(timeout: NSEC_PER_SEC)
    await store.receive(.response(1_234_567_890)) {
      $0 = 1_234_567_890
    }
  }

  func testDependenciesTransferredToEffects_Run() async {
    struct Feature: ReducerProtocol {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      func reduce(into state: inout Int, action: Action) -> Effect<Action, Never> {
        switch action {
        case .tap:
          return .run { send in
            await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
          }
        case let .response(value):
          state = value
          return .none
        }
      }
    }
    let store = TestStore(
      initialState: 0,
      reducer: Feature()
        .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
    )

    await store.send(.tap).finish(timeout: NSEC_PER_SEC)
    await store.receive(.response(1_234_567_890)) {
      $0 = 1_234_567_890
    }
  }

  func testMap() async {
    @Dependency(\.date) var date
    let effect =
      DependencyValues
      .withValue(\.date, .init { Date(timeIntervalSince1970: 1_234_567_890) }) {
        EffectTask<Void>(value: ())
          .map { date() }
      }
    var output: Date?
    effect
        .producer
        .startWithValues { output = $0 }
    XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))

    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      let effect =
        DependencyValues
        .withValue(\.date, .init { Date(timeIntervalSince1970: 1_234_567_890) }) {
          EffectTask<Void>.task {}
            .map { date() }
        }
      output = await effect.values.first(where: { _ in true })
      XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))
    }
  }

  func testCanary1() async {
    for _ in 1...100 {
      let task = TestStoreTask(rawValue: Task {}, timeout: NSEC_PER_SEC)
      await task.finish()
    }
  }
  func testCanary2() async {
    for _ in 1...100 {
      let task = TestStoreTask(rawValue: nil, timeout: NSEC_PER_SEC)
      await task.finish()
    }
  }
}
#endif
