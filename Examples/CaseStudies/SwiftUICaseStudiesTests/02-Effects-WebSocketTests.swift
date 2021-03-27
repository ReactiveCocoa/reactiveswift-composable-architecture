import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class WebSocketTests: XCTestCase {
  func testWebSocketHappyPath() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()
    let receiveSubject = Signal<WebSocketClient.Message, NSError>.pipe()

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: ImmediateScheduler(),
        webSocket: .mock(
          open: { _, _, _ in socketSubject.output.producer },
          receive: { _ in receiveSubject.output.producer },
          send: { _, _ in Effect(value: nil) },
          sendPing: { _ in .none }
        )
      )
    )

    // Connect to the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    socketSubject.input.send(value: .didOpenWithProtocol(nil))
    store.receive(.webSocket(.didOpenWithProtocol(nil))) {
      $0.connectivityState = .connected
    }

    // Send a message
    store.send(.messageToSendChanged("Hi")) {
      $0.messageToSend = "Hi"
    }
    store.send(.sendButtonTapped) {
      $0.messageToSend = ""
    }
    store.receive(.sendResponse(nil))

    // Receive a message
    receiveSubject.input.send(value: .string("Hi"))
    store.receive(.receivedSocketMessage(.success(.string("Hi")))) {
      $0.receivedMessages = ["Hi"]
    }

    // Disconnect from the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketSendFailure() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()
    let receiveSubject = Signal<WebSocketClient.Message, NSError>.pipe()

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: ImmediateScheduler(),
        webSocket: .mock(
          open: { _, _, _ in socketSubject.output.producer },
          receive: { _ in receiveSubject.output.producer },
          send: { _, _ in Effect(value: NSError(domain: "", code: 1)) },
          sendPing: { _ in .none }
        )
      )
    )

    // Connect to the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    socketSubject.input.send(value: .didOpenWithProtocol(nil))
    store.receive(.webSocket(.didOpenWithProtocol(nil))) {
      $0.connectivityState = .connected
    }

    // Send a message
    store.send(.messageToSendChanged("Hi")) {
      $0.messageToSend = "Hi"
    }
    store.send(.sendButtonTapped) {
      $0.messageToSend = ""
    }
    store.receive(.sendResponse(NSError(domain: "", code: 1))) {
      $0.alert = .init(title: .init("Could not send socket message. Try again."))
    }

    // Disconnect from the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketPings() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()
    let pingSubject = Signal<NSError?, Never>.pipe()

    let scheduler = TestScheduler()
    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: scheduler,
        webSocket: .mock(
          open: { _, _, _ in socketSubject.output.producer },
          receive: { _ in .none },
          sendPing: { _ in pingSubject.output.producer }
        )
      )
    )

    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }

    socketSubject.input.send(value: .didOpenWithProtocol(nil))
    scheduler.advance()
    store.receive(.webSocket(.didOpenWithProtocol(nil))) {
      $0.connectivityState = .connected
    }

    pingSubject.input.send(value: nil)
    scheduler.advance(by: .seconds(5))
    scheduler.advance(by: .seconds(5))
    store.receive(.pingResponse(nil))

    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketConnectError() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: ImmediateScheduler(),
        webSocket: .mock(
          cancel: { _, _, _ in .fireAndForget { socketSubject.input.sendCompleted() } },
          open: { _, _, _ in socketSubject.output.producer },
          receive: { _ in .none },
          sendPing: { _ in .none }
        )
      )
    )

    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }

    socketSubject.input.send(value: .didClose(code: .internalServerError, reason: nil))
    store.receive(.webSocket(.didClose(code: .internalServerError, reason: nil))) {
      $0.connectivityState = .disconnected
    }
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
