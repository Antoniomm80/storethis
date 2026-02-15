//
//  Item.swift
//  storagethis
//
//  Created by Antonio on 15/2/26.
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
