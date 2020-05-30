import ReactiveSwift
import ComposableArchitecture
import CoreMotion
import XCTest

@testable import MotionManager

class MotionManagerTests: XCTestCase {
  func testExample() {
    let motionSubject = Signal<MotionClient.Action, MotionClient.Error>.pipe()
    var motionUpdatesStarted = false

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        motionClient: .mock(
          create: { _ in motionSubject.output.producer },
          startDeviceMotionUpdates: { _ in .fireAndForget { motionUpdatesStarted = true } },
          stopDeviceMotionUpdates: { _ in
            .fireAndForget { motionSubject.input.sendCompleted() }
          }
        )
      )
    )

    let deviceMotion = DeviceMotion(
      gravity: CMAcceleration(x: 1, y: 2, z: 3),
      userAcceleration: CMAcceleration(x: 4, y: 5, z: 6)
    )

    store.assert(
      .send(.onAppear),
      .send(.recordingButtonTapped) {
        $0.isRecording = true
        XCTAssertTrue(motionUpdatesStarted)
      },
      .do { motionSubject.input.send(value: .motionUpdate(deviceMotion)) },
      .receive(.motionClient(.success(.motionUpdate(deviceMotion)))) {
        $0.z = [32]
      },
      .send(.recordingButtonTapped) {
        $0.isRecording = false
      }
    )
  }
}
