#if canImport(SwiftUI)

  import SwiftUI

  // NB: Deprecated after 0.10.0:

  @available(iOS 13, macOS 10.15, macCatalyst 13, tvOS 13, watchOS 6, *)
  extension ActionSheetState {
    @available(*, deprecated, message: "'title' and 'message' should be 'TextState'")
    @_disfavoredOverload
    public init(
      title: LocalizedStringKey,
      message: LocalizedStringKey? = nil,
      buttons: [Button]
    ) {
      self.init(
        title: .init(title),
        message: message.map { .init($0) },
        buttons: buttons
      )
    }
  }

  @available(iOS 13, macOS 10.15, macCatalyst 13, tvOS 13, watchOS 6, *)
  extension AlertState {
    @available(*, deprecated, message: "'title' and 'message' should be 'TextState'")
    @_disfavoredOverload
    public init(
      title: LocalizedStringKey,
      message: LocalizedStringKey? = nil,
      dismissButton: Button? = nil
    ) {
      self.init(
        title: .init(title),
        message: message.map { .init($0) },
        dismissButton: dismissButton
      )
    }

    @available(*, deprecated, message: "'title' and 'message' should be 'TextState'")
    @_disfavoredOverload
    public init(
      title: LocalizedStringKey,
      message: LocalizedStringKey? = nil,
      primaryButton: Button,
      secondaryButton: Button
    ) {
      self.init(
        title: .init(title),
        message: message.map { .init($0) },
        primaryButton: primaryButton,
        secondaryButton: secondaryButton
      )
    }
  }

  @available(iOS 13, macOS 10.15, macCatalyst 13, tvOS 13, watchOS 6, *)
  extension AlertState.Button {
    @available(*, deprecated, message: "'label' should be 'TextState'")
    @_disfavoredOverload
    public static func cancel(
      _ label: LocalizedStringKey,
      send action: Action? = nil
    ) -> Self {
      Self(action: action, type: .cancel(label: .init(label)))
    }

    @available(*, deprecated, message: "'label' should be 'TextState'")
    @_disfavoredOverload
    public static func `default`(
      _ label: LocalizedStringKey,
      send action: Action? = nil
    ) -> Self {
      Self(action: action, type: .default(label: .init(label)))
    }

    @available(*, deprecated, message: "'label' should be 'TextState'")
    @_disfavoredOverload
    public static func destructive(
      _ label: LocalizedStringKey,
      send action: Action? = nil
    ) -> Self {
      Self(action: action, type: .destructive(label: .init(label)))
    }
  }
#endif

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
