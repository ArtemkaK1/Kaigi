import Foundation

@MainActor enum AIServiceFactory {
    static func make() -> any AIRefinementService {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) { return FoundationModelsRefinementService() }
        #endif
        return UnavailableAIService()
    }
}
