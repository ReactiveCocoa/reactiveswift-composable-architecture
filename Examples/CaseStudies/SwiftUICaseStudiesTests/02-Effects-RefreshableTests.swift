import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class RefreshableTests: XCTestCase {
  func testHappyPath() {
    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { .init(value: "\($0) is a good number.") },
        mainQueue: ImmediateScheduler()
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(.factResponse(.success("1 is a good number."))) {
      $0.isLoading = false
      $0.fact = "1 is a good number."
    }
  }

  func testUnhappyPath() {
    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { _ in .init(error: .init()) },
        mainQueue: ImmediateScheduler()
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(.factResponse(.failure(.init()))) {
      $0.isLoading = false
    }
  }

  func testCancellation() {
    let mainQueue = TestScheduler()

    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { .init(value: "\($0) is a good number.") },
        mainQueue: mainQueue
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.send(.cancelButtonTapped) {
      $0.isLoading = false
    }
  }
}
