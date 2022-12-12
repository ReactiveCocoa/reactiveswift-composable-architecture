import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class RefreshableTests: XCTestCase {
  func testHappyPath() async {
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: .unimplemented
    )

    store.environment.fact.fetch = { "\($0) is a good number." }
    store.environment.mainQueue = ImmediateScheduler()

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh)
    await store.receive(.factResponse(.success("1 is a good number."))) {
      $0.fact = "1 is a good number."
    }
  }

  func testUnhappyPath() async {
    struct FactError: Equatable, Error {}
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: .unimplemented
    )

    store.environment.fact.fetch = { _ in throw FactError() }
    store.environment.mainQueue = ImmediateScheduler()

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh)
    await store.receive(.factResponse(.failure(FactError())))
  }

  func testCancellation() async {
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = ImmediateScheduler()

    store.environment.fact.fetch = {
      try await Task.sleep(nanoseconds: NSEC_PER_SEC)
      return "\($0) is a good number."
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh)
    await store.send(.cancelButtonTapped)
  }
}

extension RefreshableEnvironment {
  static let unimplemented = Self(
    fact: .unimplemented,
    mainQueue: UnimplementedScheduler()
  )
}
