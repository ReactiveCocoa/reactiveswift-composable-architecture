import ComposableArchitecture
import CoreLocation
import ReactiveSwift

extension LocationManager {

  /// The live implementation of the `LocationManager` interface. This implementation is capable of
  /// creating real `CLLocationManager` instances, listening to its delegate methods, and invoking
  /// its methods. You will typically use this when building for the simulator or device:
  ///
  ///     let store = Store(
  ///       initialState: AppState(),
  ///       reducer: appReducer,
  ///       environment: AppEnvironment(
  ///         locationManager: LocationManager.live
  ///       )
  ///     )
  ///
  public static let live: LocationManager = { () -> LocationManager in
    var manager = LocationManager()

    manager.authorizationStatus = CLLocationManager.authorizationStatus

    manager.create = { id in
      Effect { subscriber, lifetime in
        let manager = CLLocationManager()
        var delegate = LocationManagerDelegate()
        delegate.didChangeAuthorization = {
          subscriber.send(value: .didChangeAuthorization($0))
        }
        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
          delegate.didDetermineStateForRegion = { state, region in
            subscriber.send(value: .didDetermineState(state, region: Region(rawValue: region)))
          }
        #endif
        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
          delegate.didEnterRegion = { region in
            subscriber.send(value: .didEnterRegion(Region(rawValue: region)))
          }
        #endif
        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
          delegate.didExitRegion = { region in
            subscriber.send(value: .didExitRegion(Region(rawValue: region)))
          }
        #endif
        if #available(iOS 13, *) {
          #if os(iOS) || targetEnvironment(macCatalyst)
            delegate.didFailRangingForConstraintWithError = { constraint, error in
              subscriber.send(
                value: .didFailRanging(beaconConstraint: constraint, error: Error(error)))
            }
          #endif
        }
        delegate.didFailWithError = { error in
          subscriber.send(value: .didFailWithError(Error(error)))
        }
        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
          delegate.didFinishDeferredUpdatesWithError = { error in
            subscriber.send(value: .didFinishDeferredUpdatesWithError(error.map(Error.init)))
          }
        #endif
        #if os(iOS) || targetEnvironment(macCatalyst)
          delegate.didPauseLocationUpdates = {
            subscriber.send(value: .didPauseLocationUpdates)
          }
        #endif
        #if os(iOS) || targetEnvironment(macCatalyst)
          delegate.didResumeLocationUpdates = {
            subscriber.send(value: .didResumeLocationUpdates)
          }
        #endif
        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
          delegate.didStartMonitoringForRegion = { region in
            subscriber.send(value: .didStartMonitoring(region: Region(rawValue: region)))
          }
        #endif
        #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
          delegate.didUpdateHeading = { heading in
            subscriber.send(value: .didUpdateHeading(newHeading: Heading(rawValue: heading)))
          }
        #endif
        #if os(macOS)
          delegate.didUpdateToLocationFromLocation = { newLocation, oldLocation in
            subscriber.send(
              value:
                .didUpdateTo(
                  newLocation: Location(rawValue: newLocation),
                  oldLocation: Location(rawValue: oldLocation)
                )
            )
          }
        #endif
        delegate.didUpdateLocations = {
          subscriber.send(value: .didUpdateLocations($0.map(Location.init(rawValue:))))
        }
        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
          delegate.monitoringDidFailForRegionWithError = { region, error in
            subscriber.send(
              value: .monitoringDidFail(
                region: region.map(Region.init(rawValue:)), error: Error(error)))
          }
        #endif
        #if os(iOS) || targetEnvironment(macCatalyst)
          delegate.didVisit = { visit in
            subscriber.send(value: .didVisit(Visit(visit: visit)))
          }
        #endif
        manager.delegate = delegate

        dependencies[id] = Dependencies(
          delegate: delegate,
          manager: manager,
          subscriber: subscriber
        )

        lifetime += AnyDisposable {
          dependencies[id] = nil
        }
      }
    }

    manager.destroy = { id in
      .fireAndForget {
        dependencies[id]?.subscriber.sendCompleted()
        dependencies[id] = nil
      }
    }

    manager.locationServicesEnabled = CLLocationManager.locationServicesEnabled

    manager.location = { id in dependencies[id]?.manager.location.map(Location.init(rawValue:)) }

    manager.accuracyAuthorization = { id in
      #if (compiler(>=5.3) && !(os(macOS) || targetEnvironment(macCatalyst))) || compiler(>=5.3.1)
      if #available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, macCatalyst 14.0, *) {
        return AccuracyAuthorization(dependencies[id]?.manager.accuracyAuthorization)
      }
      #endif
      return nil
    }

    manager.requestLocation = { id in
      .fireAndForget { dependencies[id]?.manager.requestLocation() }
    }

    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
      if #available(OSX 10.15, *) {
        manager.requestAlwaysAuthorization = { id in
          .fireAndForget { dependencies[id]?.manager.requestAlwaysAuthorization() }
        }
      }
    #endif

    #if os(iOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
      manager.requestWhenInUseAuthorization = { id in
        .fireAndForget { dependencies[id]?.manager.requestWhenInUseAuthorization() }
      }
    #endif

    manager.set = { id, properties in
      .fireAndForget {
        guard let manager = dependencies[id]?.manager else { return }

        #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
          if let activityType = properties.activityType {
            manager.activityType = activityType
          }
          if let allowsBackgroundLocationUpdates = properties.allowsBackgroundLocationUpdates {
            manager.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
          }
        #endif
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
          if let desiredAccuracy = properties.desiredAccuracy {
            manager.desiredAccuracy = desiredAccuracy
          }
          if let distanceFilter = properties.distanceFilter {
            manager.distanceFilter = distanceFilter
          }
        #endif
        #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
          if let headingFilter = properties.headingFilter {
            manager.headingFilter = headingFilter
          }
          if let headingOrientation = properties.headingOrientation {
            manager.headingOrientation = headingOrientation
          }
        #endif
        #if os(iOS) || targetEnvironment(macCatalyst)
          if let pausesLocationUpdatesAutomatically = properties.pausesLocationUpdatesAutomatically
          {
            manager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
          }
          if let showsBackgroundLocationIndicator = properties.showsBackgroundLocationIndicator {
            manager.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator
          }
        #endif
      }
    }

    #if os(iOS) || targetEnvironment(macCatalyst)
      manager.startMonitoringVisits = { id in
        .fireAndForget { dependencies[id]?.manager.startMonitoringVisits() }
      }
    #endif

    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
      manager.startUpdatingLocation = { id in
        .fireAndForget { dependencies[id]?.manager.startUpdatingLocation() }
      }
    #endif

    #if os(iOS) || targetEnvironment(macCatalyst)
      manager.stopMonitoringVisits = { id in
        .fireAndForget { dependencies[id]?.manager.stopMonitoringVisits() }
      }
    #endif

    manager.stopUpdatingLocation = { id in
      .fireAndForget { dependencies[id]?.manager.stopUpdatingLocation() }
    }

    return manager
  }()
}

private struct Dependencies {
  let delegate: LocationManagerDelegate
  let manager: CLLocationManager
  let subscriber: Signal<LocationManager.Action, Never>.Observer
}

private var dependencies: [AnyHashable: Dependencies] = [:]

private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
  var didChangeAuthorization: (CLAuthorizationStatus) -> Void = { _ in fatalError() }
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    var didDetermineStateForRegion: (CLRegionState, CLRegion) -> Void = { _, _ in fatalError() }
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    var didEnterRegion: (CLRegion) -> Void = { _ in fatalError() }
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    var didExitRegion: (CLRegion) -> Void = { _ in fatalError() }
  #endif
  #if os(iOS) || targetEnvironment(macCatalyst)
    @available(iOS 13, *)
    lazy var didFailRangingForConstraintWithError: (CLBeaconIdentityConstraint, Error) -> Void = {
      _, _ in fatalError()
    }
  #endif
  var didFailWithError: (Error) -> Void = { _ in fatalError() }
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    var didFinishDeferredUpdatesWithError: (Error?) -> Void = { _ in fatalError() }
  #endif
  #if os(iOS) || targetEnvironment(macCatalyst)
    var didPauseLocationUpdates: () -> Void = { fatalError() }
  #endif
  #if os(iOS) || targetEnvironment(macCatalyst)
    @available(iOS 13, *)
    lazy var didRangeBeaconsSatisfyingConstraint: ([CLBeacon], CLBeaconIdentityConstraint) -> Void =
      {
        _, _ in fatalError()
      }
  #endif
  #if os(iOS) || targetEnvironment(macCatalyst)
    var didResumeLocationUpdates: () -> Void = { fatalError() }
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    var didStartMonitoringForRegion: (CLRegion) -> Void = { _ in fatalError() }
  #endif
  #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    var didUpdateHeading: (CLHeading) -> Void = { _ in fatalError() }
  #endif
  var didUpdateLocations: ([CLLocation]) -> Void = { _ in fatalError() }
  #if os(macOS)
    var didUpdateToLocationFromLocation: (CLLocation, CLLocation) -> Void = { _, _ in fatalError() }
  #endif
  #if os(iOS) || targetEnvironment(macCatalyst)
    var didVisit: (CLVisit) -> Void = { _ in fatalError() }
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    var monitoringDidFailForRegionWithError: (CLRegion?, Error) -> Void = { _, _ in fatalError() }
  #endif

  func locationManager(
    _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
  ) {
    self.didChangeAuthorization(status)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    self.didFailWithError(error)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    self.didUpdateLocations(locations)
  }

  #if os(macOS)
    func locationManager(
      _ manager: CLLocationManager, didUpdateTo newLocation: CLLocation,
      from oldLocation: CLLocation
    ) {
      self.didUpdateToLocationFromLocation(newLocation, oldLocation)
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(
      _ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?
    ) {
      self.didFinishDeferredUpdatesWithError(error)
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
      self.didPauseLocationUpdates()
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
      self.didResumeLocationUpdates()
    }
  #endif

  #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
      self.didUpdateHeading(newHeading)
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
      self.didEnterRegion(region)
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
      self.didExitRegion(region)
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(
      _ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion
    ) {
      self.didDetermineStateForRegion(state, region)
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(
      _ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error
    ) {
      self.monitoringDidFailForRegionWithError(region, error)
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
      self.didStartMonitoringForRegion(region)
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    @available(iOS 13.0, *)
    func locationManager(
      _ manager: CLLocationManager, didRange beacons: [CLBeacon],
      satisfying beaconConstraint: CLBeaconIdentityConstraint
    ) {
      self.didRangeBeaconsSatisfyingConstraint(beacons, beaconConstraint)
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    @available(iOS 13.0, *)
    func locationManager(
      _ manager: CLLocationManager, didFailRangingFor beaconConstraint: CLBeaconIdentityConstraint,
      error: Error
    ) {
      self.didFailRangingForConstraintWithError(beaconConstraint, error)
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
      self.didVisit(visit)
    }
  #endif
}
