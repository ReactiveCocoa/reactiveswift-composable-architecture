// NB: Deprecated after 0.9.0:

extension Store {
  @available(*, deprecated, renamed: "producerScope(state:)")
  public func scope<LocalState>(
    state toLocalState: @escaping (Effect<State, Never>) -> Effect<LocalState, Never>
  ) -> Effect<Store<LocalState, Action>, Never> {
    self.producerScope(state: toLocalState)
  }

  @available(*, deprecated, renamed: "producerScope(state:action:)")
  public func scope<LocalState, LocalAction>(
    state toLocalState: @escaping (Effect<State, Never>) -> Effect<LocalState, Never>,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> Effect<Store<LocalState, LocalAction>, Never> {
    self.producerScope(state: toLocalState, action: fromLocalAction)
  }
}

// NB: Deprecated after 0.6.0:

extension Reducer {
  @available(*, deprecated, renamed: "optional()")
  public var optional: Reducer<State?, Action, Environment> {
    self.optional()
  }
}
