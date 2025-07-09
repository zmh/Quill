//
//  HTMLHandler.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import Foundation
import SwiftUI

class HTMLHandler {
    static let shared = HTMLHandler()
    
    private init() {}
    
    /// Converts HTML to plain text for editing
    func htmlToPlainText(_ html: String) -> String {
        var text = html
        
        // Convert <br> and <br/> to newlines
        text = text
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
        
        // Convert </p> to double newline
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        
        // Convert </div> to newline
        text = text.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
        
        // Convert list items
        text = text.replacingOccurrences(of: "<li>", with: "• ", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        
        // Strip remaining HTML tags
        let tagPattern = "<[^>]+>"
        text = text.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)
        
        // Decode HTML entities after stripping tags
        text = decodeHTMLEntities(text)
        
        // Clean up extra whitespace
        text = text
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text
    }
    
    /// Converts plain text back to HTML for saving
    func plainTextToHTML(_ text: String) -> String {
        // Escape HTML entities
        var html = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        
        // Convert paragraphs
        let paragraphs = html.components(separatedBy: "\n\n")
        html = paragraphs
            .filter { !$0.isEmpty }
            .map { "<p>\($0.replacingOccurrences(of: "\n", with: "<br>"))</p>" }
            .joined(separator: "\n\n")
        
        return html
    }
    
    /// Creates an attributed string for preview with basic HTML rendering
    func htmlToAttributedString(_ html: String) -> AttributedString {
        // For now, just return plain text as attributed string
        // In the future, we can add proper HTML rendering
        var attributedString = AttributedString(htmlToPlainText(html))
        
        // Set default font
        attributedString.font = .body
        
        return attributedString
    }
    
    /// Normalizes HTML content for consistent hash generation
    func normalizeHTML(_ html: String) -> String {
        var normalized = html
        
        // Remove extra whitespace between tags
        normalized = normalized.replacingOccurrences(of: ">\\s+<", with: "><", options: .regularExpression)
        
        // Normalize whitespace within text content
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Split into lines, trim each line, and rejoin
        let lines = normalized.components(separatedBy: .newlines)
        normalized = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        
        // Trim overall whitespace
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return normalized
    }
    
    /// Decodes HTML entities comprehensively
    private func decodeHTMLEntities(_ text: String) -> String {
        // Try manual decoding first since it's more reliable for plain text
        return decodeHTMLEntitiesManually(text)
    }
    
    /// Manual fallback for HTML entity decoding
    func decodeHTMLEntitiesManually(_ text: String) -> String {
        var result = text
        
        // Named entities
        let namedEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&hellip;": "…",
            "&ndash;": "–",
            "&mdash;": "—",
            "&lsquo;": "'",
            "&rsquo;": "'",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}",
            "&deg;": "°",
            "&plusmn;": "±",
            "&frac12;": "½",
            "&frac14;": "¼",
            "&frac34;": "¾",
            "&acirc;": "â",
            "&ecirc;": "ê",
            "&icirc;": "î",
            "&ocirc;": "ô",
            "&ucirc;": "û",
            "&agrave;": "à",
            "&egrave;": "è",
            "&igrave;": "ì",
            "&ograve;": "ò",
            "&ugrave;": "ù",
            "&aacute;": "á",
            "&eacute;": "é",
            "&iacute;": "í",
            "&oacute;": "ó",
            "&uacute;": "ú",
            "&atilde;": "ã",
            "&ntilde;": "ñ",
            "&otilde;": "õ",
            "&auml;": "ä",
            "&euml;": "ë",
            "&iuml;": "ï",
            "&ouml;": "ö",
            "&uuml;": "ü",
            "&yuml;": "ÿ",
            "&ccedil;": "ç",
            "&aring;": "å",
            "&aelig;": "æ",
            "&oslash;": "ø",
            "&szlig;": "ß"
        ]
        
        // Common numeric entities that we see in the user's examples
        let commonNumericEntities: [String: String] = [
            "&#8217;": "'", // Right single quotation mark
            "&#8216;": "'", // Left single quotation mark
            "&#8220;": "\u{201C}", // Left double quotation mark
            "&#8221;": "\u{201D}", // Right double quotation mark
            "&#8212;": "—", // Em dash
            "&#8211;": "–", // En dash
            "&#8230;": "…", // Horizontal ellipsis
            "&#8482;": "™", // Trade mark sign
            "&#169;": "©",  // Copyright sign
            "&#174;": "®",  // Registered sign
            "&#8594;": "→", // Rightwards arrow
        ]
        
        // Replace named entities
        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Replace common numeric entities
        for (entity, replacement) in commonNumericEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // General numeric entity decoding (&#XXXX; format)
        while let range = result.range(of: #"&#\d+;"#, options: .regularExpression) {
            let entityString = String(result[range])
            let numberString = String(entityString.dropFirst(2).dropLast()) // Remove "&#" and ";"
            
            if let number = Int(numberString), let scalar = UnicodeScalar(number) {
                let replacement = String(Character(scalar))
                result.replaceSubrange(range, with: replacement)
            } else {
                // If conversion fails, break to avoid infinite loop
                break
            }
        }
        
        return result
    }
}

// Preview component for rendered HTML
struct HTMLPreview: View {
    let html: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            Text(HTMLHandler.shared.htmlToAttributedString(html))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: CGFloat.infinity, alignment: .leading)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}