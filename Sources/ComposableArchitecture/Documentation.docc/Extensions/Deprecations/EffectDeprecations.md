# Deprecations

Review unsupported effect APIs and their replacements.

## Overview

Avoid using deprecated APIs in your app. Select a method to see the replacement that you should use instead.

## Topics

### Creating an effect

- ``EffectProducer/task(priority:operation:)``

### Cancellation

- ``EffectProducer/cancel(ids:)-8q1hl``

### Testing

- ``EffectProducer/failing(_:)``
- ``EffectProducer/unimplemented(_:)``

### Combine integration

- ``EffectProducer/Output``
- ``EffectProducer/init(_:)``
- ``EffectProducer/init(value:)``
- ``EffectProducer/init(error:)``
- ``EffectProducer/upstream``
- ``EffectProducer/catching(_:)``
- ``EffectProducer/debounce(id:for:scheduler:options:)-1xdnj``
- ``EffectProducer/debounce(id:for:scheduler:options:)-1oaak``
- ``EffectProducer/deferred(for:scheduler:options:)``
- ``EffectProducer/fireAndForget(_:)``
- ``EffectProducer/future(_:)``
- ``EffectProducer/receive(subscriber:)``
- ``EffectProducer/result(_:)``
- ``EffectProducer/run(_:)``
- ``EffectProducer/throttle(id:for:scheduler:latest:)-3gibe``
- ``EffectProducer/throttle(id:for:scheduler:latest:)-85y01``
- ``EffectProducer/timer(id:every:tolerance:on:options:)-6yv2m``
- ``EffectProducer/timer(id:every:tolerance:on:options:)-8t3is``
- ``EffectProducer/Subscriber``
<!--DocC: Can't currently document `Publisher` extensions. -->
