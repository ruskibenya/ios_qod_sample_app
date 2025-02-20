import Foundation

struct VideoStats {
    let timestamp: TimeInterval
    let videoBitrateKbps: Double
    let packetLossRatio: Double
    let qodEnabled: Bool
}

class VideoResultSet {
    var testName: String
    var qualityStats: [VideoStats]
    
    init(testName: String) {
        self.testName = testName
        self.qualityStats = []
    }
}
