//
//  FoundationExtensions.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

extension Array {
    mutating func randomize() {
        for i in 0..<self.count {
            let r = Int.random(in: 0..<Int(self.count - i))
            (self[i], self[i+r]) = (self[i+r], self[i])
        }
    }
}

extension Array {
    func split(percentage: Float) -> (Array, Array) {
        let pos = Int(Float(count) * percentage)
        return pos >= 0 && pos < count ? (Array(self[0..<pos]), Array(self[pos..<count])) : (Array(), self)
    }
}

// http://www.cse.yorku.ca/~oz/hash.html
extension String {
    // hash(0) = 5381
    // hash(i) = hash(i - 1) * 33 ^ str[i];
    var djb2hash: Int {
        let unicodeScalars = self.unicodeScalars.map { $0.value }
        return unicodeScalars.reduce(5381) {
            ($0 << 5) &+ $0 &+ Int($1)
        }
    }

    // hash(0) = 0
    // hash(i) = hash(i - 1) * 65599 + str[i];
    var sdbmhash: Int {
        let unicodeScalars = self.unicodeScalars.map { $0.value }
        return unicodeScalars.reduce(0) {
            Int($1) &+ ($0 << 6) &+ ($0 << 16) - $0
        }
    }
}

