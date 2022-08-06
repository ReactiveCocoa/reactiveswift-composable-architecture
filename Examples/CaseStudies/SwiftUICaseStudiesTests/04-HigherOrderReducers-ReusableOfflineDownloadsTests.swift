import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SwiftUICaseStudies

class ReusableComponentsDownloadComponentTests: XCTestCase {
  let downloadSubject = Signal<DownloadClient.Action, DownloadClient.Error>.pipe()
  let reducer = Reducer<
    DownloadComponentState<Int>, DownloadComponentAction, DownloadComponentEnvironment
  >
  .empty
  .downloadable(
    state: \.self,
    action: .self,
    environment: { $0 }
  )
  let mainQueue = TestScheduler()

  func testDownloadFlow() {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.mainQueue
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    self.downloadSubject.input.send(value: .updateProgress(0.2))
    self.mainQueue.advance()
    store.receive(.downloadClient(.success(.updateProgress(0.2)))) {
      $0.mode = .downloading(progress: 0.2)
    }

    self.downloadSubject.input.send(value: .response(Data()))
    self.mainQueue.advance(by: 1)
    store.receive(.downloadClient(.success(.response(Data())))) {
      $0.mode = .downloaded
    }
    self.downloadSubject.input.sendCompleted()
    self.mainQueue.advance()
  }

  func testDownloadThrottling() {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.mainQueue
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    self.downloadSubject.input.send(value: .updateProgress(0.5))
    self.mainQueue.advance()
    store.receive(.downloadClient(.success(.updateProgress(0.5)))) {
      $0.mode = .downloading(progress: 0.5)
    }

    self.downloadSubject.input.send(value: .updateProgress(0.6))
    self.mainQueue.advance(by: 0.5)

    self.downloadSubject.input.send(value: .updateProgress(0.7))
    self.mainQueue.advance(by: 0.5)
    store.receive(.downloadClient(.success(.updateProgress(0.7)))) {
      $0.mode = .downloading(progress: 0.7)
    }

    self.downloadSubject.input.sendCompleted()
    self.mainQueue.run()
  }

  func testCancelDownloadFlow() {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.mainQueue
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to stop downloading this map?"),
        primaryButton: .destructive(TextState("Stop"), action: .send(.stopButtonTapped)),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    store.send(.alert(.stopButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }

    self.mainQueue.run()
  }

  func testDownloadFinishesWhileTryingToCancel() {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.mainQueue
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to stop downloading this map?"),
        primaryButton: .destructive(TextState("Stop"), action: .send(.stopButtonTapped)),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    self.downloadSubject.input.send(value: .response(Data()))
    self.mainQueue.advance(by: 1)
    store.receive(.downloadClient(.success(.response(Data())))) {
      $0.alert = nil
      $0.mode = .downloaded
    }
    self.downloadSubject.input.sendCompleted()
    self.mainQueue.advance()
  }

  func testDeleteDownloadFlow() {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .downloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.mainQueue
      )
    )

    store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to delete this map from your offline storage?"),
        primaryButton: .destructive(TextState("Delete"), action: .send(.deleteButtonTapped)),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    store.send(.alert(.deleteButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }
  }
}

extension DownloadClient {
  static let unimplemented = Self(
    download: { _ in .unimplemented("\(Self.self).download") }
  )
}
