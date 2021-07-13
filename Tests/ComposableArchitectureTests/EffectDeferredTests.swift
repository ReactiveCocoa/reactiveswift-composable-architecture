import ComposableArchitecture
import ReactiveSwift
import XCTest

final class EffectDeferredTests: XCTestCase {
  func testDeferred() {
    let scheduler = TestScheduler()
    var values: [Int] = []
    
    func runDeferredEffect(value: Int) {
      SignalProducer(value: value)
        .deferred(for: 1, scheduler: scheduler)
        .startWithValues { values.append($0) }
    }
    
    runDeferredEffect(value: 1)
    
    // Nothing emits right away.
    XCTAssertEqual(values, [])
    
    // Waiting half the time also emits nothing
    scheduler.advance(by: .milliseconds(500))
    XCTAssertEqual(values, [])
    
    // Run another deferred effect.
    runDeferredEffect(value: 2)
    
    // Waiting half the time emits first deferred effect received.
    scheduler.advance(by: .milliseconds(500))
    XCTAssertEqual(values, [1])
    
    // Run another deferred effect.
    runDeferredEffect(value: 3)
    
    // Waiting half the time emits second deferred effect received.
    scheduler.advance(by: .milliseconds(500))
    XCTAssertEqual(values, [1, 2])
    
    // Waiting the rest of the time emits the final effect value.
    scheduler.advance(by: .milliseconds(500))
    XCTAssertEqual(values, [1, 2, 3])
    
    // Running out the scheduler
    scheduler.run()
    XCTAssertEqual(values, [1, 2, 3])
  }
  
  func testDeferredIsLazy() {
    let scheduler = TestScheduler()
    var values: [Int] = []
    var effectRuns = 0
    
    func runDeferredEffect(value: Int) {
      Effect.deferred { () -> Effect<Int, Never> in
        effectRuns += 1
        return Effect(value: value)
      }
      .deferred(for: 1, scheduler: scheduler)
      .startWithValues { values.append($0) }
    }
    
    runDeferredEffect(value: 1)
    
    XCTAssertEqual(values, [])
    XCTAssertEqual(effectRuns, 0)
    
    scheduler.advance(by: .milliseconds(500))
    
    XCTAssertEqual(values, [])
    XCTAssertEqual(effectRuns, 0)
    
    scheduler.advance(by: .milliseconds(500))
    
    XCTAssertEqual(values, [1])
    XCTAssertEqual(effectRuns, 1)
  }
}
