//
//  BOW.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

public enum KeyType : String, Codable {
    case WordGram
    case CharGram
}

public enum HashAlgorithm : String, Codable {
    case DJB2
    case SDBM
}

public enum ValueType : Codable {
    case HashingTrick(algorithm: HashAlgorithm, vectorSize: Int)
    case TFIDF(minCount: Int)
}

extension ValueType {
    enum Discriminator: String, Decodable {
        case HashingTrick, TFIDF
    }
    
    enum CodingKeys: String, CodingKey {
        case discriminator
        case algorithm
        case vectorSize
        case minCount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let discriminator = try container.decode(Discriminator.self, forKey: .discriminator)
        switch discriminator {
        case .HashingTrick:
            let algorithm = try container.decode(HashAlgorithm.self, forKey: .algorithm)
            let vectorSize = try container.decode(Int.self, forKey: .vectorSize)
            self = .HashingTrick(algorithm: algorithm, vectorSize: vectorSize)
        case .TFIDF:
            let minCount = try container.decode(Int.self, forKey: .minCount)
            self = .TFIDF(minCount: minCount)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .HashingTrick(let algorithm, let vectorSize):
            try container.encode(algorithm, forKey: .algorithm)
            try container.encode(vectorSize, forKey: .vectorSize)
        case .TFIDF(let minCount):
            try container.encode(minCount, forKey: .minCount)
        }
    }
}

// Bow with Hash or TfIdf Featurizer for words, wordgrams and chargrams
public struct BOW : TransformProtocol, Codable {
    //Base Properties
    public let name: DataString
    public let transformerType: TransformType

    //Parameters: NB read only (let)
    private let keyType: KeyType
    private let ngramLength: Int
    private let valueType: ValueType

    //Metadata: NB access on write must be protected for concurrency access if this is a .Mapper
    public var vocabulary: [String : DataFloat]

    public init(name: String = "BOW", keyType: KeyType = .WordGram, ngramLength: Int = 1, valueType: ValueType = .TFIDF(minCount: 1)) {
        self.name = name
        self.transformerType = .Featurizer
        self.keyType = keyType
        self.ngramLength = ngramLength
        self.valueType = valueType
        self.vocabulary = [String : DataFloat]()
    }
    
    public mutating func transform(input: MatrixDataIO, generateMetadata: Bool) throws -> MatrixDataIO {
        let nGramMatrix = getNGramMatrix(input: input.toMatrixDataString())

        switch valueType {
        case .HashingTrick(let algorithm, let vectorSize):
            return HashingTrick(input: nGramMatrix, algorithm: algorithm, vectorSize: vectorSize).toMatrixDataIO()
        case .TFIDF(let minCount):
            if generateMetadata {
                return TFIDFGenerateVocabulary(input: nGramMatrix, minCount: minCount).toMatrixDataIO()
            }
            else{
                return TFIDFUseVocabulary(input: nGramMatrix).toMatrixDataIO()
            }
        }
    }

    private func getNGramMatrix(input: MatrixDataString) -> MatrixDataString {
        var nGramMatrix = MatrixDataString()

        for inputVector in input {
            var nGramVector = VectorDataString()
            for wordStartPos in 0..<inputVector.count {
                switch keyType {
                case .WordGram:
                    var nGram = String()
                    let m = min(ngramLength, inputVector.count - wordStartPos)
                    for pos in 0..<m {
                        if pos > 0 {
                            nGram += " \(inputVector[wordStartPos + pos])"
                        }
                        else {
                            nGram = inputVector[wordStartPos + pos]
                        }

                        nGramVector.append(nGram)
                    }

                case .CharGram:
                    let size = max(1, ngramLength)
                    let word = size == 1 ? inputVector[wordStartPos] : " \(inputVector[wordStartPos]) "
                    for charStartPos in 0...max(0, word.count - size) {
                        let startIndex = word.index(word.startIndex, offsetBy: charStartPos)
                        let endIndex = word.index(startIndex, offsetBy: min(size, word.count - charStartPos))
                        nGramVector.append(String(word[startIndex..<endIndex]))
                    }
                }
            }

            nGramMatrix.append(nGramVector)
        }

        return nGramMatrix
    }

    private mutating func HashingTrick(input: MatrixDataString, algorithm: HashAlgorithm, vectorSize: Int) -> MatrixDataFloat {
        // function hashing_vectorizer(features : array of string, N : integer):
        //     x := new vector[N]
        //     for f in features:
        //         h := hash(f)
        //         x[h mod N] += 1
        //     return x

        var vectors = MatrixDataFloat()
        for doc in input {
            var vector = VectorDataFloat(repeating: 0.0, count: vectorSize)
            for word in doc {
                let h = algorithm == .DJB2 ? word.djb2hash : word.sdbmhash
                if h < 0 {
                    //print("*** Error hashing word: \(word) -> \(h)")
                }
                else {
                    vector[h % vectorSize] += 1
                }
            }

            vectors.append(vector)
        }
        
        return L2Normalize(vectors: vectors)
    }

    private mutating func TFIDFGenerateVocabulary(input: MatrixDataString, minCount: Int) -> MatrixDataFloat {
        //Create Temp BOW Dictionary with word frequency in dataset and word frequency per document
        var bow = [String : (Int, [Int : Int])]()  // token : (freq in dataset, [doc : freq in doc])
        var docId = 0
        for doc in input {
            for word in doc {
                if var x = bow[word] {
                    x.0 += 1
                    if let _ = x.1[docId] {
                        x.1[docId]! += 1
                    }
                    else {
                        x.1[docId] = 1
                    }
                    bow[word] = x
                }
                else {
                    bow[word] = (1, [docId : 1])
                }
            }
            docId += 1
        }
        
        //Filter Bow with minCount
        bow = bow.filter{ $0.value.0 >= minCount }

        //Create Features Vectors with BOW TF-IDF values
        var vectors = MatrixDataFloat()
        docId = 0
        for doc in input {
            var vector = VectorDataFloat()
            for (word, touple) in bow {
                var tfidf:DataFloat = 0
                if doc.contains(word) {
                    tfidf = TFIDF(numberOfDocs: DataFloat(input.count), datasetFreq: DataFloat(touple.0), docFreq: DataFloat(touple.1[docId]!))
                }
                vector.append(tfidf)
            }
            vectors.append(vector)
            docId += 1
        }
        
        self.vocabulary = Dictionary(uniqueKeysWithValues: bow.map{ key, value in (key, DataFloat(value.0)) })

        return L2Normalize(vectors: vectors)
    }

    private func TFIDFUseVocabulary(input: MatrixDataString) -> MatrixDataFloat {
        //Create Features Vectors with BOW TF-IDF values
        var vectors = MatrixDataFloat()
        for doc in input {
            var vector = VectorDataFloat()
            for (word, datasetFreq) in self.vocabulary {
                var tfidf:DataFloat = 0
                let docFreq = DataFloat(doc.filter({ $0 == word }).count)
                if docFreq > 0 {
                    tfidf = TFIDF(numberOfDocs: DataFloat(input.count), datasetFreq: datasetFreq, docFreq: docFreq)
                }
                vector.append(tfidf)
            }
            vectors.append(vector)
        }
        
        return L2Normalize(vectors: vectors)
    }

    private func TFIDF(numberOfDocs: DataFloat, datasetFreq: DataFloat, docFreq: DataFloat) -> DataFloat {
        return docFreq * (numberOfDocs / (1.0 + docFreq)) //log(numberOfDocs / (1.0 + docFreq))
    }

    private func L2Normalize(vectors: MatrixDataFloat) -> MatrixDataFloat {
        return vectors.map { vector in 
            let sqrtSumSquared:DataFloat = sqrt(vector.reduce(0, { $0 + ($1 * $1) }))
            return vector.map{ $0 / sqrtSumSquared }
        }
    }
}
