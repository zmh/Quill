import SwiftUI
import SwiftData

struct GoalProgressPopover: View {
    @Query(sort: \WritingSession.date, order: .reverse) private var sessions: [WritingSession]
    @AppStorage("writingGoalTarget") private var writingGoalTarget = 500
    @AppStorage("writingGoalPeriod") private var writingGoalPeriod = "daily"

    @State private var selectedTab = "goal"

    private let goalManager = WritingGoalManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Tab header
            HStack(spacing: 20) {
                TabHeaderButton(title: "Goal", isSelected: selectedTab == "goal") {
                    selectedTab = "goal"
                }
                TabHeaderButton(title: "History", isSelected: selectedTab == "history") {
                    selectedTab = "history"
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == "goal" {
                        GoalView(
                            sessions: sessions,
                            targetWords: writingGoalTarget,
                            goalPeriod: writingGoalPeriod,
                            goalManager: goalManager
                        )
                    } else {
                        HistoryView(
                            sessions: sessions,
                            goalManager: goalManager
                        )
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 320, height: 340)
    }
}

// MARK: - Tab Header Button

struct TabHeaderButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Goal View

struct GoalView: View {
    let sessions: [WritingSession]
    let targetWords: Int
    let goalPeriod: String
    let goalManager: WritingGoalManager

    private var currentProgress: Int {
        goalManager.targetWordCount = targetWords
        goalManager.goalPeriod = goalPeriod == "daily" ? .daily : .weekly
        return goalManager.getCurrentProgress(sessions: sessions)
    }

    private var progressPercentage: Double {
        goalManager.targetWordCount = targetWords
        goalManager.goalPeriod = goalPeriod == "daily" ? .daily : .weekly
        return goalManager.getGoalCompletionPercentage(sessions: sessions)
    }

    private var currentStreak: Int {
        goalManager.targetWordCount = targetWords
        return goalManager.getCurrentStreak(sessions: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Progress circle
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: progressPercentage)
                        .stroke(
                            progressPercentage >= 1.0 ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progressPercentage)

                    VStack(spacing: 4) {
                        Text("\(currentProgress)")
                            .font(.system(size: 32, weight: .bold))
                        Text("of \(targetWords)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("words")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            // Stats
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(goalPeriod == "daily" ? "Today" : "This Week")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(currentProgress) words")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("Goal")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(targetWords) words per \(goalPeriod == "daily" ? "day" : "week")")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }

                HStack {
                    Text("Current Streak")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        if currentStreak > 0 {
                            Text("🔥")
                                .font(.system(size: 14))
                        }
                        Text(currentStreak > 0 ? "\(currentStreak) \(currentStreak == 1 ? "day" : "days")" : "No streak yet")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

// MARK: - History View

struct HistoryView: View {
    let sessions: [WritingSession]
    let goalManager: WritingGoalManager

    private var recentSessions: [WritingSession] {
        goalManager.getRecentSessions(sessions: sessions, days: 7)
    }

    private var maxWords: Int {
        recentSessions.map(\.wordsWritten).max() ?? 500
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Bar chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Last 7 Days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { dayOffset in
                        let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
                        let session = recentSessions.first { Calendar.current.isDate($0.date, inSameDayAs: date) }

                        VStack(spacing: 4) {
                            // Bar
                            Rectangle()
                                .fill(session != nil ? Color.blue.opacity(0.8) : Color.gray.opacity(0.2))
                                .frame(width: 32, height: max(4, CGFloat(session?.wordsWritten ?? 0) / CGFloat(max(maxWords, 1)) * 100))
                                .cornerRadius(4)
                                .rotationEffect(.degrees(180))
                                .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))

                            // Day label
                            Text(dayLabel(for: date))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 120)
            }

            Divider()

            // Recent sessions list
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Sessions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                if recentSessions.isEmpty {
                    Text("No writing sessions yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(recentSessions.prefix(5)) { session in
                        HStack {
                            Text(relativeDateString(for: session.date))
                                .font(.system(size: 14))
                            Spacer()
                            Text("\(session.wordsWritten) words")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).prefix(1).uppercased()
    }

    private func relativeDateString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    GoalProgressPopover()
        .modelContainer(for: [WritingSession.self], inMemory: true)
}
