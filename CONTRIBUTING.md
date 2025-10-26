# Contributing to Flow

Thank you for your interest in contributing to Flow! This document provides guidelines for contributing to the project.

## Code of Conduct

Please be respectful and constructive in all interactions with the community.

## How to Contribute

### Reporting Issues

- Use the GitHub issue tracker
- Search for existing issues before creating a new one
- Provide a clear description and reproduction steps
- Include relevant code samples and error messages

### Submitting Pull Requests

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
   - Write clear, concise code
   - Follow the existing code style
   - Add tests for new functionality
4. **Ensure tests pass**
   ```bash
   swift test
   ```
5. **Commit your changes**
   - Use descriptive commit messages
   - Follow conventional commit format:
     - `feat: add new feature`
     - `fix: resolve bug`
     - `docs: update documentation`
     - `refactor: improve code structure`
     - `test: add tests`
     - `chore: update dependencies`
6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Create a Pull Request**
   - Provide a clear description of changes
   - Reference any related issues
   - Ensure CI checks pass

### PR Title Guidelines

Use descriptive titles with keywords for automatic labeling:

- **Features**: `feat: add new middleware system`
- **Bug Fixes**: `fix: resolve task cancellation issue`
- **Documentation**: `docs: update getting started guide`
- **Refactoring**: `refactor: simplify ActionHandler API`
- **Tests**: `test: add coverage for TaskManager`
- **Performance**: `perf: optimize state updates`
- **Breaking Changes**: `feat!: redesign Store API` (note the `!`)
- **Maintenance**: `chore: update dependencies`
- **Security**: `security: fix vulnerability`

PRs will be automatically labeled based on these keywords.

## Development Setup

### Requirements

- Swift 6.2+
- macOS 15.0+ (for development)

### Building

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Code Coverage

```bash
swift test --enable-code-coverage
```

### Code Style

- **SwiftLint**: Run `swiftlint` to check style
- **Swift Format**: Run `swift-format lint --recursive Sources Tests`

## Project Structure

```
Flow/
├── Sources/Flow/
│   ├── Store/           # Core store implementation
│   ├── ActionHandler/   # Action processing
│   ├── Middleware/      # Middleware system
│   └── TestStore/       # Testing utilities
├── Tests/
│   ├── UnitTests/       # Unit tests
│   └── IntegrationTests/ # Integration tests
└── Examples/DemoApp/    # Example application
```

## Release Process (Maintainers Only)

Flow uses automated releases via GitHub Actions:

### Creating a Release

1. **Ensure all tests pass**
2. **Update version in Package.swift if needed**
3. **Create and push a version tag**:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
4. **GitHub Actions will**:
   - Run all tests
   - Generate release notes from PR labels
   - Create a pre-release
5. **Review and publish**:
   - Go to GitHub Releases
   - Review the automatically generated notes
   - Edit if necessary
   - Uncheck "This is a pre-release"
   - Click "Publish release"

### Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features (backward compatible)
- **PATCH** (0.0.1): Bug fixes (backward compatible)

## Testing Guidelines

### Writing Tests

- **Unit tests**: Test individual components in isolation
- **Integration tests**: Test component interactions
- **Use TestStore**: For feature testing with assertions
- **Mock dependencies**: Inject mocks via initializers

### Test Coverage Goals

- Aim for high coverage (>90%)
- All public APIs should be tested
- Test edge cases and error conditions

### Example Test

```swift
@MainActor
final class MyFeatureTests: XCTestCase {
    func testFeature() async {
        let store = TestStore(
            initialState: MyFeature.State(),
            feature: MyFeature()
        )

        await store.send(.action) { state in
            state.value = expectedValue
        }
    }
}
```

## Documentation

### Code Documentation

- Use triple-slash comments (`///`)
- Document all public APIs
- Include code examples in documentation
- Follow Swift DocC format

### Example

```swift
/// Processes an action and updates state.
///
/// - Parameters:
///   - action: The action to process
///   - state: The current state
/// - Returns: An ActionTask for side effects
///
/// ## Example
/// ```swift
/// let task = await handler.handle(action: .increment, state: state)
/// ```
public func handle(action: Action, state: State) async -> ActionTask
```

## Questions?

- Open a [GitHub Discussion](../../discussions)
- Check existing [Issues](../../issues)
- Review the [Documentation](../../wiki)

Thank you for contributing to Flow! 🎉
