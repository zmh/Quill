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
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isEnabled ? 
                (configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.1)) :
                Color.gray.opacity(0.1)
            )
            .foregroundColor(isEnabled ? .accentColor : .gray)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
    }
}