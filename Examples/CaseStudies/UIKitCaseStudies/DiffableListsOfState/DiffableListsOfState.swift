import ComposableArchitecture
import SwiftUI
import UIKit

struct DiffableCounterState: Hashable, Identifiable {
  var id: UUID = .init()
  var counter: CounterState = .init()

  // custom Equatable/Hashable conformances to only look at the ID for diffing
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

let diffableCounterReducer = Reducer<DiffableCounterState, CounterAction, Void> { state, action, _ in
  switch action {
  case .decrementButtonTapped:
    state.counter.count -= 1
    return .none
  case .incrementButtonTapped:
    state.counter.count += 1
    return .none
  }
}

struct DiffableCounterListState: Equatable {
  var counters: IdentifiedStateContainer<UUID, DiffableCounterState>
}

enum DiffableCounterListAction: Equatable {
  case counter(id: UUID, action: CounterAction)
  case shuffle
  case insert
  case remove(id: UUID)
}

let diffableCounterListReducer: Reducer<DiffableCounterListState, DiffableCounterListAction, Void> = diffableCounterReducer
  .forEach(
    state: \DiffableCounterListState.counters,
    action: /DiffableCounterListAction.counter(id:action:),
    environment: { _ in () }
  )
  .combined(
    with: Reducer { state, action, _ in

      switch action {
      case .shuffle:
        state.counters.shuffle()
        return .none
      case .insert:
        state.counters.append(.init())
        return .none
      case .remove(let id):
        state.counters.remove(id: id)
        return .none
      case .counter:
        return .none
      }

    }
  )

final class DiffableCountersTableViewController: UIViewController, UICollectionViewDelegate {

  struct DummySection: Hashable {}

  let store: Store<DiffableCounterListState, DiffableCounterListAction>
  let viewStore: ViewStore<DiffableCounterListState, DiffableCounterListAction>

  var collectionView: UICollectionView!
  var dataSource: UICollectionViewDiffableDataSource<DummySection, DiffableCounterState>!

  init(store: Store<DiffableCounterListState, DiffableCounterListAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "Diffable Lists"

    setUpCollectionView()
    setUpSubviews()

    collectionView.delegate = self
  }

  private func setUpSubviews() {

    let shuffle = UIButton(type: .roundedRect)
    shuffle.backgroundColor = .lightGray
    shuffle.setTitle("Shuffle", for: .normal)
    shuffle.addTarget(self, action: #selector(shuffleTapped), for: .touchUpInside)

    let insert = UIButton(type: .roundedRect)
    insert.backgroundColor = .lightGray
    insert.setTitle("Insert", for: .normal)
    insert.addTarget(self, action: #selector(insertTapped), for: .touchUpInside)

    let stackView = UIStackView(arrangedSubviews: [shuffle, insert])
    stackView.distribution = .fillEqually

    view.addSubview(collectionView)
    view.addSubview(stackView)

    collectionView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: stackView.topAnchor),
      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    ])
  }

  private func setUpCollectionView() {

    var listConfiguration = UICollectionLayoutListConfiguration(appearance: .sidebarPlain)
    listConfiguration.trailingSwipeActionsConfigurationProvider = { indexPath in
      UISwipeActionsConfiguration(
        actions: [
          .init(
            style: .destructive,
            title: "Delete",
            handler: { [weak self] _, _, completion in
              guard let id = self?.dataSource.itemIdentifier(for: indexPath)?.id else { return }
              self?.viewStore.send(.remove(id: id))
              completion(true)
            }
          )
        ]
      )
    }

    self.collectionView = UICollectionView(
      frame: view.frame,
      collectionViewLayout: UICollectionViewCompositionalLayout.list(using: listConfiguration)
    )

    self.collectionView.register(
      CounterCollectionViewCell.self,
      forCellWithReuseIdentifier: CounterCollectionViewCell.identifier
    )

    self.dataSource = .init(collectionView: collectionView, cellProvider: { [store] collectionView, indexPath, state in
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: CounterCollectionViewCell.identifier,
        for: indexPath
      ) as! CounterCollectionViewCell

      let childStore = store.childStore(
        for: state.id,
        state: \.counters,
        action: DiffableCounterListAction.counter(id:action:)
      )

      // this extra `scope` could be avoided if we didn't reuse `CounterState` in `DiffableCounterState`
      cell.viewStore = ViewStore(childStore.scope(state: \.counter))

      return cell
    })

    self.viewStore.produced.counters
      .startWithValues { [weak self] in

        var snapshot = NSDiffableDataSourceSnapshot<DummySection, DiffableCounterState>()
        snapshot.appendSections([.init()])
        snapshot.appendItems($0.elements)

        // check the window to prevent `UITableViewAlertForLayoutOutsideViewHierarchy` from firing when not visible
        self?.dataSource.apply(snapshot, animatingDifferences: self?.view.window != nil ? true : false)
      }
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

    guard let id = self.dataSource.itemIdentifier(for: indexPath)?.id else { return }

    self.navigationController?.pushViewController(
      CounterViewController(
        store: self.store.childStore(
          for: id,
          state: \.counters,
          action: DiffableCounterListAction.counter(id:action:)
        )
        // this extra `scope` could be avoided if we didn't reuse `CounterState` in `DiffableCounterState`
        .scope(state: \.counter)
      ),
      animated: true
    )
  }

  @objc func shuffleTapped() {
    viewStore.send(.shuffle)
  }

  @objc func insertTapped() {
    viewStore.send(.insert)
  }
}

struct DiffableCountersTableViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = UINavigationController(
      rootViewController: DiffableCountersTableViewController(
        store: Store(
          initialState: DiffableCounterListState(
            counters: [
              DiffableCounterState(),
              DiffableCounterState(),
              DiffableCounterState(),
            ]
          ),
          reducer: diffableCounterListReducer,
          environment: ()
        )
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
