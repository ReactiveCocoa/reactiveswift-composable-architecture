import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SpeechRecognition

class SpeechRecognitionTests: XCTestCase {
  let recognitionTaskSubject = Signal<SpeechRecognitionResult, SpeechClient.Error>.pipe()

  func testDenyAuthorization() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = ImmediateScheduler()
    store.environment.speechClient.requestAuthorization = { Effect(value: .denied) }

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    store.receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
      $0.alert = AlertState(
        title: TextState(
          """
          You denied access to speech recognition. This app needs access to transcribe your speech.
          """
        )
      )
      $0.isRecording = false
    }
  }

  func testRestrictedAuthorization() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = ImmediateScheduler()
    store.environment.speechClient.requestAuthorization = { Effect(value: .restricted) }

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    store.receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
      $0.alert = AlertState(title: TextState("Your device does not allow speech recognition."))
      $0.isRecording = false
    }
  }

  func testAllowAndRecord() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = ImmediateScheduler()
    store.environment.speechClient.finishTask = {
      .fireAndForget { self.recognitionTaskSubject.input.sendCompleted() }
    }
    store.environment.speechClient.requestAuthorization = { Effect(value: .authorized) }
    store.environment.speechClient.startTask = { _ in self.recognitionTaskSubject.output.producer }

    let firstResult = SpeechRecognitionResult(
      bestTranscription: Transcription(
        formattedString: "Hello",
        segments: []
      ),
      isFinal: false,
      transcriptions: []
    )
    var secondResult = firstResult
    secondResult.bestTranscription.formattedString = "Hello world"

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

    self.recognitionTaskSubject.input.send(value: firstResult)
    store.receive(.speech(.success("Hello"))) {
      $0.transcribedText = "Hello"
    }

    self.recognitionTaskSubject.input.send(value: secondResult)
    store.receive(.speech(.success("Hello world"))) {
      $0.transcribedText = "Hello world"
    }

    store.send(.recordButtonTapped) {
      $0.isRecording = false
    }
  }

  func testAudioSessionFailure() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = ImmediateScheduler()
    store.environment.speechClient.startTask = { _ in self.recognitionTaskSubject.output.producer }
    store.environment.speechClient.requestAuthorization = { Effect(value: .authorized) }

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

    self.recognitionTaskSubject.input.send(error: .couldntConfigureAudioSession)
    store.receive(.speech(.failure(.couldntConfigureAudioSession))) {
      $0.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.input.sendCompleted()
  }

  func testAudioEngineFailure() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = ImmediateScheduler()
    store.environment.speechClient.startTask = { _ in self.recognitionTaskSubject.output.producer }
    store.environment.speechClient.requestAuthorization = { Effect(value: .authorized) }

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

    self.recognitionTaskSubject.input.send(error: .couldntStartAudioEngine)
    store.receive(.speech(.failure(.couldntStartAudioEngine))) {
      $0.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.input.sendCompleted()
  }
}

extension AppEnvironment {
  static let unimplemented = Self(
    mainQueue: UnimplementedScheduler(),
    speechClient: .unimplemented
  )
}
