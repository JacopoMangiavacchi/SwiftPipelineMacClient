//
//  BinaryDictionary.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

// BinaryDictionary Featurizer
public struct BinaryDictionary : TransformProtocol, Codable {
    //Base Properties
    public let name: DataString
    public let transformerType: TransformType

    //Parameters: NB read only (let)
    private let wordsVector: [String]

    //Metadata: NB access on write must be protected for concurrency access if this is a .Mapper

    public init(name: String = "BinaryDictionary", words: [String]) {
        self.name = name
        self.transformerType = .Featurizer
        self.wordsVector = words
    }
    
    public mutating func transform(input: MatrixDataIO, generateMetadata: Bool) throws -> MatrixDataIO {
        var vectors = MatrixDataIO()

        for doc in input.toMatrixDataString() {
            var vector = [DataIO.DataFloat(value: DataFloat(0))]
            for word in wordsVector {
                if doc.contains(word) {
                    vector = [DataIO.DataFloat(value: DataFloat(1))]
                    break
                }
            }
            vectors.append(vector)
        }

        return vectors
    }
}
