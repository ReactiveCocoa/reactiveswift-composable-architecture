import ComposableArchitecture
import ComposableCoreMotion
import CoreMotion
import ReactiveSwift
import XCTest

@testable import MotionManagerDemo

class MotionTests: XCTestCase {
  func testMotionUpdate() {
    let motionSubject = Signal<DeviceMotion, Error>.pipe()

    var motionManagerIsLive = false

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        motionManager: .mock(
          create: { _ in .fireAndForget { motionManagerIsLive = true } },
          destroy: { _ in .fireAndForget { motionManagerIsLive = false } },
          deviceMotion: { _ in nil },
          startDeviceMotionUpdates: { _, _, _ in motionSubject.output.producer },
          stopDeviceMotionUpdates: { _ in
            .fireAndForget { motionSubject.input.sendCompleted() }
          }
        )
      )
    )

    let deviceMotion = DeviceMotion(
      attitude: .init(quaternion: .init(x: 1, y: 0, z: 0, w: 0)),
      gravity: CMAcceleration(x: 1, y: 2, z: 3),
      heading: 0,
      magneticField: .init(field: .init(x: 0, y: 0, z: 0), accuracy: .high),
      rotationRate: .init(x: 0, y: 0, z: 0),
      timestamp: 0,
      userAcceleration: CMAcceleration(x: 4, y: 5, z: 6)
    )

    store.assert(
      .send(.recordingButtonTapped) {
        $0.isRecording = true
        XCTAssertEqual(motionManagerIsLive, true)
      },

      .do { motionSubject.input.send(value: deviceMotion) },
      .receive(.motionUpdate(.success(deviceMotion))) {
        $0.z = [32]
      },

      .send(.recordingButtonTapped) {
        $0.isRecording = false
        XCTAssertEqual(motionManagerIsLive, false)
      }
    )
  }

  func testFacingDirection() {
    let motionSubject = Signal<DeviceMotion, Error>.pipe()
    var motionManagerIsLive = false

    let initialDeviceMotion = DeviceMotion(
      attitude: .init(quaternion: .init(x: 1, y: 0, z: 0, w: 0)),
      gravity: CMAcceleration(x: 0, y: 0, z: 0),
      heading: 0,
      magneticField: .init(field: .init(x: 0, y: 0, z: 0), accuracy: .high),
      rotationRate: .init(x: 0, y: 0, z: 0),
      timestamp: 0,
      userAcceleration: CMAcceleration(x: 0, y: 0, z: 0)
    )
    var updatedDeviceMotion = initialDeviceMotion
    updatedDeviceMotion.attitude = .init(quaternion: .init(x: 0, y: 0, z: 1, w: 0))

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        motionManager: .mock(
          create: { _ in .fireAndForget { motionManagerIsLive = true } },
          destroy: { _ in .fireAndForget { motionManagerIsLive = false } },
          deviceMotion: { _ in initialDeviceMotion },
          startDeviceMotionUpdates: { _, _, _ in motionSubject.output.producer },
          stopDeviceMotionUpdates: { _ in
            .fireAndForget { motionSubject.input.sendCompleted() }
          }
        )
      )
    )

    store.assert(
      .send(.recordingButtonTapped) {
        $0.isRecording = true
        XCTAssertEqual(motionManagerIsLive, true)
      },

      .do { motionSubject.input.send(value: initialDeviceMotion) },
      .receive(.motionUpdate(.success(initialDeviceMotion))) {
        $0.facingDirection = .forward
        $0.initialAttitude = initialDeviceMotion.attitude
        $0.z = [0]
      },

      .do { motionSubject.input.send(value: updatedDeviceMotion) },
      .receive(.motionUpdate(.success(updatedDeviceMotion))) {
        $0.z = [0, 0]
        $0.facingDirection = .backward
      },

      .send(.recordingButtonTapped) {
        $0.facingDirection = nil
        $0.initialAttitude = nil
        $0.isRecording = false
        XCTAssertEqual(motionManagerIsLive, false)
      }
    )
  }
}
