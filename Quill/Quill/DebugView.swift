//
//  DebugView.swift
//  Quill
//
//  Created by Claude on 7/9/25.
//

import SwiftUI
import SwiftData

struct DebugView: View {
    @ObservedObject private var logger = DebugLogger.shared
    @Query private var siteConfigs: [SiteConfiguration]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Console")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear") {
                    logger.clear()
                }
                .buttonStyle(.borderless)
                
                Button("Export") {
                    let logs = logger.exportLogs()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logs, forType: .string)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Site config info
            if siteConfigs.isEmpty {
                Text("No WordPress site configured")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ForEach(siteConfigs) { config in
                    HStack {
                        Text("Site: \(config.siteURL)")
                        Text("User: \(config.username)")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            // Logs
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logger.logs) { entry in
                            DebugLogRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: logger.logs.count) { _, _ in
                    if let lastLog = logger.logs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

struct DebugLogRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(timeString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 65)
            
            Text(entry.level.rawValue.prefix(4))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(levelColor)
                .frame(width: 35)
            
            if !entry.source.isEmpty {
                Text(entry.source)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(minWidth: 60, maxWidth: 80)
            }
            
            Text(entry.message)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: entry.timestamp)
    }
    
    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    DebugView()
        .modelContainer(for: [SiteConfiguration.self])
}