// NB: Deprecated after 0.6.0:

extension Reducer {
  @available(*, deprecated, renamed: "optional()")
  public var optional: Reducer<State?, Action, Environment> {
    self.optional()
  }
}

