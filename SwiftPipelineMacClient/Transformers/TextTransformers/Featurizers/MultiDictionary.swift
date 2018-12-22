//
//  MultiDictionary.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

// MultiDictionary Featurizer
public struct MultiDictionary : TransformProtocol, Codable {
    //Base Properties
    public let name: DataString
    public let transformerType: TransformType

    //Parameters: NB read only (let)
    private let wordsVector: [String]

    //Metadata: NB access on write must be protected for concurrency access if this is a .Mapper

    public init(name: String = "MultiDictionary", words: [String]) {
        self.name = name
        self.transformerType = .Featurizer
        self.wordsVector = words
    }
    
    public mutating func transform(input: MatrixDataIO, generateMetadata: Bool) throws -> MatrixDataIO {
        var vectors = MatrixDataIO()

        for doc in input.toMatrixDataString() {
            var vector = VectorDataIO()
            for word in wordsVector {
                if doc.contains(word) {
                    vector.append(DataIO.DataFloat(value: DataFloat(1)))
                }
                else {
                    vector.append(DataIO.DataFloat(value: DataFloat(0)))
                }
            }
            vectors.append(vector)
        }

        return vectors
    }
}
