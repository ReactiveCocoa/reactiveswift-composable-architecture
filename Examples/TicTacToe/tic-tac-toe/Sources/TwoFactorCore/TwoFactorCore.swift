import AuthenticationClient
import ComposableArchitecture
import Dispatch

public struct TwoFactorState: Equatable {
  public var alert: AlertState<TwoFactorAction>?
  public var code = ""
  public var isFormValid = false
  public var isTwoFactorRequestInFlight = false
  public let token: String

  public init(token: String) {
    self.token = token
  }
}

public enum TwoFactorAction: Equatable {
  case alertDismissed
  case codeChanged(String)
  case submitButtonTapped
  case twoFactorResponse(TaskResult<AuthenticationResponse>)
}

public enum TwoFactorTearDownToken {}

public struct TwoFactorEnvironment: Sendable {
  public var authenticationClient: AuthenticationClient

  public init(
    authenticationClient: AuthenticationClient
  ) {
    self.authenticationClient = authenticationClient
  }
}

public let twoFactorReducer = Reducer<TwoFactorState, TwoFactorAction, TwoFactorEnvironment> {
  state, action, environment in

  switch action {
  case .alertDismissed:
    state.alert = nil
    return .none

  case let .codeChanged(code):
    state.code = code
    state.isFormValid = code.count >= 4
    return .none

  case .submitButtonTapped:
    state.isTwoFactorRequestInFlight = true
    return .task { [code = state.code, token = state.token] in
      .twoFactorResponse(
        await TaskResult {
          try await environment.authenticationClient.twoFactor(.init(code: code, token: token))
        }
      )
    }
    .cancellable(id: TwoFactorTearDownToken.self)

  case let .twoFactorResponse(.failure(error)):
    state.alert = AlertState(title: TextState(error.localizedDescription))
    state.isTwoFactorRequestInFlight = false
    return .none

  case let .twoFactorResponse(.success(response)):
    state.isTwoFactorRequestInFlight = false
    return .none
  }
}
