import Foundation

enum RefinementAction: Sendable { case cleanUp, structure }
struct RefinementResult: Sendable { let text: String }
@MainActor protocol AIRefinementService {
    var unavailableReason: String? { get }
    func refine(_ text: String, action: RefinementAction) async throws -> RefinementResult
}
struct RefinementFailure: LocalizedError { let message: String; var errorDescription: String? { message } }
