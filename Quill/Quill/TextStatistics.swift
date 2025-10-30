//
//  TextStatistics.swift
//  Quill
//
//  Created by Claude on 10/30/25.
//

import Foundation

/// Comprehensive text statistics including character, word, sentence, paragraph counts and reading times
struct TextStatistics {
    let characters: Int
    let charactersWithoutSpaces: Int
    let words: Int
    let sentences: Int
    let wordsPerSentence: Int
    let paragraphs: Int
    let lines: Int
    let pages: Double

    // Reading times in seconds
    let slowReadingTime: Int
    let averageReadingTime: Int
    let fastReadingTime: Int
    let aloudReadingTime: Int

    static let zero = TextStatistics(
        characters: 0,
        charactersWithoutSpaces: 0,
        words: 0,
        sentences: 0,
        wordsPerSentence: 0,
        paragraphs: 0,
        lines: 0,
        pages: 0.0,
        slowReadingTime: 0,
        averageReadingTime: 0,
        fastReadingTime: 0,
        aloudReadingTime: 0
    )
}

/// Calculator for computing text statistics from HTML content
struct TextStatisticsCalculator {

    // Reading speeds in words per minute
    private static let slowReadingSpeed = 100
    private static let averageReadingSpeed = 200
    private static let fastReadingSpeed = 300
    private static let aloudReadingSpeed = 150

    // Pages calculation (assumes ~250 words per page)
    private static let wordsPerPage = 250.0

    /// Calculate comprehensive statistics from HTML content
    static func calculate(from htmlContent: String) -> TextStatistics {
        // Convert HTML to plain text
        let plainText = HTMLHandler.shared.htmlToPlainText(htmlContent)

        // Character counts
        let characters = plainText.count
        let charactersWithoutSpaces = plainText.filter { !$0.isWhitespace }.count

        // Word count
        let words = plainText.split(whereSeparator: \.isWhitespace).count

        // Sentence count (count periods, exclamation marks, and question marks)
        let sentences = countSentences(in: plainText)

        // Words per sentence
        let wordsPerSentence = sentences > 0 ? words / sentences : 0

        // Paragraph count (count double newlines or <p> tags in HTML)
        let paragraphs = countParagraphs(in: htmlContent)

        // Line count (count newlines in plain text)
        let lines = countLines(in: plainText)

        // Pages (250 words per page)
        let pages = Double(words) / wordsPerPage

        // Reading times (in seconds)
        let slowReadingTime = calculateReadingTime(words: words, wordsPerMinute: slowReadingSpeed)
        let averageReadingTime = calculateReadingTime(words: words, wordsPerMinute: averageReadingSpeed)
        let fastReadingTime = calculateReadingTime(words: words, wordsPerMinute: fastReadingSpeed)
        let aloudReadingTime = calculateReadingTime(words: words, wordsPerMinute: aloudReadingSpeed)

        return TextStatistics(
            characters: characters,
            charactersWithoutSpaces: charactersWithoutSpaces,
            words: words,
            sentences: sentences,
            wordsPerSentence: wordsPerSentence,
            paragraphs: paragraphs,
            lines: lines,
            pages: pages,
            slowReadingTime: slowReadingTime,
            averageReadingTime: averageReadingTime,
            fastReadingTime: fastReadingTime,
            aloudReadingTime: aloudReadingTime
        )
    }

    /// Count sentences by detecting sentence-ending punctuation
    private static func countSentences(in text: String) -> Int {
        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        var count = 0
        var previousWasEnding = false

        for char in text {
            if let scalar = char.unicodeScalars.first, sentenceEndings.contains(scalar) {
                if !previousWasEnding {
                    count += 1
                    previousWasEnding = true
                }
            } else if !char.isWhitespace {
                previousWasEnding = false
            }
        }

        // If text doesn't end with punctuation but has content, count it as a sentence
        if !text.isEmpty && !previousWasEnding && text.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
            count += 1
        }

        return max(count, 0)
    }

    /// Count paragraphs based on HTML structure
    private static func countParagraphs(in html: String) -> Int {
        // Count paragraph tags
        let pTagPattern = "</?p[^>]*>"
        let regex = try? NSRegularExpression(pattern: pTagPattern, options: .caseInsensitive)
        let matches = regex?.matches(in: html, range: NSRange(html.startIndex..., in: html))

        // Each opening <p> tag represents a paragraph
        let pCount = (matches?.count ?? 0) / 2 // Divide by 2 since we have opening and closing tags

        // If no <p> tags but content exists, count as at least 1 paragraph
        let plainText = HTMLHandler.shared.htmlToPlainText(html).trimmingCharacters(in: .whitespacesAndNewlines)
        return max(pCount, plainText.isEmpty ? 0 : 1)
    }

    /// Count lines based on newline characters
    private static func countLines(in text: String) -> Int {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return 0 }

        let lines = trimmedText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return max(lines.count, 1)
    }

    /// Calculate reading time in seconds based on words per minute
    private static func calculateReadingTime(words: Int, wordsPerMinute: Int) -> Int {
        guard words > 0 else { return 0 }
        let minutes = Double(words) / Double(wordsPerMinute)
        return Int(ceil(minutes * 60)) // Convert to seconds and round up
    }
}

// MARK: - Formatting Extensions

extension TextStatistics {

    /// Format reading time into a human-readable string (e.g., "2 sec", "1 min", "2 min 30 sec")
    func formatReadingTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) sec"
        } else if seconds < 120 {
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "1 min"
            } else {
                return "1 min \(remainingSeconds) sec"
            }
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) min"
            } else {
                return "\(minutes) min \(remainingSeconds) sec"
            }
        }
    }

    /// Format pages count with one decimal place
    var formattedPages: String {
        return String(format: "%.1f", pages)
    }
}
