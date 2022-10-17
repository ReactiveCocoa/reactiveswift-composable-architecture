import Benchmark
import ComposableArchitecture
import Foundation
import ReactiveSwift

let effectSuite = BenchmarkSuite(name: "Effects") {
  $0.benchmark("Merged Effect.none (create, flat)") {
    doNotOptimizeAway(EffectTask<Int>.merge((1...100).map { _ in .none }))
  }

  $0.benchmark("Merged Effect.none (create, nested)") {
    var effect = EffectTask<Int>.none
    for _ in 1...100 {
      effect = effect.merge(with: .none)
    }
    doNotOptimizeAway(effect)
  }

  let effect = EffectTask<Int>.merge((1...100).map { _ in .none })
  var didComplete = false
  $0.benchmark("Merged Effect.none (start)") {
    doNotOptimizeAway(
      effect.producer.startWithCompleted { didComplete = true }
    )
  } tearDown: {
    precondition(didComplete)
  }
}
