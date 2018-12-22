//
//  MultiRegex.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

// MultiRegex Featurizer
public struct MultiRegex : TransformProtocol, Codable {
    static let regexKey = "RegexArrayKey"

    //Base Properties
    public let name: DataString
    public let transformerType: TransformType

    //Parameters: NB read only (let)
    private let regexVector: VectorDataString

    //Metadata: NB access on write must be protected for concurrency access if this is a .Mapper


    public init(name: String = "MultiRegex", regexValues: VectorDataString = [String]()) {
        self.name = name
        self.transformerType = .Featurizer
        self.regexVector = regexValues
    }
    
    public mutating func transform(input: MatrixDataIO, generateMetadata: Bool) throws -> MatrixDataIO {
        var vectors = MatrixDataIO()
        for doc in input.toMatrixDataString() {
            var vector = VectorDataIO()
            for regex in regexVector {
                vector.append(search(text: doc[0], regexp: regex) ? DataIO.DataFloat(value: DataFloat(1)) : DataIO.DataFloat(value: DataFloat(0)))
            }
            vectors.append(vector)
        }

        return vectors
    }

    private func search(text: String, regexp: String) -> Bool {
        if let _ = text.range(of:regexp, options: .regularExpression) {
            return true //text.distance(from: text.startIndex, to: range.lowerBound)
        }
        
        return false //not found
    }
}