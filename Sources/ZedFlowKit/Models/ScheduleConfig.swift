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

    /// Calculates the next occurrence strictly after `referenceDate`.
    ///
    /// - Parameters:
    ///   - referenceDate: The baseline date, defaults to current time.
    ///   - baseDate: Optional prior anchor date used to avoid interval schedule drift.
    ///   - calendar: Calendar to use for date components calculations.
    /// - Returns: The calculated future execution `Date`, or `nil` if manual.
    public func nextExecutionDate(
        after referenceDate: Date = Date(),
        baseDate: Date? = nil,
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .manual:
            return nil

        case .interval(let minutes):
            let step = TimeInterval(max(1, minutes) * 60)
            if let base = baseDate {
                if base > referenceDate {
                    return base
                }
                let elapsed = referenceDate.timeIntervalSince(base)
                let stepsPassed = floor(elapsed / step) + 1
                return base.addingTimeInterval(stepsPassed * step)
            }
            return referenceDate.addingTimeInterval(step)

        case .daily(let hour, let minute):
            var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let candidate = calendar.date(from: components) else {
                return nil
            }

            if candidate > referenceDate {
                return candidate
            } else {
                return calendar.date(byAdding: .day, value: 1, to: candidate)
            }
        }
    }
}
