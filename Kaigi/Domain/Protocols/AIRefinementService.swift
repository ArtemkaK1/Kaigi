import Foundation

nonisolated enum RefinementAction: Equatable, Sendable {
    case cleanUp, structure
    var feature: AppFeature { self == .cleanUp ? .aiCleanUp : .aiStructure }
}
struct RefinementResult: Sendable { let text: String }
@MainActor protocol AIRefinementService {
    var unavailableReason: String? { get }

    func refine(_ text: String, action: RefinementAction) async throws -> RefinementResult
}
struct RefinementFailure: LocalizedError { let message: String; var errorDescription: String? { message } }
