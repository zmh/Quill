//
//  DateFormatter+Extensions.swift
//  Quill
//
//  Created by Claude on 7/6/25.
//

import Foundation

extension Date {
    func simplifiedRelativeString() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        
        // Future dates
        if interval < 0 {
            let futureInterval = abs(interval)
            
            if futureInterval < 60 {
                return "now"
            } else if futureInterval < 3600 {
                let minutes = Int(futureInterval / 60)
                return "in \(minutes) min"
            } else if futureInterval < 86400 {
                let hours = Int(futureInterval / 3600)
                return "in \(hours) hour\(hours == 1 ? "" : "s")"
            } else if futureInterval < 2592000 { // 30 days
                let days = Int(futureInterval / 86400)
                return "in \(days) day\(days == 1 ? "" : "s")"
            } else if futureInterval < 31536000 { // 365 days
                let months = Int(futureInterval / 2592000)
                return "in \(months) month\(months == 1 ? "" : "s")"
            } else {
                let years = Int(futureInterval / 31536000)
                return "in \(years) year\(years == 1 ? "" : "s")"
            }
        }
        
        // Past dates
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if interval < 2592000 { // 30 days
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if interval < 31536000 { // 365 days
            let months = Int(interval / 2592000)
            return "\(months) month\(months == 1 ? "" : "s") ago"
        } else {
            let years = Int(interval / 31536000)
            return "\(years) year\(years == 1 ? "" : "s") ago"
        }
    }
}