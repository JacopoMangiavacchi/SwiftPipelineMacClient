//
//  DataIO.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

public typealias DataFloat = Float
public typealias DataString = String

public typealias MatrixDataFloat = [[DataFloat]]
public typealias MatrixDataString = [[DataString]]

public typealias VectorDataFloat = [DataFloat]
public typealias VectorDataString = [DataString]

// Basic data types supported for Inputs, Outputs, Features
public enum DataIO {
    case DataFloat(value: DataFloat)
    case DataString(value: DataString)

    func toDataFloat() -> DataFloat? {
        switch self {
        case .DataFloat(let value):
            return value
        default:
            return nil
        }
    }

    func toDataString() -> DataString? {
        switch self {
        case .DataString(let value):
            return value
        default:
            return nil
        }
    }
}

extension DataIO : Codable {
    enum CodingKeys: String, CodingKey {
        case DataFloat, DataString
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(DataIO.self, forKey: .DataFloat) {
            self = value
        }
        else if let value = try container.decodeIfPresent(DataIO.self, forKey: .DataString) {
            self = value
        }
        else {
            self = .DataString(value: "error decoding")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .DataFloat(let value):
            try container.encode(value, forKey: .DataFloat)
        case .DataString(let value):
            try container.encode(value, forKey: .DataString)
        }
    }
}

public typealias MatrixDataIO = [[DataIO]]
public typealias VectorDataIO = [DataIO]

extension Sequence where Iterator.Element == VectorDataIO {
    public func toMatrixDataFlow() -> MatrixDataFloat {
        return self.map { $0.compactMap{ $0.toDataFloat() } }
    }

    public func toMatrixDataString() -> MatrixDataString {
        return self.map { $0.compactMap{ $0.toDataString() } }
    }
}

extension Sequence where Iterator.Element == VectorDataFloat {
    public func toMatrixDataIO() -> MatrixDataIO {
        return self.map { $0.map{ DataIO.DataFloat(value: $0) } }
    }
}

extension Sequence where Iterator.Element == VectorDataString {
    public func toMatrixDataIO() -> MatrixDataIO {
        return self.map { $0.map{ DataIO.DataString(value: $0) } }
    }
}

extension Sequence where Iterator.Element == DataFloat {
    public func toVectorDataIO() -> VectorDataIO {
        return self.map { DataIO.DataFloat(value: $0) }
    }
}

extension Sequence where Iterator.Element == DataString {
    public func toVectorDataIO() -> VectorDataIO {
        return self.map { DataIO.DataString(value: $0) }
    }
}

//Utility Initializers for basic Literal types
extension DataIO: ExpressibleByStringLiteral {
    // By using 'StaticString' we disable string interpolation, for safety
    public init(stringLiteral value: StaticString) {
        self = DataIO.DataString(value: "\(value)")
    }
}

extension DataIO: ExpressibleByIntegerLiteral {
    public init(integerLiteral: IntegerLiteralType) {
        self = DataIO.DataFloat(value: Float(integerLiteral))
    }
}

extension DataIO: ExpressibleByFloatLiteral {
    public init(floatLiteral: FloatLiteralType) {
        self = DataIO.DataFloat(value: Float(floatLiteral))
    }
}
