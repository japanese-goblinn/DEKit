//
//  String+Error.swift
//  DEKit
//
//  Created by Kirill Gorbachyonok on 5/3/20.
//

import Foundation

extension String: Error {}

extension String: LocalizedError {
    public var errorDescription: String? { self }
}
