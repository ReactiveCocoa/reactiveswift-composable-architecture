import ReactiveSwift
import Foundation

/// A store represents the runtime that powers the application. It is the object that you will pass
/// around to views that need to interact with the application.
///
/// You will typically construct a single one of these at the root of your application, and then use
/// the `scope` method to derive more focused stores that can be passed to subviews.
public final class Store<State, Action> {
  @MutableProperty private(set) var state: State
  var effectCancellables: [UUID: Disposable] = [:]
  private var isSending = false
  private var parentCancellable: Disposable?
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
    localStore.parentCancellable = self.$state.signal
      .observeValues { [weak localStore] newValue in localStore?.state = toLocalState(newValue) }

//    localStore.parentCancellable = self.$state.producer
//      .startWithValues { [weak localStore] newValue in localStore?.state = toLocalState(newValue) }
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

  /// Scopes the store to a publisher of stores of more local state and local actions.
  ///
  /// - Parameters:
  ///   - toLocalState: A function that transforms a publisher of `State` into a publisher of
  ///     `LocalState`.
  ///   - fromLocalAction: A function that transforms `LocalAction` into `Action`.
  /// - Returns: A publisher of stores with its domain (state and action) transformed.
  public func scope<LocalState, LocalAction>(
    state toLocalState: @escaping (SignalProducer<State, Never>) -> SignalProducer<LocalState, Never>,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> SignalProducer<Store<LocalState, LocalAction>, Never> {

    func extractLocalState(_ state: State) -> LocalState? {
      var localState: LocalState?
      _ = toLocalState(SignalProducer.init(value: state))
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

        localStore.parentCancellable = self.$state.producer
          .startWithValues { [weak localStore] state in
            guard let localStore = localStore else { return }
            localStore.state = extractLocalState(state) ?? localStore.state
          }
        return localStore
      }
  }

  /// Scopes the store to a publisher of stores of more local state and local actions.
  ///
  /// - Parameter toLocalState: A function that transforms a publisher of `State` into a publisher
  ///   of `LocalState`.
  /// - Returns: A publisher of stores with its domain (state and action)
  ///   transformed.
  public func scope<LocalState>(
    state toLocalState: @escaping (SignalProducer<State, Never>) -> SignalProducer<LocalState, Never>
  ) -> SignalProducer<Store<LocalState, Action>, Never> {
    self.scope(state: toLocalState, action: { $0 })
  }

  func send(_ action: Action) {
    if self.isSending {
      assertionFailure(
        """
        The store was sent an action recursively. This can occur when you run an effect directly \
        in the reducer, rather than returning it from the reducer. Check the stack (⌘7) to find \
        frames corresponding to one of your reducers. That code should be refactored to not invoke \
        the effect directly.
        """
      )
    }
    self.isSending = true
    let effect = self.reducer(&self.state, action)
    self.isSending = false

    var didComplete = false
    let uuid = UUID()

    var isProcessingEffects = true
    let effectCancellable = effect.start { [weak self] event in
      switch event {
      // WARNING: check if handling `.interrupted` like this is valid
      case .completed, .interrupted:
        didComplete = true
        self?.effectCancellables[uuid] = nil
        
      case let .value(action):
        if isProcessingEffects {
          self?.synchronousActionsToSend.append(action)
        } else {
          self?.send(action)
        }
      }            
    }
    isProcessingEffects = false
    
    if !didComplete {
      self.effectCancellables[uuid] = effectCancellable
    }

    while !self.synchronousActionsToSend.isEmpty {
      let action = self.synchronousActionsToSend.removeFirst()
      self.send(action)
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

// A publisher of store state.
@dynamicMemberLookup
public struct StorePublisher<State>: SignalProducerConvertible {
  public let producer: SignalProducer<State, Never>

  init(_ upstream: SignalProducer<State, Never>) {
    self.producer = upstream
  } 
  
  /// Returns the resulting publisher of a given key path.
  public subscript<LocalState>(
    dynamicMember keyPath: KeyPath<State, LocalState>
  ) -> SignalProducer<LocalState, Never>
  where LocalState: Equatable {
    self.producer.map(keyPath).skipRepeats()
  }  
}
