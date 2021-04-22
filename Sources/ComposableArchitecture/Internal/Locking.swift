import Foundation

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  extension UnsafeMutablePointer where Pointee == os_unfair_lock_s {
    @inlinable @discardableResult
    func sync<R>(_ work: () -> R) -> R {
      os_unfair_lock_lock(self)
      defer { os_unfair_lock_unlock(self) }
      return work()
    }
  }
#endif

/// `Lock` exposes `os_unfair_lock` on supported platforms, with pthread mutex as the
/// fallback.
/// Implementation copied from https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/Atomic.swift
internal class Lock {
  #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  @available(iOS 10.0, *)
  @available(macOS 10.12, *)
  @available(tvOS 10.0, *)
  @available(watchOS 3.0, *)
  internal final class UnfairLock: Lock {
    private let _lock: os_unfair_lock_t

    override init() {
      _lock = .allocate(capacity: 1)
      _lock.initialize(to: os_unfair_lock())
      super.init()
    }

    override func lock() {
      os_unfair_lock_lock(_lock)
    }

    override func unlock() {
      os_unfair_lock_unlock(_lock)
    }

    override func `try`() -> Bool {
      return os_unfair_lock_trylock(_lock)
    }

    deinit {
      _lock.deinitialize(count: 1)
      _lock.deallocate()
    }
  }
  #endif

  internal final class PthreadLock: Lock {
    private let _lock: UnsafeMutablePointer<pthread_mutex_t>

    init(recursive: Bool = false) {
      _lock = .allocate(capacity: 1)
      _lock.initialize(to: pthread_mutex_t())

      let attr = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
      attr.initialize(to: pthread_mutexattr_t())
      pthread_mutexattr_init(attr)

      defer {
        pthread_mutexattr_destroy(attr)
        attr.deinitialize(count: 1)
        attr.deallocate()
      }

      pthread_mutexattr_settype(attr, Int32(recursive ? PTHREAD_MUTEX_RECURSIVE : PTHREAD_MUTEX_ERRORCHECK))

      let status = pthread_mutex_init(_lock, attr)
      assert(status == 0, "Unexpected pthread mutex error code: \(status)")

      super.init()
    }

    override func lock() {
      let status = pthread_mutex_lock(_lock)
      assert(status == 0, "Unexpected pthread mutex error code: \(status)")
    }

    override func unlock() {
      let status = pthread_mutex_unlock(_lock)
      assert(status == 0, "Unexpected pthread mutex error code: \(status)")
    }

    override func `try`() -> Bool {
      let status = pthread_mutex_trylock(_lock)
      switch status {
      case 0:
        return true
      case EBUSY, EAGAIN, EDEADLK:
        return false
      default:
        assertionFailure("Unexpected pthread mutex error code: \(status)")
        return false
      }
    }

    deinit {
      let status = pthread_mutex_destroy(_lock)
      assert(status == 0, "Unexpected pthread mutex error code: \(status)")

      _lock.deinitialize(count: 1)
      _lock.deallocate()
    }
  }

  static func make() -> Lock {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    if #available(*, iOS 10.0, macOS 10.12, tvOS 10.0, watchOS 3.0) {
      return UnfairLock()
    }
    #endif

    return PthreadLock()
  }

  private init() {}

  func lock() { fatalError() }
  func unlock() { fatalError() }
  func `try`() -> Bool { fatalError() }
}

extension Lock.PthreadLock {
  @inlinable @discardableResult
  func sync<R>(work: () -> R) -> R {
    self.lock()
    defer { self.unlock() }
    return work()
  }
}
