//
//  WriterQuoteEmptyStateView.swift
//  Quill
//
//  Created by Claude Code
//

import SwiftUI

struct WriterQuote {
    let quote: String
    let author: String
}

struct WriterQuoteEmptyStateView: View {
    // Collection of inspiring writer and blogger quotes
    private let quotes = [
        WriterQuote(quote: "The first draft is just you telling yourself the story.", author: "Terry Pratchett"),
        WriterQuote(quote: "You can always edit a bad page. You can't edit a blank page.", author: "Jodi Picoult"),
        WriterQuote(quote: "Start writing, no matter what. The water does not flow until the faucet is turned on.", author: "Louis L'Amour"),
        WriterQuote(quote: "There is no greater agony than bearing an untold story inside you.", author: "Maya Angelou"),
        WriterQuote(quote: "If you want to be a writer, you must do two things above all others: read a lot and write a lot.", author: "Stephen King"),
        WriterQuote(quote: "Write what should not be forgotten.", author: "Isabel Allende"),
        WriterQuote(quote: "The scariest moment is always just before you start.", author: "Stephen King"),
        WriterQuote(quote: "One day I will find the right words, and they will be simple.", author: "Jack Kerouac"),
        WriterQuote(quote: "You don't start out writing good stuff. You start out writing crap and thinking it's good stuff, and then gradually you get better at it.", author: "Octavia E. Butler"),
        WriterQuote(quote: "Write the story you need to tell and want to read.", author: "Rainbow Rowell"),
        WriterQuote(quote: "Usage is like oxygen for ideas. You can never fully anticipate how an audience is going to react to something you've created until it's out there.", author: "Matt Mullenweg"),
        WriterQuote(quote: "Technology is best when it brings people together.", author: "Matt Mullenweg"),
        WriterQuote(quote: "The biggest mistake we make is not starting.", author: "Matt Mullenweg"),
        WriterQuote(quote: "If you're not embarrassed when you ship your first version, you waited too long.", author: "Matt Mullenweg"),
        WriterQuote(quote: "What you publish is your resume. Share your work and put it out there.", author: "Matt Mullenweg"),
        WriterQuote(quote: "The best time to plant a tree was 20 years ago. The second best time is now.", author: "Matt Mullenweg"),
        WriterQuote(quote: "Blogging is to writing what extreme sports are to athletics: more free-form, more accident-prone, less formal, more alive.", author: "Andrew Sullivan"),
        WriterQuote(quote: "Don't focus on having a great blog. Focus on producing a blog that's great for your readers.", author: "Brian Clark"),
        WriterQuote(quote: "Write to be understood, speak to be heard, read to grow.", author: "Lawrence Clark Powell"),
        WriterQuote(quote: "The way to get good ideas is to get lots of ideas and throw the bad ones away.", author: "Linus Pauling"),
        WriterQuote(quote: "What you do every day matters more than what you do once in a while.", author: "Gretchen Rubin")
    ]

    @State private var currentQuoteIndex = 0

    var body: some View {
        ZStack {
            // Background with subtle texture
            Color(white: 0.94)

            // Writer quote section - centered
            VStack(spacing: 8) {
                Text("\"\(quotes[currentQuoteIndex].quote)\"")
                    .font(.body)
                    .italic()
                    .foregroundStyle(Color(white: 0.7))
                    .multilineTextAlignment(.center)

                Text("— \(quotes[currentQuoteIndex].author)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(white: 0.7))
            }
            .frame(maxWidth: 400)
            .id(currentQuoteIndex) // For animation when quote changes
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Randomly select a quote on appear
            currentQuoteIndex = Int.random(in: 0..<quotes.count)
        }
    }
}

#Preview {
    WriterQuoteEmptyStateView()
}
