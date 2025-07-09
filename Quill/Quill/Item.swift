//
//  Item.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
