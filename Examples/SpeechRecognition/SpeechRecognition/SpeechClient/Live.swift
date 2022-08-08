import ComposableArchitecture
import ReactiveSwift
import Speech

extension SpeechClient {
  static var live: Self {
    var audioEngine: AVAudioEngine?
    var recognitionTask: SFSpeechRecognitionTask?

    return Self(
      finishTask: {
        .fireAndForget {
          audioEngine?.stop()
          audioEngine?.inputNode.removeTap(onBus: 0)
          recognitionTask?.finish()
        }
      },
      requestAuthorization: {
        .future { callback in
          SFSpeechRecognizer.requestAuthorization { status in
            callback(.success(status))
          }
        }
      },
      startTask: { request in
        Effect { subscriber, lifetime in
          audioEngine = AVAudioEngine()
          let audioSession = AVAudioSession.sharedInstance()
          do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
          } catch {
            subscriber.send(error: .couldntConfigureAudioSession)
            return
          }

          let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
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

          let cancellable = AnyDisposable {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
            recognitionTask?.cancel()
          }
          lifetime += cancellable

          audioEngine?.inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: audioEngine?.inputNode.outputFormat(forBus: 0)
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
      }
    )
  }
}
