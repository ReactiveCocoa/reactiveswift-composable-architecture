import Benchmark
import ComposableArchitecture
import Dependencies
import Foundation
import ReactiveSwift

let dependenciesSuite = BenchmarkSuite(name: "Dependencies") { suite in
  #if swift(>=5.7)
    let reducer: some ReducerProtocol<Int, Void> = EmptyReducer()
      .dependency(\.calendar, .autoupdatingCurrent)
      .dependency(\.date, .init { Date() })
      .dependency(\.locale, .autoupdatingCurrent)
      .dependency(\.mainQueue, ImmediateScheduler())
      .dependency(\.timeZone, .autoupdatingCurrent)
      .dependency(\.uuid, .init { UUID() })

    suite.benchmark("Dependency key writing") {
      var state = 0
      _ = reducer.reduce(into: &state, action: ())
      precondition(state == 0)
    }
  #endif
}
