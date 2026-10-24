import Foundation

@MainActor struct UnavailableAIService: AIRefinementService {
    var unavailableReason: String? { "On-device AI requires macOS 26 and an available Apple Intelligence model. Manual notes are always available." }
    func refine(_ text: String, action: RefinementAction) async throws -> RefinementResult { throw RefinementFailure(message: unavailableReason!) }
}
@MainActor struct MockAIRefinementService: AIRefinementService {
    let result: String
    var unavailableReason: String? = nil
    func refine(_ text: String, action: RefinementAction) async throws -> RefinementResult {
        if let unavailableReason { throw RefinementFailure(message: unavailableReason) }
        return RefinementResult(text: result)
    }
}
