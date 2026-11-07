import FirebaseCore
import Foundation
import Testing
@testable import Meetrail

@MainActor struct CrashlyticsTests {
    @Test func linkedCrashlyticsDoesNotInitializeInXCTest() {
        // +load registers the eager component; only configure creates the reporter.
        #expect(NSClassFromString("FIRCrashlytics") != nil)
        #expect(FirebaseApp.app() == nil)
        for arguments in [[], ["--sample"], ["--marketing-fixtures"], ["--all-features"], ["--test-session", "synthetic"]] {
            #expect(!AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: arguments, isTesting: true))
        }
    }

    @Test func generatedInfoAndLocalConfigurationRemainCorrect() throws {
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSApplicationCrashOnExceptions") as? Bool == true)
        for key in ["FirebaseAppDelegateProxyEnabled", "FirebaseAutomaticScreenReportingEnabled", "GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED", "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS"] {
            #expect(Bundle.main.object(forInfoDictionaryKey: key) as? Bool == false)
        }
        let resource = try #require(Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"))
        let values = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: resource), format: nil) as? [String: Any])
        #expect(values["BUNDLE_ID"] as? String == "com.volrik.kaigi")
    }

    @Test func normalAndSyntheticLaunchPolicyIsUnchanged() {
        #expect(AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: [], isTesting: false))
        for flag in ["--sample", "--marketing-fixtures", "--all-features", "--test-session"] {
            #expect(!AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: [flag], isTesting: false))
        }
        #expect(FeatureToggles.forLaunch(arguments: []) == .appStoreFree)
    }
}
