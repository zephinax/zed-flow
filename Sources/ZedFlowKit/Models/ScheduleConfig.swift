import Foundation

public enum ScheduleConfig: Codable, Hashable, Sendable {
    case manual
    case interval(minutes: Int)
    case daily(hour: Int, minute: Int)

    public var displayTitle: String {
        switch self {
        case .manual:
            return "Manual"
        case .interval(let minutes):
            if minutes < 60 {
                return "Every \(minutes)m"
            } else if minutes % 60 == 0 {
                let hours = minutes / 60
                return hours == 1 ? "Every 1 hour" : "Every \(hours) hours"
            } else {
                let hours = minutes / 60
                let rem = minutes % 60
                return "Every \(hours)h \(rem)m"
            }
        case .daily(let hour, let minute):
            return String(format: "Daily at %02d:%02d", hour, minute)
        }
    }
}
