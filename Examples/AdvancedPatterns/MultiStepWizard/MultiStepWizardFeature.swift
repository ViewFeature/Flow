import Flow
import Foundation

/// Application-specific errors for wizard operations.
enum WizardError: Error, LocalizedError {
  case validationFailed(step: String, errors: [String])
  case submissionFailed(underlying: Error)

  var errorDescription: String? {
    switch self {
    case .validationFailed(let step, let errors):
      return "Validation failed in \(step): \(errors.joined(separator: ", "))"
    case .submissionFailed(let underlying):
      return "Submission failed: \(underlying.localizedDescription)"
    }
  }
}

/// Multi-step wizard/form with complex validation and navigation.
///
/// Demonstrates:
/// - Multi-step workflow with state machine
/// - Step-by-step validation
/// - Conditional navigation
/// - Progress tracking
/// - Save draft / restore state
/// - Final submission
struct MultiStepWizardFeature: Feature {
  // MARK: - Dependencies

  let validator: FormValidator
  let apiClient: SubmissionAPIClient

  init(
    validator: FormValidator = DefaultFormValidator(),
    apiClient: SubmissionAPIClient
  ) {
    self.validator = validator
    self.apiClient = apiClient
  }

  // MARK: - State

  @Observable
  final class State {
    // Current step
    var currentStep: Step = .personalInfo

    // Form data
    var personalInfo = PersonalInfo()
    var addressInfo = AddressInfo()
    var paymentInfo = PaymentInfo()

    // UI state
    var isValidating = false
    var isSubmitting = false
    var error: WizardError?

    // Validation errors per step
    var personalInfoErrors: [String] = []
    var addressInfoErrors: [String] = []
    var paymentInfoErrors: [String] = []

    // Progress
    var completedSteps: Set<Step> = []

    var progress: Double {
      Double(completedSteps.count) / Double(Step.allCases.count)
    }

    init() {}
  }

  enum Step: String, CaseIterable, Sendable {
    case personalInfo = "Personal Info"
    case addressInfo = "Address"
    case paymentInfo = "Payment"
    case review = "Review"

    var index: Int {
      Step.allCases.firstIndex(of: self) ?? 0
    }

    var next: Step? {
      let nextIndex = index + 1
      return nextIndex < Step.allCases.count ? Step.allCases[nextIndex] : nil
    }

    var previous: Step? {
      let prevIndex = index - 1
      return prevIndex >= 0 ? Step.allCases[prevIndex] : nil
    }
  }

  // MARK: - Actions

  enum Action: Sendable {
    case updatePersonalInfo(PersonalInfo)
    case updateAddressInfo(AddressInfo)
    case updatePaymentInfo(PaymentInfo)

    case nextStep
    case previousStep
    case goToStep(Step)

    case validateCurrentStep
    case validationSucceeded
    case validationFailed([String])

    case submit
    case submitSucceeded
    case submitFailed(Error)

    case saveDraft
    case restoreDraft
  }

  // MARK: - Action Handler

  // swiftlint:disable cyclomatic_complexity function_body_length
  func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { [validator, apiClient] action, state in
      switch action {
      // MARK: - Data Updates

      case .updatePersonalInfo(let info):
        state.personalInfo = info
        state.personalInfoErrors = []
        return .none

      case .updateAddressInfo(let info):
        state.addressInfo = info
        state.addressInfoErrors = []
        return .none

      case .updatePaymentInfo(let info):
        state.paymentInfo = info
        state.paymentInfoErrors = []
        return .none

      // MARK: - Navigation

      case .nextStep:
        // Validate current step before proceeding
        return .run { state in
          state.isValidating = true

          let errors = validateStep(state.currentStep, state: state)

          if errors.isEmpty {
            // Mark step as completed
            state.completedSteps.insert(state.currentStep)

            // Move to next step
            if let nextStep = state.currentStep.next {
              state.currentStep = nextStep
            }

            state.isValidating = false
          } else {
            // Show validation errors
            setErrorsForStep(state.currentStep, errors: errors, state: state)
            state.isValidating = false
          }
        }

      case .previousStep:
        if let prevStep = state.currentStep.previous {
          state.currentStep = prevStep
        }
        return .none

      case .goToStep(let step):
        // Can only go to completed steps or the next step
        if state.completedSteps.contains(step) || step == state.currentStep.next {
          state.currentStep = step
        }
        return .none

      // MARK: - Validation

      case .validateCurrentStep:
        state.isValidating = true

        return .run { state in
          let errors = validateStep(state.currentStep, state: state)

          if errors.isEmpty {
            state.completedSteps.insert(state.currentStep)
          } else {
            setErrorsForStep(state.currentStep, errors: errors, state: state)
          }

          state.isValidating = false
        }

      case .validationSucceeded:
        state.isValidating = false
        return .none

      case .validationFailed(let errors):
        setErrorsForStep(state.currentStep, errors: errors, state: state)
        state.isValidating = false
        return .none

      // MARK: - Submission

      case .submit:
        // Validate all steps
        let allErrors = Step.allCases.flatMap { step in
          validateStep(step, state: state)
        }

        guard allErrors.isEmpty else {
          state.error = .validationFailed(
            reason: "Please complete all required fields",
            suggestion: "Review each step and fix validation errors"
          )
          return .none
        }

        state.isSubmitting = true
        state.error = nil

        return .run { state in
          do {
            try await apiClient.submit(
              personalInfo: state.personalInfo,
              addressInfo: state.addressInfo,
              paymentInfo: state.paymentInfo
            )

            state.isSubmitting = false
            // Reset wizard after successful submission
            resetWizard(state: state)
          } catch {
            throw WizardError.submissionFailed(underlying: error)
          }
        }
        .catch { error, state in
          state.isSubmitting = false
          if let wizardError = error as? WizardError {
            state.error = wizardError
          } else {
            state.error = .submissionFailed(underlying: error)
          }
        }

      case .submitSucceeded:
        state.isSubmitting = false
        resetWizard(state: state)
        return .none

      case .submitFailed(let error):
        state.isSubmitting = false
        state.error = .networkError(underlying: error)
        return .none

      // MARK: - Draft Management

      case .saveDraft:
        return .run { state in
          // Save to UserDefaults or file system
          let draft = WizardDraft(
            personalInfo: state.personalInfo,
            addressInfo: state.addressInfo,
            paymentInfo: state.paymentInfo,
            currentStep: state.currentStep
          )

          // Save draft (simplified for example)
          print("Draft saved: \(draft)")
        }

      case .restoreDraft:
        return .run { _ in
          // Load from UserDefaults or file system
          // For now, just a placeholder
          print("Draft restored")
        }
      }
    }
  }
  // swiftlint:enable cyclomatic_complexity function_body_length

  // MARK: - Helper Functions

  private func validateStep(_ step: Step, state: State) -> [String] {
    switch step {
    case .personalInfo:
      return validator.validatePersonalInfo(state.personalInfo)
    case .addressInfo:
      return validator.validateAddressInfo(state.addressInfo)
    case .paymentInfo:
      return validator.validatePaymentInfo(state.paymentInfo)
    case .review:
      return []  // Review step has no validation
    }
  }

  private func setErrorsForStep(_ step: Step, errors: [String], state: State) {
    switch step {
    case .personalInfo:
      state.personalInfoErrors = errors
    case .addressInfo:
      state.addressInfoErrors = errors
    case .paymentInfo:
      state.paymentInfoErrors = errors
    case .review:
      break
    }
  }

  private func resetWizard(state: State) {
    state.currentStep = .personalInfo
    state.personalInfo = PersonalInfo()
    state.addressInfo = AddressInfo()
    state.paymentInfo = PaymentInfo()
    state.completedSteps = []
    state.personalInfoErrors = []
    state.addressInfoErrors = []
    state.paymentInfoErrors = []
  }
}

// MARK: - Form Data Types

struct PersonalInfo: Sendable {
  var firstName = ""
  var lastName = ""
  var email = ""
  var phone = ""
}

struct AddressInfo: Sendable {
  var street = ""
  var city = ""
  var state = ""
  var zipCode = ""
  var country = ""
}

struct PaymentInfo: Sendable {
  var cardNumber = ""
  var expiryDate = ""
  var cvv = ""
  var nameOnCard = ""
}

struct WizardDraft: Codable {
  let personalInfo: PersonalInfo
  let addressInfo: AddressInfo
  let paymentInfo: PaymentInfo
  let currentStep: MultiStepWizardFeature.Step
}

extension PersonalInfo: Codable {}
extension AddressInfo: Codable {}
extension PaymentInfo: Codable {}
extension MultiStepWizardFeature.Step: Codable {}

// MARK: - Validation

protocol FormValidator: Sendable {
  func validatePersonalInfo(_ info: PersonalInfo) -> [String]
  func validateAddressInfo(_ info: AddressInfo) -> [String]
  func validatePaymentInfo(_ info: PaymentInfo) -> [String]
}

struct DefaultFormValidator: FormValidator {
  func validatePersonalInfo(_ info: PersonalInfo) -> [String] {
    var errors: [String] = []

    if info.firstName.isEmpty {
      errors.append("First name is required")
    }

    if info.lastName.isEmpty {
      errors.append("Last name is required")
    }

    if info.email.isEmpty {
      errors.append("Email is required")
    } else if !info.email.contains("@") {
      errors.append("Email must be valid")
    }

    if info.phone.isEmpty {
      errors.append("Phone number is required")
    }

    return errors
  }

  func validateAddressInfo(_ info: AddressInfo) -> [String] {
    var errors: [String] = []

    if info.street.isEmpty {
      errors.append("Street address is required")
    }

    if info.city.isEmpty {
      errors.append("City is required")
    }

    if info.state.isEmpty {
      errors.append("State is required")
    }

    if info.zipCode.isEmpty {
      errors.append("ZIP code is required")
    }

    if info.country.isEmpty {
      errors.append("Country is required")
    }

    return errors
  }

  func validatePaymentInfo(_ info: PaymentInfo) -> [String] {
    var errors: [String] = []

    if info.cardNumber.isEmpty {
      errors.append("Card number is required")
    } else if info.cardNumber.count < 13 {
      errors.append("Card number must be at least 13 digits")
    }

    if info.expiryDate.isEmpty {
      errors.append("Expiry date is required")
    }

    if info.cvv.isEmpty {
      errors.append("CVV is required")
    } else if info.cvv.count < 3 {
      errors.append("CVV must be at least 3 digits")
    }

    if info.nameOnCard.isEmpty {
      errors.append("Name on card is required")
    }

    return errors
  }
}

// MARK: - API Client

protocol SubmissionAPIClient: Sendable {
  func submit(
    personalInfo: PersonalInfo,
    addressInfo: AddressInfo,
    paymentInfo: PaymentInfo
  ) async throws
}

struct MockSubmissionAPIClient: SubmissionAPIClient {
  func submit(
    personalInfo: PersonalInfo,
    addressInfo: AddressInfo,
    paymentInfo: PaymentInfo
  ) async throws {
    // Simulate network delay
    try await Task.sleep(for: .seconds(1))

    print("Submitted:")
    print("  Name: \(personalInfo.firstName) \(personalInfo.lastName)")
    print("  Email: \(personalInfo.email)")
    print("  Address: \(addressInfo.street), \(addressInfo.city)")
  }
}
