//
//  Transformer.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

//Transformer type: Mapper or Featurizer
public enum TransformType : String, Codable {
    case Mapper
    case Featurizer
}

// Generic Transormer interface for Mapper and Featurizer
public protocol TransformProtocol : Codable {
    var name: DataString { get }
    var transformerType: TransformType { get }

    init?(from json: String) throws
    func typeName() -> String
    func typeOf() -> TransformProtocol.Type
    func encode() -> String 
    mutating func transform(input: MatrixDataIO, generateMetadata: Bool) throws -> MatrixDataIO
}

// Default implementation for deserialize a Transformer from a JSON string
extension TransformProtocol {
    public init?(from json: String) throws {
        guard let data = json.data(using: .utf8) else { return nil }
        guard let value = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = value
    }

    public func typeName() -> String {
        return "\(type(of: self))"
    }

    public func typeOf() -> TransformProtocol.Type {
        return type(of: self)
    }

    public func encode() -> String {
        return String(data: try! JSONEncoder().encode(self), encoding: .utf8)!
    }
}

// Transformer errors
public enum TransformerError : Error {
    case MetadataNotValid
    case FeaturesVectorOfDifferentShape
    case ParallelExecuteFeaturizers
    case ParallelExecuteMapper
}
