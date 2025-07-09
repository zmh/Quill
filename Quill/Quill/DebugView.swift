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
                
                Button("Export") {
                    let logs = logger.exportLogs()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logs, forType: .string)
                }
            }
            .padding()
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
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct DebugLogRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            
            Text("[\(entry.level.rawValue)]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(levelColor)
            
            if !entry.source.isEmpty {
                Text("[\(entry.source)]")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            
            Spacer()
        }
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