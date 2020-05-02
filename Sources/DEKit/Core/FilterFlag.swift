//
//  FilterFlag.swift
//  DEKit
//
//  Created by Kirill Gorbachyonok on 5/3/20.
//

import Foundation

struct FilterFlag: OptionSet {
    
    let rawValue: RawValue
    
    static let write = FilterFlag(rawValue: UInt32(NOTE_WRITE))
    static let delete = FilterFlag(rawValue: UInt32(NOTE_DELETE))
    static let rename = FilterFlag(rawValue: UInt32(NOTE_RENAME))
    
    static let all: FilterFlag = [.write, .delete, .rename]
}

extension FilterFlag {
    typealias RawValue = UInt32
}
