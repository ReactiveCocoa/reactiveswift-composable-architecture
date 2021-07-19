import Foundation
import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import VoiceMemos

class VoiceMemosTests: XCTestCase {
  func testRecordMemoHappyPath() {
    let audioRecorderSubject = Signal<
      AudioRecorderClient.Action, AudioRecorderClient.Failure
    >.pipe()
    let scheduler = TestScheduler()

    var environment = VoiceMemosEnvironment.failing
    environment.audioRecorder.currentTime = { _ in Effect(value: 2.5) }
    environment.audioRecorder.requestRecordPermission = { Effect(value: true) }
    environment.audioRecorder.startRecording = { _, _ in
      audioRecorderSubject.output.producer
    }
    environment.audioRecorder.stopRecording = { _ in
            .fireAndForget {
              audioRecorderSubject.input.send(value: .didFinishRecording(successfully: true))
              audioRecorderSubject.input.sendCompleted()
            }
          }
    environment.date = { Date(timeIntervalSinceReferenceDate: 0) }
    environment.mainQueue = scheduler
    environment.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
    environment.uuid = { UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")! }

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: environment
      )

    store.send(.recordButtonTapped)
    scheduler.advance()
    store.receive(.recordPermissionBlockCalled(true)) {
      $0.audioRecorderPermission = .allowed
      $0.currentRecording = .init(
        date: Date(timeIntervalSinceReferenceDate: 0),
        mode: .recording,
        url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
      )
    }
    scheduler.advance(by: .seconds(1))
    store.receive(.currentRecordingTimerUpdated) {
      $0.currentRecording!.duration = 1
    }
    scheduler.advance(by: .seconds(1))
    store.receive(.currentRecordingTimerUpdated) {
      $0.currentRecording!.duration = 2
    }
    scheduler.advance(by: .milliseconds(500))
    store.send(.recordButtonTapped) {
      $0.currentRecording!.mode = .encoding
    }
    store.receive(.finalRecordingTime(2.5)) {
      $0.currentRecording!.duration = 2.5
    }
    store.receive(.audioRecorder(.success(.didFinishRecording(successfully: true)))) {
      $0.currentRecording = nil
      $0.voiceMemos = [
        VoiceMemo(
          date: Date(timeIntervalSinceReferenceDate: 0),
          duration: 2.5,
          mode: .notPlaying,
          title: "",
          url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
        )
      ]
    }
  }

  func testPermissionDenied() {
    var didOpenSettings = false

    var environment = VoiceMemosEnvironment.failing
    environment.audioRecorder.requestRecordPermission = { Effect(value: false) }
    environment.mainQueue = ImmediateScheduler()
    environment.openSettings = .fireAndForget { didOpenSettings = true }

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: environment
    )

    store.send(.recordButtonTapped)
    store.receive(.recordPermissionBlockCalled(false)) {
      $0.alert = .init(title: .init("Permission is required to record voice memos."))
      $0.audioRecorderPermission = .denied
    }
    store.send(.alertDismissed) {
      $0.alert = nil
    }
    store.send(.openSettingsButtonTapped)
    XCTAssert(didOpenSettings)
  }

  func testRecordMemoFailure() {
    let audioRecorderSubject = Signal<
      AudioRecorderClient.Action, AudioRecorderClient.Failure
    >.pipe()

    var environment = VoiceMemosEnvironment.failing
    environment.audioRecorder.currentTime = { _ in Effect(value: 2.5) }
    environment.audioRecorder.requestRecordPermission = { Effect(value: true) }
    environment.audioRecorder.startRecording = { _, _ in
      audioRecorderSubject.output.producer
    }
    environment.date = { Date(timeIntervalSinceReferenceDate: 0) }
    environment.mainQueue = ImmediateScheduler()
    environment.temporaryDirectory = { .init(fileURLWithPath: "/tmp") }
    environment.uuid = { UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")! }

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: environment
    )

    store.send(.recordButtonTapped)
    store.receive(.recordPermissionBlockCalled(true)) {
      $0.audioRecorderPermission = .allowed
      $0.currentRecording = .init(
        date: Date(timeIntervalSinceReferenceDate: 0),
        mode: .recording,
        url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
      )
    }
    audioRecorderSubject.input.send(error: .couldntActivateAudioSession)
    store.receive(.currentRecordingTimerUpdated) {
      $0.currentRecording?.duration = 1.0
    }
    store.receive(.audioRecorder(.failure(.couldntActivateAudioSession))) {
      $0.alert = .init(title: .init("Voice memo recording failed."))
      $0.currentRecording = nil
    }
  }

  func testPlayMemoHappyPath() {
    let scheduler = TestScheduler()
    var environment = VoiceMemosEnvironment.failing
    environment.audioPlayer.play = { _, _ in
      Effect(value: .didFinishPlaying(successfully: true))
        .delay(1, on: scheduler)
    }
    environment.mainQueue = scheduler

    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 1,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: environment
    )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = VoiceMemo.Mode.playing(progress: 0)
    }
    scheduler.advance(by: .milliseconds(500))
    store.receive(VoiceMemosAction.voiceMemo(id: url, action: VoiceMemoAction.timerUpdated(0.5))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.5)
    }
    scheduler.advance(by: .milliseconds(500))
    store.receive(VoiceMemosAction.voiceMemo(id: url, action: VoiceMemoAction.timerUpdated(1))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 1)
    }
    scheduler.advance(by: .milliseconds(100))
    store.receive(
      .voiceMemo(
        id: url,
        action: .audioPlayerClient(.success(.didFinishPlaying(successfully: true)))
      )
    ) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  func testPlayMemoFailure() {
    var environment = VoiceMemosEnvironment.failing
    environment.audioPlayer.play = { _, _ in Effect(error: .decodeErrorDidOccur) }
    environment.mainQueue = ImmediateScheduler()

    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: environment
      )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    store.receive(.voiceMemo(id: url, action: .audioPlayerClient(.failure(.decodeErrorDidOccur))))
    {
      $0.alert = .init(title: .init("Voice memo playback failed."))
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  func testStopMemo() {
    var didStopAudioPlayerClient = false
    var environment = VoiceMemosEnvironment.failing
    environment.audioPlayer.stop = { _ in .fireAndForget { didStopAudioPlayerClient = true } }

    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: environment
    )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
    XCTAssert(didStopAudioPlayerClient)
  }

  func testDeleteMemo() {
    var didStopAudioPlayerClient = false
    var environment = VoiceMemosEnvironment.failing
    environment.audioPlayer.stop = { _ in .fireAndForget { didStopAudioPlayerClient = true } }

    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: environment
      )

    store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
      XCTAssertEqual(didStopAudioPlayerClient, true)
    }
  }

  func testDeleteMemoWhilePlaying() {
    let url = URL(string: "https://www.pointfree.co/functions")!
    var environment = VoiceMemosEnvironment.failing
    environment.audioPlayer.play = { _, _ in .none }
    environment.audioPlayer.stop = { _ in .none }
    environment.mainQueue = ImmediateScheduler()

    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 10,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: environment
      )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
  }
}

extension VoiceMemosEnvironment {
  static let failing = Self(
    audioPlayer: .failing,
    audioRecorder: .failing,
    date: {
      XCTFail("VoiceMemosEnvironment.date is unimplemented")
      return Date()
    },
    mainQueue: FailingScheduler(),
    openSettings: .failing("VoiceMemosEnvironment.openSettings"),
    temporaryDirectory: {
      XCTFail("VoiceMemosEnvironment.temporaryDirectory is unimplemented")
      return URL(fileURLWithPath: NSTemporaryDirectory())
    },
    uuid: {
      XCTFail("VoiceMemosEnvironment.uuid is unimplemented")
      return UUID()
    }
    )
  }
