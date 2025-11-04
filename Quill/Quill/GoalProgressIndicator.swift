import SwiftUI
import SwiftData

/// Circular progress indicator for writing goals in the toolbar
struct GoalProgressIndicator: View {
    let progress: Double // 0.0 to 1.0
    let isComplete: Bool

    var body: some View {
        ZStack {
            // Invisible fill to make entire circle clickable
            Circle()
                .fill(Color.clear)
                .frame(width: 16, height: 16)

            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                .frame(width: 16, height: 16)

            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isComplete ? Color.green : Color.gray,
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Center checkmark (shows when complete)
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

/// Interactive goal progress button for the toolbar
struct GoalProgressButton: View {
    @Query(sort: \WritingSession.date, order: .reverse) private var sessions: [WritingSession]
    @AppStorage("writingGoalTarget") private var writingGoalTarget = 500
    @AppStorage("writingGoalPeriod") private var writingGoalPeriod = "daily"
    @Environment(\.scenePhase) private var scenePhase

    @Binding var showGoalProgress: Bool
    @State private var displayProgress: Double = 0.0
    @State private var displayWordCount: Int = 0
    @State private var currentDay: Date = Calendar.current.startOfDay(for: Date())

    private let goalManager = WritingGoalManager.shared

    var body: some View {
        Button(action: {
            showGoalProgress.toggle()
        }) {
            GoalProgressIndicator(
                progress: displayProgress,
                isComplete: displayWordCount >= writingGoalTarget
            )
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Writing Goal: \(displayWordCount)/\(writingGoalTarget) words")
        .task(id: sessions.count) {
            // Update whenever sessions array changes (items added/removed)
            updateProgress()
        }
        .task(id: sessions.first?.wordsWritten) {
            // Update whenever the most recent session's word count changes
            updateProgress()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Check for day changes when app becomes active
            if newPhase == .active {
                let today = Calendar.current.startOfDay(for: Date())
                if today != currentDay {
                    currentDay = today
                    updateProgress()
                }
            }
        }
        .onChange(of: writingGoalTarget) { _, _ in
            updateProgress()
        }
        .onChange(of: writingGoalPeriod) { _, _ in
            updateProgress()
        }
        .onAppear {
            updateProgress()
        }
    }

    private func updateProgress() {
        goalManager.targetWordCount = writingGoalTarget
        goalManager.goalPeriod = writingGoalPeriod == "daily" ? .daily : .weekly
        displayWordCount = goalManager.getCurrentProgress(sessions: sessions)

        if writingGoalTarget > 0 {
            displayProgress = min(Double(displayWordCount) / Double(writingGoalTarget), 1.0)
        } else {
            displayProgress = 0.0
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GoalProgressIndicator(progress: 0.0, isComplete: false)
        GoalProgressIndicator(progress: 0.3, isComplete: false)
        GoalProgressIndicator(progress: 0.7, isComplete: false)
        GoalProgressIndicator(progress: 1.0, isComplete: true)
    }
    .padding()
}
