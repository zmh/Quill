//
//  Theme.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

extension View {
    func quillSidebar() -> some View {
        self
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
    }
    
    func quillEditor() -> some View {
        self
            .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
            #if os(macOS)
            .background(Color(NSColor.textBackgroundColor))
            #else
            .background(Color(UIColor.systemBackground))
            #endif
    }
}

struct QuillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isEnabled ? 
                        (configuration.isPressed ? buttonBackgroundColor.opacity(0.3) : buttonBackgroundColor) :
                        Color.gray.opacity(0.1)
                    )
            )
            .foregroundColor(isEnabled ? buttonTextColor : Color.gray.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isEnabled ? buttonTextColor.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var buttonBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.accentColor.opacity(0.25)
        } else {
            return Color.accentColor.opacity(0.15)
        }
    }
    
    private var buttonTextColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.4, green: 0.7, blue: 1.0) // Brighter blue for dark mode
        } else {
            return Color.accentColor
        }
    }
}