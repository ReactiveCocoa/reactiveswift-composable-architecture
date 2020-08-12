import Foundation
import ReactiveSwift

/// A store represents the runtime that powers the application. It is the object that you will pass
/// around to views that need to interact with the application.
///
/// You will typically construct a single one of these at the root of your application, and then use
/// the `scope` method to derive more focused stores that can be passed to subviews.
public final class Store<State, Action> {
  @MutableProperty private(set) var state: State
  private var isSending = false
  private let reducer: (inout State, Action) -> Effect<Action, Never>
  private var synchronousActionsToSend: [Action] = []

  /// Initializes a store from an initial state, a reducer, and an environment.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - environment: The environment of dependencies for the application.
  public convenience init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init(
      initialState: initialState,
      reducer: { reducer.run(&$0, $1, environment) }
    )
  }

  /// Scopes the store to one that exposes local state and actions.
  ///
  /// This can be useful for deriving new stores to hand to child views in an application. For
  /// example:
  ///
  ///     // Application state made from local states.
  ///     struct AppState { var login: LoginState, ... }
  ///     struct AppAction { case login(LoginAction), ... }
  ///
  ///     // A store that runs the entire application.
  ///     let store = Store(initialState: AppState(), reducer: appReducer, environment: ())
  ///
  ///     // Construct a login view by scoping the store to one that works with only login domain.
  ///     let loginView = LoginView(
  ///       store: store.scope(
  ///         state: { $0.login },
  ///         action: { AppAction.login($0) }
  ///       )
  ///     )
  ///
  /// - Parameters:
  ///   - toLocalState: A function that transforms `State` into `LocalState`.
  ///   - fromLocalAction: A function that transforms `LocalAction` into `Action`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<LocalState, LocalAction>(
    state toLocalState: @escaping (State) -> LocalState,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> Store<LocalState, LocalAction> {
    let localStore = Store<LocalState, LocalAction>(
      initialState: toLocalState(self.state),
      reducer: { localState, localAction in
        self.send(fromLocalAction(localAction))
        localState = toLocalState(self.state)
        return .none
      }
    )
    self.$state.producer
      .startWithValues { [weak localStore] newValue in localStore?.state = toLocalState(newValue) }
    return localStore
  }

  /// Scopes the store to one that exposes local state.
  ///
  /// - Parameter toLocalState: A function that transforms `State` into `LocalState`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<LocalState>(
    state toLocalState: @escaping (State) -> LocalState
  ) -> Store<LocalState, Action> {
    self.scope(state: toLocalState, action: { $0 })
  }

  /// Scopes the store to a producer of stores of more local state and local actions.
  ///
  /// - Parameters:
  ///   - toLocalState: A function that transforms a producer of `State` into a producer of
  ///     `LocalState`.
  ///   - fromLocalAction: A function that transforms `LocalAction` into `Action`.
  /// - Returns: A producer of stores with its domain (state and action) transformed.
  public func scope<LocalState, LocalAction>(
    state toLocalState: @escaping (Effect<State, Never>) -> Effect<LocalState, Never>,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> Effect<Store<LocalState, LocalAction>, Never> {

    func extractLocalState(_ state: State) -> LocalState? {
      var localState: LocalState?
      _ = toLocalState(Effect(value: state))
        .startWithValues { localState = $0 }
      return localState
    }

    return toLocalState(self.$state.producer)
      .map { localState in
        let localStore = Store<LocalState, LocalAction>(
          initialState: localState,
          reducer: { localState, localAction in
            self.send(fromLocalAction(localAction))
            localState = extractLocalState(self.state) ?? localState
            return .none
          })

        self.$state.producer
          .startWithValues { [weak localStore] state in
            guard let localStore = localStore else { return }
            localStore.state = extractLocalState(state) ?? localStore.state
          }
        return localStore
      }
  }

  /// Scopes the store to a producer of stores of more local state and local actions.
  ///
  /// - Parameter toLocalState: A function that transforms a producer of `State` into a producer
  ///   of `LocalState`.
  /// - Returns: A producer of stores with its domain (state and action)
  ///   transformed.
  public func scope<LocalState>(
    state toLocalState: @escaping (Effect<State, Never>) -> Effect<LocalState, Never>
  ) -> Effect<Store<LocalState, Action>, Never> {
    self.scope(state: toLocalState, action: { $0 })
  }

  func send(_ action: Action) {
    self.synchronousActionsToSend.append(action)

    while !self.synchronousActionsToSend.isEmpty {
      let action = self.synchronousActionsToSend.removeFirst()

      if self.isSending {
        assertionFailure(
          """
          The store was sent the action \(debugCaseOutput(action)) while it was already 
          processing another action.

          This can happen for a few reasons:

          * The store was sent an action recursively. This can occur when you run an effect \
          directly in the reducer, rather than returning it from the reducer. Check the stack (⌘7) \
          to find frames corresponding to one of your reducers. That code should be refactored to \
          not invoke the effect directly.

          * The store has been sent actions from multiple threads. The `send` method is not \
          thread-safe, and should only ever be used from a single thread (typically the main \
          thread). Instead of calling `send` from multiple threads you should use effects to \
          process expensive computations on background threads so that it can be fed back into the \
          store.
          """
        )
      }
      self.isSending = true
      let effect = self.reducer(&self.state, action)
      self.isSending = false

      var isProcessingEffects = true
      effect.startWithValues { [weak self] action in
        if isProcessingEffects {
          self?.synchronousActionsToSend.append(action)
        } else {
          self?.send(action)
        }
      }
      isProcessingEffects = false
    }
  }

  /// Returns a "stateless" store by erasing state to `Void`.
  public var stateless: Store<Void, Action> {
    self.scope(state: { _ in () })
  }

  /// Returns an "actionless" store by erasing action to `Never`.
  public var actionless: Store<State, Never> {
    func absurd<A>(_ never: Never) -> A {}
    return self.scope(state: { $0 }, action: absurd)
  }

  private init(
    initialState: State,
    reducer: @escaping (inout State, Action) -> Effect<Action, Never>
  ) {
    self.reducer = reducer
    self.state = initialState
  }
}

/// A producer of store state.
@dynamicMemberLookup
public struct Produced<Value>: SignalProducerConvertible {
  public let producer: Effect<Value, Never>

  init(by upstream: Effect<Value, Never>) {
    self.producer = upstream
  }

  /// Returns the resulting producer of a given key path.
  public subscript<LocalValue>(
    dynamicMember keyPath: KeyPath<Value, LocalValue>
  ) -> Effect<LocalValue, Never> where LocalValue: Equatable {
    self.producer.map(keyPath).skipRepeats()
  }
}

@available(
  *, deprecated,
  message:
    """
Consider using `Produced<State>` instead, this typealias is added for backward compatibility and will be removed in the next major release.
"""
)
public typealias StoreProducer<State> = Produced<State>
