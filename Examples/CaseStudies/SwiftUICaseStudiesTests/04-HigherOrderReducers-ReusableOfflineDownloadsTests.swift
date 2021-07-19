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
  let scheduler = TestScheduler()

  func testDownloadFlow() {
    var downloadClient = DownloadClient.failing
    downloadClient.download = { _, _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    self.downloadSubject.input.send(value: .updateProgress(0.2))
    self.scheduler.advance()
    store.receive(.downloadClient(.success(.updateProgress(0.2)))) {
      $0.mode = .downloading(progress: 0.2)
    }

    self.downloadSubject.input.send(value: .response(Data()))
    self.scheduler.advance(by: .seconds(1))
    store.receive(.downloadClient(.success(.response(Data())))) {
      $0.mode = .downloaded
    }
    self.downloadSubject.input.sendCompleted()
    self.scheduler.advance()
  }

  func testDownloadThrottling() {
    var downloadClient = DownloadClient.failing
    downloadClient.download = { _, _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    self.downloadSubject.input.send(value: .updateProgress(0.5))
    self.scheduler.advance()
    store.receive(.downloadClient(.success(.updateProgress(0.5)))) {
      $0.mode = .downloading(progress: 0.5)
    }

    self.downloadSubject.input.send(value: .updateProgress(0.6))
    self.scheduler.advance(by: .milliseconds(500))

    self.downloadSubject.input.send(value: .updateProgress(0.7))
    self.scheduler.advance(by: .milliseconds(500))
    store.receive(.downloadClient(.success(.updateProgress(0.7)))) {
      $0.mode = .downloading(progress: 0.7)
    }

    self.downloadSubject.input.sendCompleted()
    self.scheduler.run()
  }

  func testCancelDownloadFlow() {
    var downloadClient = DownloadClient.failing
    downloadClient.cancel = { _ in
      .fireAndForget { self.downloadSubject.input.sendCompleted() }
    }
    downloadClient.download = { _, _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    store.send(.buttonTapped) {
      $0.alert = .init(
        title: .init("Do you want to cancel downloading this map?"),
        primaryButton: .destructive(.init("Cancel"), send: .cancelButtonTapped),
        secondaryButton: .default(.init("Nevermind"), send: .nevermindButtonTapped)
      )
    }

    store.send(.alert(.cancelButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }

    self.scheduler.run()
  }

  func testDownloadFinishesWhileTryingToCancel() {
    var downloadClient = DownloadClient.failing
    downloadClient.cancel = { _ in
      .fireAndForget { self.downloadSubject.input.sendCompleted() }
    }
    downloadClient.download = { _, _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    store.send(.buttonTapped) {
      $0.alert = .init(
        title: .init("Do you want to cancel downloading this map?"),
        primaryButton: .destructive(.init("Cancel"), send: .cancelButtonTapped),
        secondaryButton: .default(.init("Nevermind"), send: .nevermindButtonTapped)
      )
    }

    self.downloadSubject.input.send(value: .response(Data()))
    self.scheduler.advance(by: .seconds(1))
    store.receive(.downloadClient(.success(.response(Data())))) {
      $0.alert = nil
      $0.mode = .downloaded
    }
    self.downloadSubject.input.sendCompleted()
    self.scheduler.advance()
  }

  func testDeleteDownloadFlow() {
    var downloadClient = DownloadClient.failing
    downloadClient.cancel = { _ in
      .fireAndForget { self.downloadSubject.input.sendCompleted() }
    }
    downloadClient.download = { _, _ in self.downloadSubject.output.producer }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .downloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler
      )
    )

    store.send(.buttonTapped) {
      $0.alert = .init(
        title: .init("Do you want to delete this map from your offline storage?"),
        primaryButton: .destructive(.init("Delete"), send: .deleteButtonTapped),
        secondaryButton: .default(.init("Nevermind"), send: .nevermindButtonTapped)
      )
    }

    store.send(.alert(.deleteButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }
  }
}

extension DownloadClient {
  static let failing = Self(
    cancel: { _ in .failing("DownloadClient.cancel") },
    download: { _, _ in .failing("DownloadClient.download") }
  )
}
