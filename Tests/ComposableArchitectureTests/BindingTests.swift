#if compiler(>=5.4) && canImport(SwiftUI)
  import ComposableArchitecture
  import XCTest

  final class BindingTests: XCTestCase {
    @available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
    func testNestedBindableState() {
      struct State: Equatable {
        @BindableState var nested = Nested()

        struct Nested: Equatable {
          var field = ""
        }
      }

      enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
      }

      let reducer = Reducer<State, Action, ()> { state, action, _ in
        switch action {
        case .binding(\.$nested.field):
          state.nested.field += "!"
          return .none
        default:
          return .none
        }
      }
      .binding()

      let store = Store(initialState: .init(), reducer: reducer, environment: ())

      let viewStore = ViewStore(store)

      viewStore.binding(\.$nested.field).wrappedValue = "Hello"

      XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
    }
  }
#endif
