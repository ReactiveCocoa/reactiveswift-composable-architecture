import Combine
import ComposableArchitecture
import Foundation
import ReactiveSwift

struct DownloadClient {
  var download: (URL) -> Effect<Action, Error>

  struct Error: Swift.Error, Equatable {}

  enum Action: Equatable {
    case response(Data)
    case updateProgress(Double)
  }
}

extension DownloadClient {
  static let live = DownloadClient(
    download: { url in
      .init { subscriber, lifetime in
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
          switch (data, error) {
          case let (.some(data), _):
            subscriber.send(value: .response(data))
            subscriber.sendCompleted()
          case let (_, .some(error)):
            subscriber.send(error: Error())
          case (.none, .none):
            fatalError("Data and Error should not both be nil")
          }
        }

        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
          subscriber.send(value: .updateProgress(progress.fractionCompleted))
        }

        lifetime += AnyDisposable {
          observation.invalidate()
          task.cancel()
        }
        task.resume()
      }
    }
  )
}
