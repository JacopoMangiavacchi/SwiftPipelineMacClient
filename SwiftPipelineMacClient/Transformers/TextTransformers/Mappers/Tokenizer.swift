//
//  Tokenizer.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

// Tokenizer Mapper
public struct Tokenizer : TransformProtocol, Codable {
    //Base Properties
    public let name: DataString
    public let transformerType: TransformType

    //Parameters: NB read only (let)
    private let separatorString: String
    private let stopWordsVector: [String]

    //Metadata: NB access on write must be protected for concurrency access if this is a .Mapper

    public init(name: String = "Tokenizer", separators: String, stopWords: [String] = [String]()) {
        self.name = name
        self.transformerType = .Mapper
        self.separatorString = separators
        self.stopWordsVector = stopWords
    }
    
    public func transform(input: MatrixDataIO, generateMetadata: Bool) throws -> MatrixDataIO {
        let lowerStopWords = stopWordsVector.map{ $0.lowercased() }

        var textTokens = MatrixDataString()
        for text in input.toMatrixDataString() {
            textTokens.append(Tokenize(text: text[0], separators: separatorString).compactMap({ (token) -> DataString? in
                return token.isEmpty || lowerStopWords.contains(token) ? nil : token
            }))
        }

        return textTokens.toMatrixDataIO()
    }

    private func Tokenize(text: DataString, separators: DataString) -> [DataString] {
        return text.lowercased().components(separatedBy: CharacterSet(charactersIn: separators))
    }
}
