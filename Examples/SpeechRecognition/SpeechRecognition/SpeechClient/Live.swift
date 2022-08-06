import ComposableArchitecture
import ReactiveSwift
import Speech

extension SpeechClient {
  static var live: Self {
    var audioEngine: AVAudioEngine?
    var inputNode: AVAudioInputNode?
    var recognitionTask: SFSpeechRecognitionTask?

    return Self(
      finishTask: {
        .fireAndForget {
          audioEngine?.stop()
          inputNode?.removeTap(onBus: 0)
          recognitionTask?.finish()
        }
      },
      recognitionTask: { request in
        Effect { subscriber, lifetime in
          let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
          let cancellable = AnyDisposable {
            audioEngine?.stop()
            inputNode?.removeTap(onBus: 0)
            recognitionTask?.cancel()
            _ = speechRecognizer
          }

          lifetime += cancellable

          audioEngine = AVAudioEngine()
          let audioSession = AVAudioSession.sharedInstance()
          do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
          } catch {
            subscriber.send(error: .couldntConfigureAudioSession)
            return
          }
          inputNode = audioEngine!.inputNode

          recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            switch (result, error) {
            case let (.some(result), _):
              subscriber.send(value: SpeechRecognitionResult(result))
            case (_, .some):
              subscriber.send(error: .taskError)
            case (.none, .none):
              fatalError("It should not be possible to have both a nil result and nil error.")
            }
          }

          inputNode!.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputNode!.outputFormat(forBus: 0)
          ) { buffer, when in
            request.append(buffer)
          }

          audioEngine!.prepare()
          do {
            try audioEngine!.start()
          } catch {
            subscriber.send(error: .couldntStartAudioEngine)
            return
          }

          return
        }
      },
      requestAuthorization: {
        .future { callback in
          SFSpeechRecognizer.requestAuthorization { status in
            callback(.success(status))
          }
        }
      }
    )
  }
}

private class SpeechRecognizerDelegate: NSObject, SFSpeechRecognizerDelegate {
  var availabilityDidChange: (Bool) -> Void

  init(availabilityDidChange: @escaping (Bool) -> Void) {
    self.availabilityDidChange = availabilityDidChange
  }

  func speechRecognizer(
    _ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool
  ) {
    self.availabilityDidChange(available)
  }
}
