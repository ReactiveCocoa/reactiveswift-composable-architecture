extension Store where State: Equatable {

  public func forEach<LocalState: Equatable, LocalAction>(
    state: @escaping (State) -> [LocalState],
    action: @escaping (Int, LocalAction) -> Action
  ) -> [Store<LocalState, LocalAction>] {
    let scopedStore = scope(state: state)
    let viewStore = ViewStore(scopedStore)

    return zip(viewStore.indices, viewStore.state).map { index, element in
      scopedStore.scope(
        state: { index < $0.endIndex ? $0[index] : element },
        action: { action(index, $0) }
      )
    }
  }

  public func forEach<LocalState: Equatable, LocalAction>(
    state: @escaping (State) -> [LocalState],
    action: @escaping (LocalAction) -> Action
  ) -> [Store<LocalState, LocalAction>] {
    let scopedStore = scope(state: state)
    let viewStore = ViewStore(scopedStore)

    return zip(viewStore.indices, viewStore.state).map { index, element in
      scopedStore.scope(
        state: { index < $0.endIndex ? $0[index] : element },
        action: { action($0) }
      )
    }
  }
}

extension Store where State: Equatable {

  public func forEach<LocalState: Equatable, LocalAction, ID, LocalStateContainer>(
    state: @escaping (State) -> LocalStateContainer,
    action: @escaping (ID, LocalAction) -> Action
  ) -> [Store<LocalState, LocalAction>]
  where
    LocalStateContainer: IdentifiedContainer & Equatable,
    LocalStateContainer.Element == LocalState,
    LocalStateContainer.ID == ID
  {
    let scopedStore = scope(state: state)
    let viewStore = ViewStore(scopedStore)

    return viewStore.state.map { element in
      scopedStore.scope(
        state: { $0[id: element[keyPath: viewStore.id]] ?? element },
        action: { action(element[keyPath: viewStore.id], $0) }
      )
    }
  }

  public func childStore<LocalState: Equatable, LocalAction, ID, LocalStateContainer>(
    for id: LocalStateContainer.ID,
    state: @escaping (State) -> LocalStateContainer,
    action: @escaping (ID, LocalAction) -> Action
  ) -> Store<LocalState, LocalAction>
  where
    LocalStateContainer: IdentifiedContainer & Equatable,
    LocalStateContainer.Element == LocalState,
    LocalStateContainer.ID == ID
  {
    let scopedStore = scope(state: state)
    let viewStore = ViewStore(scopedStore)

    let originalElement = viewStore.state.first { $0[keyPath: viewStore.id] == id }!

    return scopedStore.scope(
      state: { $0[id: id] ?? originalElement },
      action: { action(id, $0) }
    )
  }
}
