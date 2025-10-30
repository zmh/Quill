//
//  TextStatisticsPopover.swift
//  Quill
//
//  Created by Claude on 10/30/25.
//

import SwiftUI

/// Popover view displaying comprehensive text statistics
struct TextStatisticsPopover: View {
    let statistics: TextStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main statistics section
            VStack(alignment: .leading, spacing: 12) {
                StatRow(label: "Characters", value: "\(statistics.characters)")
                StatRow(label: "Without Spaces", value: "\(statistics.charactersWithoutSpaces)")
                StatRow(label: "Words", value: "\(statistics.words)")
                StatRow(label: "Sentences", value: "\(statistics.sentences)")
                StatRow(label: "Words/Sentence", value: "\(statistics.wordsPerSentence)")
                StatRow(label: "Paragraphs", value: "\(statistics.paragraphs)")
                StatRow(label: "Lines", value: "\(statistics.lines)")
                StatRow(label: "Pages", value: statistics.formattedPages)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Divider
            Divider()
                .padding(.horizontal, 20)

            // Reading times section
            VStack(alignment: .leading, spacing: 12) {
                StatRow(label: "Slow", value: statistics.formatReadingTime(statistics.slowReadingTime))
                StatRow(label: "Average", value: statistics.formatReadingTime(statistics.averageReadingTime))
                StatRow(label: "Fast", value: statistics.formatReadingTime(statistics.fastReadingTime))
                StatRow(label: "Aloud", value: statistics.formatReadingTime(statistics.aloudReadingTime))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 280)
    }
}

/// Individual statistic row with label and value
private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Preview

struct TextStatisticsPopover_Previews: PreviewProvider {
    static var previews: some View {
        let sampleHTML = """
        <p>This is a sample paragraph with some content.</p>
        <p>Here's another paragraph to test the statistics calculator.</p>
        <p>The quick brown fox jumps over the lazy dog. This sentence is here to demonstrate multiple sentences.</p>
        """

        let stats = TextStatisticsCalculator.calculate(from: sampleHTML)

        return TextStatisticsPopover(statistics: stats)
            .previewLayout(.sizeThatFits)
    }
}
