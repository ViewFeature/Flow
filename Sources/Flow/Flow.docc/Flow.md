# ``Flow``

A library for managing state in SwiftUI applications in a type-safe way. Flow provides a unidirectional data flow architecture with full support for Swift 6 Approachable Concurrency.

## Key Features

- **No global store** - Each view holds its own state with `@State`
- **Result-returning actions** - Views receive action processing results
- **Swift 6 support** - Thread-safe by default with Approachable Concurrency
- **@Observable support** - Uses SwiftUI's standard `@Observable` with no Combine dependency
- **Flexible middleware** - Add cross-cutting concerns like logging, analytics, and debugging

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:CoreConcepts>
- <doc:CoreElements>
- <doc:Middleware>

### Practical Guide

- <doc:PracticalGuide>
