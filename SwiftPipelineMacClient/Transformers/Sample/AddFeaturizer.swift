//
//  AddFeaturizer.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

// AddFeaturizer Featurizer
public struct AddFeaturizer : TransformProtocol, Codable {
    //Base Properties
    public let name: DataString
    public let transformerType: TransformType

    //Parameters: NB read only (let)

    //Metadata: NB access on write must be protected for concurrency access if this is a .Mapper

    public init(name: String = "AddFeaturizer") {
        self.name = name
        self.transformerType = .Featurizer
    }
    
    public mutating func transform(input: MatrixDataIO, generateMetadata: Bool) throws -> MatrixDataIO {
        return input
    }
}
