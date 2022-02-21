import ReactiveSwift

#if canImport(Combine)
  import Combine
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

/// A ``ViewStore`` is an object that can observe state changes and send actions. They are most
/// commonly used in views, such as SwiftUI views, UIView or UIViewController, but they can be
/// used anywhere it makes sense to observe state and send actions.
///
/// In SwiftUI applications, a ``ViewStore`` is accessed most commonly using the ``WithViewStore``
/// view. It can be initialized with a store and a closure that is handed a view store and must
/// return a view to be rendered:
///
/// ```swift
/// var body: some View {
///   WithViewStore(self.store) { viewStore in
///     VStack {
///       Text("Current count: \(viewStore.count)")
///       Button("Increment") { viewStore.send(.incrementButtonTapped) }
///     }
///   }
/// }
/// ```
///
/// In UIKit applications a ``ViewStore`` can be created from a ``Store`` and then subscribed to for
/// state updates:
///
/// ```swift
/// let store: Store<State, Action>
/// let viewStore: ViewStore<State, Action>
///
/// init(store: Store<State, Action>) {
///   self.store = store
///   self.viewStore = ViewStore(store)
/// }
///
/// func viewDidLoad() {
///   super.viewDidLoad()
///
///       self.viewStore.produced.count
///         .startWithValues { [weak self] in self?.countLabel.text = $0 }
/// }
///
/// @objc func incrementButtonTapped() {
///   self.viewStore.send(.incrementButtonTapped)
/// }
/// ```
///
/// ### Thread safety
///
/// The ``ViewStore`` class is not thread-safe, and all interactions with it (and the store it was
/// derived from) must happen on the same thread. Further, for SwiftUI applications, all
/// interactions must happen on the _main_ thread. See the documentation of the ``Store`` class for
/// more information as to why this decision was made.
///
/// ### ViewStore object lifetime
///
/// You must always keep a strong reference to any ``ViewStore`` that you create to prevent it from
/// being immediately deallocated, and thereby preventing its ``produced`` ``StoreProducer`` from
/// emiting any more state updates. This is primarly an issue when using UIKit, as the SwiftUI
/// ``WithViewStore`` helper ensures that the ``ViewStore`` is retained.
@dynamicMemberLookup
public final class ViewStore<State, Action> {
  #if canImport(Combine)
    public private(set) lazy var objectWillChange = ObservableObjectPublisher()
  #endif

  private let _send: (Action) -> Void
  private var _state: State
  fileprivate let statePipe = Signal<State, Never>.pipe()
  private var viewDisposable: Disposable?

  /// Initializes a view store from a store.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed.
  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) {
    self._send = { store.send($0) }
    self._state = store.state

    self.viewDisposable = store.producer
      .skipRepeats(isDuplicate)
      .startWithValues { [weak self] in
        guard let self = self else { return }
        #if canImport(Combine)
          self.objectWillChange.send()
          self._state = $0
        #endif
        self._state = $0
        self.statePipe.input.send(value: $0)
      }
  }

  /// A `SignalProducerConvertible` that emits when state changes.
  ///
  /// This producer supports dynamic member lookup so that you can pluck out a specific field in
  /// the state:
  ///
  /// ```swift
  /// viewStore.produced.alert
  ///   .startWithValues { ... }
  /// ```
  ///
  /// When the emission happens the ``ViewStore``'s state has been updated, and so the following
  /// precondition will pass:
  ///
  /// ```swift
  /// viewStore.produced.producer
  ///   .startWithValues { precondition($0 == viewStore.state) }
  /// ```
  ///
  /// This means you can either use the value passed to the closure or you can reach into
  /// `viewStore.state` directly.
  ///
  public var produced: StoreProducer<State> {
    StoreProducer(viewStore: self)
  }

  /// The current state.
  public var state: State {
    self._state
  }

  /// Returns the resulting value of a given key path.
  public subscript<LocalState>(dynamicMember keyPath: KeyPath<State, LocalState>) -> LocalState {
    self._state[keyPath: keyPath]
  }

  /// Sends an action to the store.
  ///
  /// ``ViewStore`` is not thread safe and you should only send actions to it from the main thread.
  /// If you are wanting to send actions on background threads due to the fact that the reducer
  /// is performing computationally expensive work, then a better way to handle this is to wrap
  /// that work in an ``Effect`` that is performed on a background thread so that the result can
  /// be fed back into the store.
  ///
  /// - Parameter action: An action.
  public func send(_ action: Action) {
    self._send(action)
  }

  #if canImport(SwiftUI)
    /// Derives a binding from the store that prevents direct writes to state and instead sends
    /// actions to the store.
    ///
    /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
    /// since the ``Store`` does not allow directly writing its state; it only allows reading state
    /// and sending actions.
    ///
    /// For example, a text field binding can be created like this:
    ///
    /// ```swift
    /// struct State { var name = "" }
    /// enum Action { case nameChanged(String) }
    ///
    /// TextField(
    ///   "Enter name",
    ///   text: viewStore.binding(
    ///     get: { $0.name },
    ///     send: { Action.nameChanged($0) }
    ///   )
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - get: A function to get the state for the binding from the view
    ///     store's full state.
    ///   - localStateToViewAction: A function that transforms the binding's value
    ///     into an action that can be sent to the store.
    /// - Returns: A binding.
    public func binding<LocalState>(
      get: @escaping (State) -> LocalState,
      send localStateToViewAction: @escaping (LocalState) -> Action
    ) -> Binding<LocalState> {
      ObservedObject(wrappedValue: self)
        .projectedValue[get: .init(rawValue: get), send: .init(rawValue: localStateToViewAction)]
    }
    /// Derives a binding from the store that prevents direct writes to state and instead sends
    /// actions to the store.
    ///
    /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
    /// since the ``Store`` does not allow directly writing its state; it only allows reading state
    /// and sending actions.
    ///
    /// For example, an alert binding can be dealt with like this:
    ///
    /// ```swift
    /// struct State { var alert: String? }
    /// enum Action { case alertDismissed }
    ///
    /// .alert(
    ///   item: self.store.binding(
    ///     get: { $0.alert },
    ///     send: .alertDismissed
    ///   )
    /// ) { alert in Alert(title: Text(alert.message)) }
    /// ```
    ///
    /// - Parameters:
    ///   - get: A function to get the state for the binding from the view store's full state.
    ///   - action: The action to send when the binding is written to.
    /// - Returns: A binding.
    public func binding<LocalState>(
      get: @escaping (State) -> LocalState,
      send action: Action
    ) -> Binding<LocalState> {
      self.binding(get: get, send: { _ in action })
    }

    /// Derives a binding from the store that prevents direct writes to state and instead sends
    /// actions to the store.
    ///
    /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
    /// since the ``Store`` does not allow directly writing its state; it only allows reading state
    /// and sending actions.
    ///
    /// For example, a text field binding can be created like this:
    ///
    /// ```swift
    /// typealias State = String
    /// enum Action { case nameChanged(String) }
    ///
    /// TextField(
    ///   "Enter name",
    ///   text: viewStore.binding(
    ///     send: { Action.nameChanged($0) }
    ///   )
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - localStateToViewAction: A function that transforms the binding's value
    ///     into an action that can be sent to the store.
    /// - Returns: A binding.
    public func binding(
      send localStateToViewAction: @escaping (State) -> Action
    ) -> Binding<State> {
      self.binding(get: { $0 }, send: localStateToViewAction)
    }

    /// Derives a binding from the store that prevents direct writes to state and instead sends
    /// actions to the store.
    ///
    /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
    /// since the ``Store`` does not allow directly writing its state; it only allows reading state
    /// and sending actions.
    ///
    /// For example, an alert binding can be dealt with like this:
    ///
    /// ```swift
    /// typealias State = String
    /// enum Action { case alertDismissed }
    ///
    /// .alert(
    ///       item: self.store.binding(
    ///     send: .alertDismissed
    ///   )
    /// ) { title in Alert(title: Text(title)) }
    /// ```
    ///
    /// - Parameters:
    ///   - action: The action to send when the binding is written to.
    /// - Returns: A binding.
    public func binding(send action: Action) -> Binding<State> {
      self.binding(send: { _ in action })
    }
  #endif

  deinit {
    viewDisposable?.dispose()
  }

  private subscript<LocalState>(
    get state: HashableWrapper<(State) -> LocalState>,
    send action: HashableWrapper<(LocalState) -> Action>
  ) -> LocalState {
    get { state.rawValue(self.state) }
    set { self.send(action.rawValue(newValue)) }
  }
}

extension ViewStore where State: Equatable {
  public convenience init(_ store: Store<State, Action>) {
    self.init(store, removeDuplicates: ==)
  }
}

extension ViewStore where State == Void {
  public convenience init(_ store: Store<Void, Action>) {
    self.init(store, removeDuplicates: ==)
  }
}

#if canImport(Combine)
  extension ViewStore: ObservableObject {
  }
#endif

@dynamicMemberLookup
public struct StoreProducer<State>: SignalProducerConvertible {
  public let upstream: Effect<State, Never>
  public let viewStore: Any

  public var producer: Effect<State, Never> {
    upstream
  }

  fileprivate init<Action>(viewStore: ViewStore<State, Action>) {
    self.viewStore = viewStore
    self.upstream =
      Property<State>(initial: viewStore.state, then: viewStore.statePipe.output).producer
  }

  private init(
    upstream: Effect<State, Never>,
    viewStore: Any
  ) {
    self.upstream = upstream
    self.viewStore = viewStore
  }

  /// Returns the resulting `StoreProducer` of a given key path.
  public subscript<LocalState>(
    dynamicMember keyPath: KeyPath<State, LocalState>
  ) -> StoreProducer<LocalState>
  where LocalState: Equatable {
    .init(upstream: self.upstream.map(keyPath).skipRepeats(), viewStore: self.viewStore)
  }

  /// Returns the resulting `SignalProducer` of a given key path.
  public subscript<LocalValue>(
    dynamicMember keyPath: KeyPath<Value, LocalValue>
  ) -> Effect<LocalValue, Never> where LocalValue: Equatable {
    self.upstream.map(keyPath).skipRepeats()
  }
}

private struct HashableWrapper<Value>: Hashable {
  let rawValue: Value
  static func == (lhs: Self, rhs: Self) -> Bool { false }
  func hash(into hasher: inout Hasher) {}
}

#if canImport(_Concurrency) && compiler(>=5.5.2)
  extension ViewStore {
    /// Sends an action into the store and then suspends while a piece of state is `true`.
    ///
    /// This method can be used to interact with async/await code, allowing you to suspend while
    /// work is being performed in an effect. One common example of this is using SwiftUI's
    /// `.refreshable` method, which shows a loading indicator on the screen while work is being
    /// performed.
    ///
    /// For example, suppose we wanted to load some data from the network when a pull-to-refresh
    /// gesture is performed on a list. The domain and logic for this feature can be modeled like
    /// so:
    ///
    /// ```swift
    /// struct State: Equatable {
    ///   var isLoading = false
    ///   var response: String?
    /// }
    ///
    /// enum Action {
    ///   case pulledToRefresh
    ///   case receivedResponse(String?)
    /// }
    ///
    /// struct Environment {
    ///   var fetch: () -> Effect<String?, Never>
    /// }
    ///
    /// let reducer = Reducer<State, Action, Environment> { state, action, environment in
    ///   switch action {
    ///   case .pulledToRefresh:
    ///     state.isLoading = true
    ///     return environment.fetch()
    ///       .map(Action.receivedResponse)
    ///
    ///   case let .receivedResponse(response):
    ///     state.isLoading = false
    ///     state.response = response
    ///     return .none
    ///   }
    /// }
    /// ```
    ///
    /// Note that we keep track of an `isLoading` boolean in our state so that we know exactly
    /// when the network response is being performed.
    ///
    /// The view can show the fact in a `List`, if it's present, and we can use the `.refreshable`
    /// view modifier to enhance the list with pull-to-refresh capabilities:
    ///
    /// ```swift
    /// struct MyView: View {
    ///   let store: Store<State, Action>
    ///
    ///   var body: some View {
    ///     WithViewStore(self.store) { viewStore in
    ///       List {
    ///         if let response = viewStore.response {
    ///           Text(response)
    ///         }
    ///       }
    ///       .refreshable {
    ///         await viewStore.send(.pulledToRefresh, while: \.isLoading)
    ///       }
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// Here we've used the ``send(_:while:)`` method to suspend while the `isLoading` state is
    /// `true`. Once that piece of state flips back to `false` the method will resume, signaling
    /// to `.refreshable` that the work has finished which will cause the loading indicator to
    /// disappear.
    ///
    /// **Note:** ``ViewStore`` is not thread safe and you should only send actions to it from the
    /// main thread. If you are wanting to send actions on background threads due to the fact that
    /// the reducer is performing computationally expensive work, then a better way to handle this
    /// is to wrap that work in an ``Effect`` that is performed on a background thread so that the
    /// result can be fed back into the store.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - predicate: A predicate on `State` that determines for how long this method should
    ///     suspend.
    public func send(
      _ action: Action,
      while predicate: @escaping (State) -> Bool
    ) async {
      self.send(action)
      await self.suspend(while: predicate)
    }

    #if canImport(SwiftUI)
      /// Sends an action into the store and then suspends while a piece of state is `true`.
      ///
      /// See the documentation of ``send(_:while:)`` for more information.
      ///
      /// - Parameters:
      ///   - action: An action.
      ///   - animation: The animation to perform when the action is sent.
      ///   - predicate: A predicate on `State` that determines for how long this method should
      ///     suspend.
      public func send(
        _ action: Action,
        animation: Animation?,
        while predicate: @escaping (State) -> Bool
      ) async {
        withAnimation(animation) { self.send(action) }
        await self.suspend(while: predicate)
      }
    #endif

    /// Suspends while a predicate on state is `true`.
    ///
    /// - Parameter predicate: A predicate on `State` that determines for how long this method
    ///   should suspend.
    public func suspend(while predicate: @escaping (State) -> Bool) async {
      let cancellable = Box<Disposable?>(wrappedValue: nil)
      try? await withTaskCancellationHandler(
        handler: { cancellable.wrappedValue?.dispose() },
        operation: {
          try Task.checkCancellation()
          try await withUnsafeThrowingContinuation {
            (continuation: UnsafeContinuation<Void, Error>) in
            guard !Task.isCancelled else {
              continuation.resume(throwing: CancellationError())
              return
            }
            cancellable.wrappedValue = self.produced.producer
              .filter { !predicate($0) }
              .take(first: 1)
              .startWithValues { _ in
                continuation.resume()
                _ = cancellable
              }
          }
        }
      )

    }
  }

  private class Box<Value> {
    var wrappedValue: Value

    init(wrappedValue: Value) {
      self.wrappedValue = wrappedValue
    }
  }
#endif
