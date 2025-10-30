# Changelog

All notable changes to Flow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-10-31

### Documentation

#### Comprehensive DocC Improvements

This release includes a major overhaul of Flow's documentation based on a thorough three-round review of all DocC files. The improvements enhance clarity, add missing explanations, and significantly improve the learning experience for both beginners and advanced users.

**High Priority Improvements:**

- **Added thread-safety warning for `@unchecked Sendable`** in Middleware documentation
  - Explains that `@unchecked Sendable` bypasses Swift's concurrency checks
  - Clarifies why it's safe in Flow (MainActor execution guarantee)
  - Includes inline code comments for better understanding

- **Enhanced Getting Started guide** with clearer structure
  - Added descriptive step titles ("Step 1: Define Your Feature", "Step 2: Create Your View")
  - Added guidance note directing readers to CoreConcepts for detailed explanations
  - Improved learning flow from practical example to conceptual understanding

- **Added Quick Reference table** to Core Elements
  - At-a-glance overview of all 5 core types (Store, Feature, ActionHandler, ActionResult, ActionTask)
  - Lists purpose and key APIs for each element
  - Improves discoverability and quick lookups

- **Expanded core sections** with detailed explanations
  - Store: Key responsibilities, `@State` lifecycle, sending actions
  - Feature: Benefits (cohesion, reusability, type safety) with complete implementation
  - ActionHandler: How it works with synchronous/async examples

- **Simplified Result-Returning Actions** example in Core Concepts
  - Replaced complex parent-child navigation example with clearer login validation example
  - Better demonstrates `.just()`, `.run`, and Result type handling
  - More accessible for beginners

- **Added comprehensive error handling** to Practical Guide
  - Task Cancellation: Added `.catch` with `cancelInFlight` explanation
  - Parallel Processing: Added error handling for concurrent operations
  - Parent-Child Communication: Added `.failure` case handling

**Medium Priority Improvements:**

- **Added multiple middleware usage section**
  - Explains how to chain multiple middleware with `.use()`
  - Documents execution order (beforeAction: top-down, afterAction: bottom-up, onError: top-down)
  - Includes practical example combining logging, analytics, and error reporting

- **Expanded `.just()` explanation** in Core Elements
  - Compares `.just()` with `.none` for clarity
  - Lists common use cases (validation, calculations, cache hits)
  - Clarifies when to use synchronous vs async result returns

- **Simplified Task Priority section** with reference table
  - Replaced four separate code examples with concise reference table
  - Adds note clarifying priority affects scheduling but doesn't guarantee order
  - More scannable while preserving essential information

**Additional Improvements:**

- **Added Overview section** to Flow landing page
  - Design philosophy explanation (view-local, unidirectional, type-safe, concurrency)
  - Quick counter example for 30-second understanding
  - Architecture diagram reference
  - Comparison with global store architectures

- **Added detailed `.cancellable()` explanation**
  - Parameter descriptions (`id` for identification, `cancelInFlight` behavior)
  - Task ID naming conventions and best practices
  - Scoping information (task IDs are per-Store instance)

**Statistics:**
- 6 files modified (all Flow DocC files)
- 12 commits of improvements
- +307 lines added, -71 lines removed (net +236 lines)
- Improved sections in Flow.md, GettingStarted.md, CoreConcepts.md, CoreElements.md, Middleware.md, PracticalGuide.md

## [1.1.1] - 2025-10-30

### Bug Fixes

- **SwiftLint compliance**: Fixed `modifier_order` violation in LocationService initializer
  - Corrected modifier order from `nonisolated override` to `override nonisolated`
  - Ensures CI SwiftLint checks pass with `--strict` mode
  - Follows Swift's modifier ordering rules as specified in Swift Language Guide

### Documentation

- **Improved clarity**: Removed subjective and exaggerated expressions from documentation
  - Updated CoreConcepts.md for more objective technical descriptions
  - Simplified Flow.md introduction for better clarity
  - Improved README.md to focus on factual feature descriptions
  - Enhanced professional tone across all documentation

## [1.1.0] - 2025-10-27

### Features

#### Task Naming Support

- **Added task naming for `.run` effects**: Leverages Swift 6.2's SE-0469 task naming capability
  - New optional `name` parameter in `.run(name:operation:)` for improved debugging and profiling
  - Task names appear in Xcode debugger, Instruments, and swift-inspect
  - Fully backward compatible—existing code works unchanged
  - Names are preserved through all configuration methods (`.catch`, `.cancellable`, `.priority`)

  ```swift
  // Named task for better debugging
  return .run(name: "🔄 Fetch user profile") { state in
      let profile = try await api.fetchProfile()
      state.profile = profile
  }

  // Dynamic naming with context
  return .run(name: "Load user \(userId)") { state in
      let user = try await api.fetchUser(userId)
      state.user = user
  }
  ```

**Benefits:**
- Tasks are easily identifiable in development tools
- Better observability during debugging and profiling
- Human-readable task names in thread lists and performance traces

**Requirements:**
- Swift 6.2+ (for Task naming API support)

### Documentation

- **Improved README.md**: Enhanced "Result-Returning Actions" section with clearer explanations
  - Explicitly mentions that `ActionResult` type can be freely defined per Feature
  - Provides better context for code examples
  - Clarifies how ChildFeature, ParentView, and callbacks work together
  - Emphasizes dependency tracking within the view tree

### Tests

- Added 6 comprehensive tests for task naming feature:
  - Basic task naming functionality
  - Backward compatibility verification (name = nil)
  - Name preservation through `.catch`, `.cancellable`, `.priority`
  - Name preservation through complete configuration chaining
- All 299 tests pass (293 existing + 6 new)

### Internal

- Fixed SwiftLint `function_parameter_count` violation in `Store.executeRunTask`

## [1.0.1] - 2025-10-27

### Documentation

#### Improvements

- **Reduced redundant expressions**: Simplified English documentation for better readability
  - Updated version numbers from 0.1.6 to 1.0.0 in Getting Started guide
  - Simplified opening description in README.md
  - Changed "Reduced code" to "Less boilerplate code" for clarity
  - Removed duplicate bullet point about compile-time safety
  - Consolidated middleware description from 2 sentences to 1
  - Simplified phrasing in feature descriptions

- **Added Japanese README link**: Added prominent link to Japanese version (README_jp.md) at the top of English README for better discoverability

All changes improve documentation clarity while maintaining technical accuracy and community-friendly tone.

## [1.0.0] - 2025-10-27

### Release Highlights

This is the first stable release of Flow! 🎉

Flow provides a unidirectional data flow architecture for SwiftUI applications with full support for Swift 6 Approachable Concurrency. After several months of development and refinement, the API is now stable and ready for production use.

### Key Features

- **No Global Store**: Each view holds its own state with `@State`
- **Result-Returning Actions**: Actions can return results through `ActionTask` for parent-child communication
- **@Observable Support**: Uses SwiftUI's standard `@Observable` instead of `@ObservableObject`
- **Approachable Concurrency**: Full Swift 6 concurrency support with `defaultIsolation(MainActor.self)`
- **Observable Actions**: Middleware system for cross-cutting concerns like logging and analytics

### Documentation

- Complete English translation of all documentation
- Comprehensive guides including Getting Started, Core Concepts, Practical Guide, and Middleware
- Real-world examples demonstrating best practices

### Breaking Changes

None - this is the initial stable release.

