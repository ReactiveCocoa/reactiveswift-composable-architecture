import ComposableArchitecture
import ReactiveSwift
import UIKit

final class CounterCollectionViewCell: UICollectionViewListCell {

  static var identifier: String { "\(type(of: self))" }

  let countLabel = UILabel()

  var viewStore: ViewStore<CounterState, CounterAction>? {
    didSet { setUpBindings() }
  }

  private var disposable: Disposable?

  override init(frame: CGRect) {
    super.init(frame: frame)

    setUpSubviews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setUpSubviews() {

    self.contentView.backgroundColor = .systemBackground

    let decrementButton = UIButton(type: .system)
    decrementButton.addTarget(self, action: #selector(decrementButtonTapped), for: .touchUpInside)
    decrementButton.setTitle("−", for: .normal)

    countLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)

    let incrementButton = UIButton(type: .system)
    incrementButton.addTarget(self, action: #selector(incrementButtonTapped), for: .touchUpInside)
    incrementButton.setTitle("+", for: .normal)

    let rootStackView = UIStackView(arrangedSubviews: [
      decrementButton,
      countLabel,
      incrementButton,
    ])
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    self.contentView.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
    ])
  }

  private func setUpBindings() {

    guard let viewStore = self.viewStore else { return }

    self.disposable = viewStore.produced.count
      .map(String.init)
      .assign(to: \.text, on: countLabel)
  }

  override func prepareForReuse() {

    super.prepareForReuse()

    self.disposable?.dispose()
    self.viewStore = nil
  }


  @objc func decrementButtonTapped() {
    self.viewStore?.send(.decrementButtonTapped)
  }

  @objc func incrementButtonTapped() {
    self.viewStore?.send(.incrementButtonTapped)
  }
}
