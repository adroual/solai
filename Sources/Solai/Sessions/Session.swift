import Foundation

struct Session: Identifiable {
    let id: String
    var state: MonitorState
    var projectName: String?
    var projectPath: String?
    var pid: Int?
    var lastUpdate: Date
}
