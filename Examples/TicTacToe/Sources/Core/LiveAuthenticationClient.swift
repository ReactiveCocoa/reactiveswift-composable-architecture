import AuthenticationClient
import ComposableArchitecture
import Foundation
import ReactiveSwift

extension AuthenticationClient {
  public static let live = AuthenticationClient(
    login: { request in
      (request.email.contains("@") && request.password == "password"
        ? Effect(value: .init(token: "deadbeef", twoFactorRequired: request.email.contains("2fa")))
        : Effect(error: .invalidUserPassword))
        .delay(1, on: QueueScheduler(qos: .default, name: "auth", targeting: queue))
    },
    twoFactor: { request in
      (request.token != "deadbeef"
        ? Effect(error: .invalidIntermediateToken)
        : request.code != "1234"
          ? Effect(error: .invalidTwoFactor)
          : Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false)))
        .delay(1, on: QueueScheduler(qos: .default, name: "auth", targeting: queue))
    })
}

private let queue = DispatchQueue(label: "AuthenticationClient")
