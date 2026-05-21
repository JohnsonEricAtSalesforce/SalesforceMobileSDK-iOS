import Foundation
@testable import SalesforceAnalytics

class AnalyticsTestUtil {

    static func buildTestStoreDirectory() -> String? {
        let directories = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        guard var directory = directories.first else { return nil }
        if let bundleId = Bundle.main.bundleIdentifier {
            directory = (directory as NSString).appendingPathComponent(bundleId)
        }
        directory = (directory as NSString).appendingPathComponent(safeStringForDiskRepresentation("TEST_ORG_ID"))
        directory = (directory as NSString).appendingPathComponent(safeStringForDiskRepresentation("TEST_USER_ID"))
        directory = (directory as NSString).appendingPathComponent(safeStringForDiskRepresentation("TEST_COMMUNITY_ID"))
        return directory
    }

    static func safeStringForDiskRepresentation(_ candidate: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:@")
        return candidate.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
