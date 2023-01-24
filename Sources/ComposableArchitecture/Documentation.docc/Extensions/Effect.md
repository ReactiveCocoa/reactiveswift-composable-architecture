# ``ComposableArchitecture/EffectTask``

## Topics

### Creating an effect

- ``EffectProducer/none``
- ``EffectProducer/task(priority:operation:catch:file:fileID:line:)``
- ``EffectProducer/run(priority:operation:catch:file:fileID:line:)``
- ``EffectProducer/fireAndForget(priority:_:)``
- ``EffectProducer/send(_:)``
- ``TaskResult``

### Cancellation

- ``EffectProducer/cancellable(id:cancelInFlight:)-29q60``
- ``EffectProducer/cancel(id:)-6hzsl``
- ``EffectProducer/cancel(ids:)-1cqqx``
- ``withTaskCancellation(id:cancelInFlight:operation:)-4dtr6``

### Composition

- ``EffectProducer/map(_:)-yn70``
- ``EffectProducer/merge(_:)-45guh``
- ``EffectProducer/merge(_:)-3d54p``

### Concurrency

- ``UncheckedSendable``

### Testing

- ``EffectProducer/unimplemented(_:)``

### SwiftUI integration

- ``EffectProducer/animation(_:)``

### Deprecations

- <doc:EffectDeprecations>
