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

    let result = SpeechRecognitionResult(
      bestTranscription: Transcription(
        formattedString: "Hello",
        segments: []
      ),
      isFinal: false,
      transcriptions: []
    )
    var finalResult = result
    finalResult.bestTranscription.formattedString = "Hello world"
    finalResult.isFinal = true

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

    self.recognitionTaskSubject.input.send(value: result)
    store.receive(.speech(.success(result))) {
      $0.transcribedText = "Hello"
    }

    self.recognitionTaskSubject.input.send(value: finalResult)
    store.receive(.speech(.success(finalResult))) {
      $0.transcribedText = "Hello world"
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
