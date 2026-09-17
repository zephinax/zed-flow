import Foundation

@MainActor
public final class JobScheduler {
    public typealias TriggerHandler = (Script) -> Void
    public typealias RunningCheckHandler = (Script) -> Bool

    public var onTrigger: TriggerHandler?
    public var isRunningCheck: RunningCheckHandler?

    private var scheduledTasks: [UUID: Task<Void, Never>] = [:]
    private var scheduledDates: [UUID: Date] = [:]
    private var anchorDates: [UUID: Date] = [:]
    private var trackedScripts: [UUID: Script] = [:]

    public init(
        onTrigger: TriggerHandler? = nil,
        isRunningCheck: RunningCheckHandler? = nil
    ) {
        self.onTrigger = onTrigger
        self.isRunningCheck = isRunningCheck
    }

    deinit {
        for task in scheduledTasks.values {
            task.cancel()
        }
    }

    // MARK: - Scheduling Operations

    public func nextScheduledDate(for scriptId: UUID) -> Date? {
        scheduledDates[scriptId]
    }

    public func isScheduled(scriptId: UUID) -> Bool {
        scheduledTasks[scriptId] != nil && scheduledDates[scriptId] != nil
    }

    public func schedule(script: Script, baseDate: Date? = nil) {
        cancel(scriptId: script.id)

        guard script.isEnabled else {
            trackedScripts.removeValue(forKey: script.id)
            return
        }

        guard script.schedule != .manual else {
            trackedScripts.removeValue(forKey: script.id)
            return
        }

        trackedScripts[script.id] = script

        let anchor = baseDate ?? anchorDates[script.id]
        guard let targetDate = script.schedule.nextExecutionDate(after: Date(), baseDate: anchor) else {
            return
        }

        scheduledDates[script.id] = targetDate
        if anchorDates[script.id] == nil {
            anchorDates[script.id] = targetDate
        }

        let delay = max(0, targetDate.timeIntervalSinceNow)
        let nanoseconds = UInt64(delay * 1_000_000_000)

        scheduledTasks[script.id] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return // Task cancelled
            }

            guard let self = self else { return }
            guard !Task.isCancelled else { return }
            guard let currentScript = self.trackedScripts[script.id], currentScript.isEnabled else { return }

            // Prevent concurrent execution of the same script
            let isRunning = self.isRunningCheck?(currentScript) ?? false
            if !isRunning {
                self.onTrigger?(currentScript)
            }

            // Schedule the next recurrence anchoring to the targetDate to prevent drift
            self.schedule(script: currentScript, baseDate: targetDate)
        }
    }

    public func cancel(scriptId: UUID) {
        scheduledTasks[scriptId]?.cancel()
        scheduledTasks.removeValue(forKey: scriptId)
        scheduledDates.removeValue(forKey: scriptId)
        anchorDates.removeValue(forKey: scriptId)
    }

    public func cancelAll() {
        for task in scheduledTasks.values {
            task.cancel()
        }
        scheduledTasks.removeAll()
        scheduledDates.removeAll()
        anchorDates.removeAll()
        trackedScripts.removeAll()
    }

    public func reconcile(scripts: [Script]) {
        let activeIds = Set(scripts.map(\.id))

        // Cancel scripts that were removed
        for id in scheduledTasks.keys where !activeIds.contains(id) {
            cancel(scriptId: id)
            trackedScripts.removeValue(forKey: id)
        }

        // Update or add schedules
        for script in scripts {
            let previous = trackedScripts[script.id]
            trackedScripts[script.id] = script

            if !script.isEnabled || script.schedule == .manual {
                cancel(scriptId: script.id)
            } else if previous == nil || previous?.schedule != script.schedule || previous?.isEnabled != script.isEnabled {
                schedule(script: script)
            }
        }
    }

    /// Recalculates upcoming executions after system sleep/wake to prevent backlog storms.
    public func handleSystemWake() {
        let scripts = Array(trackedScripts.values)
        for script in scripts {
            schedule(script: script)
        }
    }
}
