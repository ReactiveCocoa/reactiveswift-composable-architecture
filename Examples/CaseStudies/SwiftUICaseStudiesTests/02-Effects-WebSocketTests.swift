import ReactiveSwift
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class WebSocketTests: XCTestCase {
  let scheduler = TestScheduler()

  func testWebSocketHappyPath() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()
    let receiveSubject = Signal<WebSocketClient.Message, NSError>.pipe()

    let testStore = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: self.scheduler,
        webSocket: .mock(
          open: { _, _, _ in socketSubject.output.producer },
          receive: { _ in receiveSubject.output.producer },
          send: { _, _ in Effect(value: nil) },
          sendPing: { _ in .none }
        )
      )
    )

    testStore.assert(
      // Connect to the socket
      .send(.connectButtonTapped) {
        $0.connectivityState = .connecting
      },
      .do { socketSubject.input.send(value: .didOpenWithProtocol(nil)) },
      .do { self.scheduler.advance() },
      .receive(.webSocket(.didOpenWithProtocol(nil))) {
        $0.connectivityState = .connected
      },

      // Send a message
      .send(.messageToSendChanged("Hi")) {
        $0.messageToSend = "Hi"
      },
      .send(.sendButtonTapped) {
        $0.messageToSend = ""
      },
      .receive(.sendResponse(nil)),

      // Receive a message
      .do { receiveSubject.input.send(value: .string("Hi")) },
      .do { self.scheduler.advance() },
      .receive(.receivedSocketMessage(.success(.string("Hi")))) {
        $0.receivedMessages = ["Hi"]
      },

      // Disconnect from the socket
      .send(.connectButtonTapped) {
        $0.connectivityState = .disconnected
      }
    )
  }

  func testWebSocketSendFailure() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()
    let receiveSubject = Signal<WebSocketClient.Message, NSError>.pipe()

    let testStore = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: self.scheduler,
        webSocket: .mock(
          open: { _, _, _ in socketSubject.output.producer },
          receive: { _ in receiveSubject.output.producer },
          send: { _, _ in Effect(value: NSError(domain: "", code: 1)) },
          sendPing: { _ in .none }
        )
      )
    )

    testStore.assert(
      // Connect to the socket
      .send(.connectButtonTapped) {
        $0.connectivityState = .connecting
      },
      .do { socketSubject.input.send(value: .didOpenWithProtocol(nil)) },
      .do { self.scheduler.advance() },
      .receive(.webSocket(.didOpenWithProtocol(nil))) {
        $0.connectivityState = .connected
      },

      // Send a message
      .send(.messageToSendChanged("Hi")) {
        $0.messageToSend = "Hi"
      },
      .send(.sendButtonTapped) {
        $0.messageToSend = ""
      },
      .receive(.sendResponse(NSError(domain: "", code: 1))) {
        $0.alert = .init(title: "Could not send socket message. Try again.")
      },

      // Disconnect from the socket
      .send(.connectButtonTapped) {
        $0.connectivityState = .disconnected
      }
    )
  }

  func testWebSocketPings() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()
    let pingSubject = Signal<NSError?, Never>.pipe()

    let testStore = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: self.scheduler,
        webSocket: .mock(
          open: { _, _, _ in socketSubject.output.producer },
          receive: { _ in .none },
          sendPing: { _ in pingSubject.output.producer }
        )
      )
    )

    testStore.assert(
      .send(.connectButtonTapped) {
        $0.connectivityState = .connecting
      },

      .do { socketSubject.input.send(value: .didOpenWithProtocol(nil)) },
      .do { self.scheduler.advance() },
      .receive(.webSocket(.didOpenWithProtocol(nil))) {
        $0.connectivityState = .connected
      },

      .do { pingSubject.input.send(value: nil) },
      .do { self.scheduler.advance(by: .seconds(5)) },
      .do { self.scheduler.advance(by: .seconds(5)) },
      .receive(.pingResponse(nil)),

      .send(.connectButtonTapped) {
        $0.connectivityState = .disconnected
      }
    )
  }

  func testWebSocketConnectError() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()

    let testStore = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: self.scheduler,
        webSocket: .mock(
          cancel: { _, _, _ in .fireAndForget { socketSubject.input.sendCompleted() } },
          open: { _, _, _ in socketSubject.output.producer },
          receive: { _ in .none },
          sendPing: { _ in .none }
        )
      )
    )

    testStore.assert(
      .send(.connectButtonTapped) {
        $0.connectivityState = .connecting
      },

      .do { socketSubject.input.send(value: .didClose(code: .internalServerError, reason: nil)) },
      .do { self.scheduler.advance() },
      .receive(.webSocket(.didClose(code: .internalServerError, reason: nil))) {
        $0.connectivityState = .disconnected
      }
    )
  }
}

extension WebSocketClient {
  static func mock(
    cancel: @escaping (AnyHashable, URLSessionWebSocketTask.CloseCode, Data?) -> Effect<
      Never, Never
    > = { _, _, _ in fatalError() },
    open: @escaping (AnyHashable, URL, [String]) -> Effect<Action, Never> = { _, _, _ in
      fatalError()
    },
    receive: @escaping (AnyHashable) -> Effect<Message, NSError> = { _ in fatalError() },
    send: @escaping (AnyHashable, URLSessionWebSocketTask.Message) -> Effect<NSError?, Never> = {
      _, _ in fatalError()
    },
    sendPing: @escaping (AnyHashable) -> Effect<NSError?, Never> = { _in in fatalError() }
  ) -> Self {
    Self(
      cancel: cancel,
      open: open,
      receive: receive,
      send: send,
      sendPing: sendPing
    )
  }
}
