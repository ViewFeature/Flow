# Changelog

All notable changes to Flow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## [0.1.6] - 2025-01-25

### Documentation

#### Major Restructuring
- **Flattened DocC hierarchy**: Moved all documentation from `Articles/Essentials/` to `.docc` root for simpler navigation
- **Reduced complexity by 420 lines**: Removed redundant examples and consolidated sections
- **Improved learning path**: Better progression from beginner to advanced concepts

#### Content Improvements

**Flow.md**
- Removed duplication between Learning Path and Topics sections
- Reorganized Topics into Essentials and Advanced categories
- Clearer navigation structure

**GettingStarted.md**
- Removed duplicate Next Steps section
- Removed unnecessary `init()` methods from examples
- Updated version placeholders to 1.0.0

**CoreConcepts.md**
- Moved Result type details to FeatureComposition for better context
- Reordered sections to present "Why This Architecture?" earlier
- Removed complex Background Work example (-40 lines)
- Added simpler note about async dependencies

**FeatureComposition.md** (-160 lines)
- Added "Philosophy: SwiftUI is the Tree" section at beginning
- Improved Pattern 1 with single view example before multiple views
- Consolidated 5 patterns → 3 patterns:
  - Pattern 3 (Initialization) merged into Pattern 2 as subsection
  - Pattern 4 & 5 combined into Pattern 3 (Advanced Composition)
- Removed 110-line registration flow example
- Consolidated Best Practices into Common Pitfalls section
- Updated Pattern Selection Guide

**Middleware.md** (-220 lines)
- Improved @unchecked Sendable explanation with gradual approach
- Reduced Real-World Examples from 5 to 2 (kept Performance Monitoring & Debug Logging)
- Consolidated 4 Protocol sections into single "Middleware Hooks" section
- Simplified Testing section (removed UnsafeMutablePointer)
- Removed Advanced Patterns section

**QuickReference.md**
- Shortened all examples (e.g., Parent-Child: 46→23 lines)
- Added missing Middleware section with 3 patterns
- Added missing Task Management section with 2 patterns
- Consolidated Action Results examples

#### Impact
- **Total reduction**: 420 lines (510 deletions, 90 insertions)
- **Section reduction**: 35% fewer sections (24 → 16)
- **Pattern simplification**: 5 → 3 patterns in FeatureComposition
- **Better structure**: Clearer hierarchy and navigation
- **More accessible**: Beginner-friendly progression throughout

## [0.1.5] - Previous Release

...

