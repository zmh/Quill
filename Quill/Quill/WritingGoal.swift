import Foundation
import SwiftData

// MARK: - Goal Period

enum GoalPeriod: String, Codable {
    case daily
    case weekly
}

// MARK: - Writing Session

@Model
final class WritingSession {
    var id: UUID
    var date: Date
    var wordsWritten: Int
    var createdDate: Date
    var modifiedDate: Date

    init(date: Date = Date(), wordsWritten: Int = 0) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.wordsWritten = wordsWritten
        self.createdDate = Date()
        self.modifiedDate = Date()
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Writing Goal Manager

@Observable
class WritingGoalManager {
    static let shared = WritingGoalManager()

    // Goal settings (persisted via AppStorage in SettingsView)
    var targetWordCount: Int = 500
    var goalPeriod: GoalPeriod = .daily

    private init() {}

    // MARK: - Goal Progress

    func getTodayProgress(sessions: [WritingSession]) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.wordsWritten }
    }

    func getWeekProgress(sessions: [WritingSession]) -> Int {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return 0
        }
        return sessions
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.wordsWritten }
    }

    func getCurrentProgress(sessions: [WritingSession]) -> Int {
        switch goalPeriod {
        case .daily:
            return getTodayProgress(sessions: sessions)
        case .weekly:
            return getWeekProgress(sessions: sessions)
        }
    }

    func getGoalCompletionPercentage(sessions: [WritingSession]) -> Double {
        let progress = getCurrentProgress(sessions: sessions)
        guard targetWordCount > 0 else { return 0 }
        return min(Double(progress) / Double(targetWordCount), 1.0)
    }

    func hasMetGoal(sessions: [WritingSession]) -> Bool {
        getCurrentProgress(sessions: sessions) >= targetWordCount
    }

    // MARK: - Streak Calculation

    func getCurrentStreak(sessions: [WritingSession]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Group sessions by date and calculate daily totals
        let dailyTotals = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.date)
        }.mapValues { daySessions in
            daySessions.reduce(0) { $0 + $1.wordsWritten }
        }

        var streak = 0
        var currentDate = today

        // Count backwards from today
        while true {
            if let wordsWritten = dailyTotals[currentDate],
               wordsWritten >= targetWordCount {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                    break
                }
                currentDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Session Management

    func recordWords(_ wordCount: Int, on date: Date = Date(), sessions: [WritingSession], modelContext: ModelContext) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Find or create session for today
        if let existingSession = sessions.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
            existingSession.wordsWritten = wordCount
            existingSession.modifiedDate = Date()
        } else {
            let newSession = WritingSession(date: dayStart, wordsWritten: wordCount)
            modelContext.insert(newSession)
        }

        try? modelContext.save()
    }

    // MARK: - History & Statistics

    func getRecentSessions(sessions: [WritingSession], days: Int = 7) -> [WritingSession] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        return sessions
            .filter { $0.date >= startDate }
            .sorted { $0.date > $1.date }
    }

    func getWeeklyHistory(sessions: [WritingSession], weeks: Int = 4) -> [(week: Date, total: Int)] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) else {
            return []
        }

        // Group by week
        let weeklyTotals = Dictionary(grouping: sessions.filter { $0.date >= startDate }) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
        }.mapValues { weekSessions in
            weekSessions.reduce(0) { $0 + $1.wordsWritten }
        }

        return weeklyTotals
            .map { (week: $0.key, total: $0.value) }
            .sorted { $0.week > $1.week }
    }
}
