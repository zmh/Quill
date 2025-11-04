//
//  FontLoader.swift
//  Quill
//
//  Loads custom fonts for the application
//

import Foundation
import AppKit

class FontLoader {
    static let shared = FontLoader()

    private init() {}

    func loadFonts() {
        let fontNames = [
            "iAWriterMonoS-Regular.ttf",
            "iAWriterMonoS-Bold.ttf",
            "iAWriterMonoS-Italic.ttf",
            "iAWriterMonoS-BoldItalic.ttf",
            "iAWriterDuoS-Regular.ttf",
            "iAWriterDuoS-Bold.ttf",
            "iAWriterDuoS-Italic.ttf",
            "iAWriterDuoS-BoldItalic.ttf",
            "iAWriterQuattroS-Regular.ttf",
            "iAWriterQuattroS-Bold.ttf",
            "iAWriterQuattroS-Italic.ttf",
            "iAWriterQuattroS-BoldItalic.ttf"
        ]

        for fontName in fontNames {
            if let fontURL = Bundle.main.url(forResource: fontName.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf") {
                registerFont(from: fontURL, name: fontName)
            } else {
                print("❌ Could not find font file: \(fontName)")
            }
        }

        // List available fonts after registration
        listAvailableFonts()
    }

    private func registerFont(from url: URL, name: String) {
        var error: Unmanaged<CFError>?

        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            print("❌ Failed to register font \(name): \(error.debugDescription)")
            return
        }

        print("✅ Successfully registered font: \(name)")

        // Get and print the actual font name from the file
        if let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] {
            for descriptor in fontDescriptors {
                if let familyName = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String,
                   let postScriptName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String {
                    print("   → Family: '\(familyName)' | PostScript: '\(postScriptName)'")
                }
            }
        }
    }

    func listAvailableFonts() {
        let fontFamilies = NSFontManager.shared.availableFontFamilies
        print("\n📝 Available font families containing 'iA':")
        for family in fontFamilies {
            if family.localizedCaseInsensitiveContains("ia") {
                print("  - \(family)")
            }
        }
        print("\n")
    }
}
