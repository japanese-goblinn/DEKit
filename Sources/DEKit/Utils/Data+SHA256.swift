//
//  Data+SHA256.swift
//  DEKit
//
//  Created by Kirill Gorbachyonok on 5/3/20.
//

import Foundation
import CommonCrypto

extension Data {
    public var SHA256hash: Self {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Self(hash)
    }
    
    public var SHA256hashString: String {
        self.SHA256hash.map { String(format: "%02X", $0) }.joined()
    }
}
