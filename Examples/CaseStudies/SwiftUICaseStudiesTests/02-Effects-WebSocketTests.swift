import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class WebSocketTests: XCTestCase {
  func testWebSocketHappyPath() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()
    let receiveSubject = Signal<WebSocketClient.Message, NSError>.pipe()

    var webSocket = WebSocketClient.unimplemented
    webSocket.open = { _, _, _ in socketSubject.output.producer }
    webSocket.receive = { _ in receiveSubject.output.producer }
    webSocket.send = { _, _ in Effect(value: nil) }
    webSocket.sendPing = { _ in .none }

    let store = TestStore(
      initialState: WebSocketState(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: ImmediateScheduler(),
        webSocket: webSocket
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

    var webSocket = WebSocketClient.unimplemented
    webSocket.open = { _, _, _ in socketSubject.output.producer }
    webSocket.receive = { _ in receiveSubject.output.producer }
    webSocket.send = { _, _ in Effect(value: NSError(domain: "", code: 1)) }
    webSocket.sendPing = { _ in .none }

    let store = TestStore(
      initialState: WebSocketState(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: ImmediateScheduler(),
        webSocket: webSocket
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
      $0.alert = AlertState(title: TextState("Could not send socket message. Try again."))
    }

    // Disconnect from the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketPings() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()
    let pingSubject = Signal<NSError?, Never>.pipe()

    var webSocket = WebSocketClient.unimplemented
    webSocket.open = { _, _, _ in socketSubject.output.producer }
    webSocket.receive = { _ in .none }
    webSocket.sendPing = { _ in pingSubject.output.producer }

    let mainQueue = TestScheduler()
    let store = TestStore(
      initialState: WebSocketState(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: mainQueue,
        webSocket: webSocket
      )
    )

    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }

    socketSubject.input.send(value: .didOpenWithProtocol(nil))
    mainQueue.advance()
    store.receive(.webSocket(.didOpenWithProtocol(nil))) {
      $0.connectivityState = .connected
    }

    pingSubject.input.send(value: nil)
    mainQueue.advance(by: 5)
    mainQueue.advance(by: 5)
    store.receive(.pingResponse(nil))

    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketConnectError() {
    let socketSubject = Signal<WebSocketClient.Action, Never>.pipe()

    var webSocket = WebSocketClient.unimplemented
    webSocket.cancel = { _, _, _ in .fireAndForget { socketSubject.input.sendCompleted() } }
    webSocket.open = { _, _, _ in socketSubject.output.producer }
    webSocket.receive = { _ in .none }
    webSocket.sendPing = { _ in .none }

    let store = TestStore(
      initialState: WebSocketState(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: ImmediateScheduler(),
        webSocket: webSocket
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
  static let unimplemented = Self(
    cancel: { _, _, _ in .unimplemented("\(Self.self).cancel") },
    open: { _, _, _ in .unimplemented("\(Self.self).open") },
    receive: { _ in .unimplemented("\(Self.self).receive") },
    send: { _, _ in .unimplemented("\(Self.self).send") },
    sendPing: { _ in .unimplemented("\(Self.self).sendPing") }
  )
}
