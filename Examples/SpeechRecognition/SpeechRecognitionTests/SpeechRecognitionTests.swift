import ComposableArchitecture
import ReactiveSwift
import XCTest

@testable import SpeechRecognition

class SpeechRecognitionTests: XCTestCase {
  let recognitionTaskSubject = Signal<SpeechClient.Action, SpeechClient.Error>.pipe()

  func testDenyAuthorization() {
    var speechClient = SpeechClient.failing
    speechClient.requestAuthorization = { Effect(value: .denied) }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: ImmediateScheduler(),
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    store.receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
      $0.alert = .init(
        title: .init(
          """
          You denied access to speech recognition. This app needs access to transcribe your speech.
          """
        )
      )
      $0.isRecording = false
      $0.speechRecognizerAuthorizationStatus = .denied
    }
  }

  func testRestrictedAuthorization() {
    var speechClient = SpeechClient.failing
    speechClient.requestAuthorization = { Effect(value: .restricted) }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: ImmediateScheduler(),
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    store.receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
      $0.alert = .init(title: .init("Your device does not allow speech recognition."))
      $0.isRecording = false
      $0.speechRecognizerAuthorizationStatus = .restricted
    }
  }

  func testAllowAndRecord() {
    var speechClient = SpeechClient.failing
    speechClient.finishTask = {
      .fireAndForget { self.recognitionTaskSubject.input.sendCompleted() }
    }
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.output.producer }
    speechClient.requestAuthorization = { Effect(value: .authorized) }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: ImmediateScheduler(),
        speechClient: speechClient
      )
    )

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

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.input.send(value: .taskResult(result))
    store.receive(.speech(.success(.taskResult(result)))) {
      $0.transcribedText = "Hello"
    }

    self.recognitionTaskSubject.input.send(value: .taskResult(finalResult))
    store.receive(.speech(.success(.taskResult(finalResult)))) {
      $0.transcribedText = "Hello world"
    }
  }

  func testAudioSessionFailure() {
    var speechClient = SpeechClient.failing
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.output.producer }
    speechClient.requestAuthorization = { Effect(value: .authorized) }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: ImmediateScheduler(),
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.input.send(error: .couldntConfigureAudioSession)
    store.receive(.speech(.failure(.couldntConfigureAudioSession))) {
      $0.alert = .init(title: .init("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.input.sendCompleted()
  }

  func testAudioEngineFailure() {
    var speechClient = SpeechClient.failing
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.output.producer }
    speechClient.requestAuthorization = { Effect(value: .authorized) }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: ImmediateScheduler(),
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.input.send(error: .couldntStartAudioEngine)
    store.receive(.speech(.failure(.couldntStartAudioEngine))) {
      $0.alert = .init(title: .init("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.input.sendCompleted()
  }
}
