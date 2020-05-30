import ReactiveSwift
import ComposableArchitecture
import XCTest

@testable import SpeechRecognition

class SpeechRecognitionTests: XCTestCase {
  let recognitionTaskSubject = Signal<SpeechClient.Action, SpeechClient.Error>.pipe()
  let scheduler = TestScheduler()

  func testDenyAuthorization() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler,
        speechClient: .mock(
          requestAuthorization: { Effect(value: .denied) }
        )
      )
    )

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },
      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
        $0.authorizationStateAlert =
          "You denied access to speech recognition. This app needs access to transcribe your speech."
        $0.isRecording = false
        $0.speechRecognizerAuthorizationStatus = .denied
      }
    )
  }

  func testRestrictedAuthorization() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler,
        speechClient: .mock(
          requestAuthorization: { Effect(value: .restricted) }
        )
      )
    )

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },
      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
        $0.authorizationStateAlert = "Your device does not allow speech recognition."
        $0.isRecording = false
        $0.speechRecognizerAuthorizationStatus = .restricted
      }
    )
  }

  func testAllowAndRecord() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler,
        speechClient: .mock(
          finishTask: { _ in
            .fireAndForget { self.recognitionTaskSubject.input.sendCompleted() }
          },
          recognitionTask: { _, _ in self.recognitionTaskSubject.output.producer },
          requestAuthorization: { Effect(value: .authorized) }
        )
      )
    )

    let result = SpeechRecognitionResult(
      bestTranscription: Transcription(
        averagePauseDuration: 0.1,
        formattedString: "Hello",
        segments: [],
        speakingRate: 1
      ),
      transcriptions: [],
      isFinal: false
    )
    var finalResult = result
    finalResult.bestTranscription.formattedString = "Hello world"
    finalResult.isFinal = true

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },

      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
        $0.speechRecognizerAuthorizationStatus = .authorized
      },

      .do { self.recognitionTaskSubject.input.send(value: .taskResult(result)) },
      .receive(.speech(.success(.taskResult(result)))) {
        $0.transcribedText = "Hello"
      },

      .do { self.recognitionTaskSubject.input.send(value: .taskResult(finalResult)) },
      .receive(.speech(.success(.taskResult(finalResult)))) {
        $0.transcribedText = "Hello world"
      }
    )
  }

  func testAudioSessionFailure() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler,
        speechClient: .mock(
          recognitionTask: { _, _ in self.recognitionTaskSubject.output.producer },
          requestAuthorization: { Effect(value: .authorized) }
        )
      )
    )

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },

      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
        $0.speechRecognizerAuthorizationStatus = .authorized
      },

      .do { self.recognitionTaskSubject.input.send(error: .couldntConfigureAudioSession) },
      .receive(.speech(.failure(.couldntConfigureAudioSession))) {
        $0.authorizationStateAlert = "Problem with audio device. Please try again."
      },

      .do { self.recognitionTaskSubject.input.sendCompleted() }
    )
  }

  func testAudioEngineFailure() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler,
        speechClient: .mock(
          recognitionTask: { _, _ in self.recognitionTaskSubject.output.producer },
          requestAuthorization: { Effect(value: .authorized) }
        )
      )
    )

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },

      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
        $0.speechRecognizerAuthorizationStatus = .authorized
      },

      .do { self.recognitionTaskSubject.input.send(error: .couldntStartAudioEngine) },
      .receive(.speech(.failure(.couldntStartAudioEngine))) {
        $0.authorizationStateAlert = "Problem with audio device. Please try again."
      },

      .do { self.recognitionTaskSubject.input.sendCompleted() }
    )
  }
}
