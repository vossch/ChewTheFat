//
//  Item.swift
//  ChewTheFat
//
//  Created by Chad Voss on 4/21/26.
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
