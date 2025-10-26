# Changelog

All notable changes to Flow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

