import Foundation

struct Bar {
    let angle: CGFloat      // radians
    let innerR: CGFloat     // 0...1
    let outerR: CGFloat     // 0...1
    let opacity: CGFloat    // 0...1
    let thickness: CGFloat  // 0...1
}

enum MonitorState: String, Codable {
    case sleeping, working, idle, waiting

    var priority: Int {
        switch self {
        case .waiting: return 3
        case .working: return 2
        case .idle:    return 1
        case .sleeping: return 0
        }
    }

    var fps: Double {
        switch self {
        case .working, .waiting: return 30
        case .sleeping, .idle: return 20
        }
    }
}
