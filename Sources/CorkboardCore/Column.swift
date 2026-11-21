import Foundation

public enum Column: String, CaseIterable, Identifiable, Hashable, Sendable {
    case backlog
    case todo
    case inProgress = "in-progress"
    case done

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .backlog: "Backlog"
        case .todo: "To Do"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }

    /// Written into a new ticket's `**Status**:` line. Existing files are not rewritten on move.
    public var statusLabel: String {
        switch self {
        case .backlog: "Backlog"
        case .todo: "Todo"
        case .inProgress: "In progress"
        case .done: "Done"
        }
    }

    /// Fixed, slight crook so each strip of tape looks stuck on by hand.
    public var tapeTilt: Double {
        switch self {
        case .backlog: -1.1
        case .todo: 0.7
        case .inProgress: -0.4
        case .done: 0.9
        }
    }
}
