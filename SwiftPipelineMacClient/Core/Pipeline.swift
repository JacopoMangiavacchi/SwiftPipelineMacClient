//
//  Pipeline.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

public let defaultMinNumberOfRowInSplit = 100
public let defaultSplitRate:Float = 0.3

// Pipeline object to chain and execute several Mappar and Featurizer tranformers
public struct Pipeline : Codable {
    public var features: [DataString : MatrixDataIO]
    public var splitRate: Float
    public var minNumberOfRowInSplit: Int
    private(set) var transformers: [TransformProtocol]
    private var  transformersJsonMap: [String : String]

    private let internalTransformersSwiftTypeOfMap: [String : TransformProtocol.Type] = [
                                                      "AddFeaturizer" : AddFeaturizer.self,
                                                      "FakeMapper" : FakeMapper.self, 
                                                      "BinaryDictionary" : BinaryDictionary.self, 
                                                      "BOW" : BOW.self, 
                                                      "MultiDictionary" : MultiDictionary.self, 
                                                      "MultiRegex" : MultiRegex.self, 
                                                      "Tokenizer" : Tokenizer.self, 
                                                    ]

    enum CodingKeys: String, CodingKey {
        case transformersJsonMap
        case splitRate
        case minNumberOfRowInSplit
    }
    
    public init() {
        self.transformers = [TransformProtocol]()
        self.features = [DataString : MatrixDataIO]()
        self.splitRate = defaultSplitRate
        self.minNumberOfRowInSplit = defaultMinNumberOfRowInSplit
        self.transformersJsonMap = [String : String]()
    }

    public init(transformers: [TransformProtocol], splitRate: Float = defaultSplitRate, minNumberOfRowInSplit: Int = defaultMinNumberOfRowInSplit) { 
        self.transformers = transformers
        self.features = [DataString : MatrixDataIO]()
        self.splitRate = splitRate
        self.minNumberOfRowInSplit = minNumberOfRowInSplit
        self.transformersJsonMap = [String : String]()
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.splitRate = try values.decode(Float.self, forKey: .splitRate)
        self.minNumberOfRowInSplit = try values.decode(Int.self, forKey: .minNumberOfRowInSplit)
        self.transformersJsonMap = try values.decode([String : String].self, forKey: .transformersJsonMap)
        self.transformers = [TransformProtocol]()
        self.features = [DataString : MatrixDataIO]()

        //NB Inject internal Transformers only - If pipeline use external transformers client need to explicity call injectTransformers() after decode and pass the external transformers type/name list
        try injectTransformers(transformerMap: [DataString : TransformProtocol.Type]())
    }

    public mutating func injectTransformers(transformerMap externalTransformersSwiftTypeOfMap: [DataString : TransformProtocol.Type]) throws {
        guard !self.transformersJsonMap.isEmpty else { return }

        var transformersSwiftTypeOfMap = internalTransformersSwiftTypeOfMap
        transformersSwiftTypeOfMap.merge(externalTransformersSwiftTypeOfMap) { (current, _) in current }

        self.transformers = try self.transformersJsonMap.compactMap { 
            let name = $0.key
            let json = $0.value
            if let fakeType: TransformProtocol.Type = transformersSwiftTypeOfMap[name] {
                return try fakeType.init(from: json)
            }
            return nil
        }

        if self.transformers.count == self.transformersJsonMap.count {
            self.transformersJsonMap.removeAll()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var transformersJsonMap: [String : String] = [String : String]()
        transformers.forEach { transformersJsonMap[$0.typeName()] = $0.encode() }
    
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(transformersJsonMap, forKey: CodingKeys.transformersJsonMap)
        try container.encode(splitRate, forKey: CodingKeys.splitRate)
        try container.encode(minNumberOfRowInSplit, forKey: CodingKeys.minNumberOfRowInSplit)
    }
    
    public mutating func append(_ transformer: TransformProtocol) {
        transformers.append(transformer)
    }

    public func transformed(input: VectorDataString, generateMetadata: Bool = true) throws -> Pipeline {
        return try transformed(input: input.map { [$0] }, generateMetadata: generateMetadata)
    }

    public func transformed(input: MatrixDataString, generateMetadata: Bool = true) throws -> Pipeline {
        return try transformed(input: input.toMatrixDataIO(), generateMetadata: generateMetadata)
    }

    public func transformed(input: MatrixDataFloat, generateMetadata: Bool = true) throws -> Pipeline {
        return try transformed(input: input.toMatrixDataIO(), generateMetadata: generateMetadata)
    }

    public func transformed(input: MatrixDataIO, generateMetadata: Bool = true) throws -> Pipeline {
        var t = self
        try t.transform(input: input, generateMetadata: generateMetadata)
        return t
    }

    public mutating func transform(input: VectorDataString, generateMetadata: Bool = true) throws {
        try transform(input: input.map { [$0] } as MatrixDataString, generateMetadata: generateMetadata)
    }

    public mutating func transform(input: MatrixDataString, generateMetadata: Bool = true) throws {
         try transform(input: input.toMatrixDataIO(), generateMetadata: generateMetadata)
    }

    public mutating func transform(input: MatrixDataFloat, generateMetadata: Bool = true) throws {
         try transform(input: input.toMatrixDataIO(), generateMetadata: generateMetadata)
    }

    public mutating func transform(input: MatrixDataIO, generateMetadata: Bool = true) throws {
        features.removeAll()

        //Concurrently process chunck of Featurizer and barrier on Mapper
        var previousInput = input
        var fromPos = 0
        var toPos = 0
        for currentPos in 0..<transformers.count {
            //Barrier on Mapper - Execute it sequentially after the eventual parallel execution of a chunk of Featurizer
            if transformers[currentPos].transformerType == .Mapper {
                //Execute in parallel the chunk of Featurizer [fromPos..<toPos]
                try ParallelExecuteFeaturizers(input: previousInput, fromPos: fromPos, toPos: toPos, generateMetadata: generateMetadata)

                //Execute mapper
                previousInput = try ParallelExecuteMapper(input: previousInput, pos: currentPos, generateMetadata: generateMetadata)
            
                //Increment fromPos and toPos to the next transfomer
                fromPos = currentPos + 1
                toPos = toPos + 1
            }
            else {
                //Increment toPos add the current Featurizer to the chunck to execute in parallel
                toPos += 1
            }
        }

        //Check if there is last chunck of Featurizer to process in parallel
        if toPos > fromPos {
            //Barrier on Mapper - Execute it sequentially after the eventual parallel execution of a chunk of Featurizer
            try ParallelExecuteFeaturizers(input: previousInput, fromPos: fromPos, toPos: toPos, generateMetadata: generateMetadata)
        }
    }

    private mutating func ParallelExecuteFeaturizers(input: MatrixDataIO, fromPos: Int, toPos: Int, generateMetadata: Bool) throws {
        //Serial queue to serialize access to shared objects
        let serialQueue = DispatchQueue(label: "featurizer-serialqueue")

        let numOfFeaturizers = toPos - fromPos
        guard numOfFeaturizers > 0 else { return }

        //Local temp data needed for Async support
        var arrayFeatures = [MatrixDataIO](repeating: MatrixDataIO(), count: numOfFeaturizers)

        //Execute each Featurizer in parallel
        var asyncCatched = false
        let _ = DispatchQueue.global(qos: .background)
        DispatchQueue.concurrentPerform(iterations: numOfFeaturizers) { iteration in
            //print("--- Executing \(transformers[fromPos + iteration].name) Featurizer")
            do {
                let transformResult = try transformers[fromPos + iteration].transform(input: input, generateMetadata: generateMetadata)
                serialQueue.sync {
                    arrayFeatures[iteration] = transformResult
                }
            }
            catch {
                asyncCatched = true
                print("Catch in ParallelExecuteFeaturizers")
            }
        }

        if asyncCatched {
            throw TransformerError.ParallelExecuteFeaturizers
        }

        //Copy arrayFeatures to features
        for transformerPos in fromPos..<toPos {
            features[transformers[transformerPos].name] = arrayFeatures[transformerPos - fromPos]
        }
    }

    private mutating func ParallelExecuteMapper(input: MatrixDataIO, pos: Int, generateMetadata: Bool) throws -> MatrixDataIO {
        //Serial queue to serialize access to shared objects
        let serialQueue = DispatchQueue(label: "mapper-serialqueue")

        //Check if input number of rows are enough to be splitted
        let splitSize = min(max(Int(Float(input.count) * splitRate), minNumberOfRowInSplit), input.count)
        let inputChunks = stride(from: 0, to: input.count, by: splitSize).map {
            Array(input[$0 ..< Swift.min($0 + splitSize, input.count)])
        }
        let numOfSplit = inputChunks.count
        //print("--- Split: ", numOfSplit, splitSize, input.count)

        //Local temp data needed for Async support
        var arrayOutput = [MatrixDataIO](repeating: MatrixDataIO(), count: numOfSplit)
        
        //Execute each MapperProtocol with parallel chunck of input
        var asyncCatched = false
        let _ = DispatchQueue.global(qos: .background)
        DispatchQueue.concurrentPerform(iterations: numOfSplit) { split in
            //print("--- Executing \(transformers[pos].name) Mapper split: \(split)")
            do {
                let transformResult = try transformers[pos].transform(input: inputChunks[split], generateMetadata: generateMetadata)
                serialQueue.sync { 
                    arrayOutput[split] = transformResult
                }
            }
            catch {
                asyncCatched = true
                print("Catch in Mapper chunk transform")
            }
        }

        if asyncCatched {
            throw TransformerError.ParallelExecuteMapper
        }

        //Merge output of all chunck and Metadata to current mapper info
        var output = MatrixDataIO()
        for split in 0..<numOfSplit {
            output += arrayOutput[split]
        }

        //Return new input
        return output
    }

    public func concatenatedFeatures(selectedFeatures: VectorDataString? = nil) throws -> MatrixDataIO {
        guard !features.isEmpty else { return MatrixDataIO() }
        guard let countOfRecords = features.first?.value.count else { return MatrixDataIO() }

        //Filter Selected Features
        var selFeatures = features
        if let selectedFeatures = selectedFeatures {
            selFeatures = selectedFeatures.reduce(into: [DataString: MatrixDataIO]()) { $0[$1] = features[$1] }
        }

        //Concatenate Features DataFloat vectors
        var flatFeatures:MatrixDataIO = MatrixDataIO(repeating: VectorDataIO(), count: countOfRecords)
        for ff in selFeatures.values {
            if ff.count != countOfRecords {
                throw TransformerError.FeaturesVectorOfDifferentShape
            }
            for i in 0..<countOfRecords {
                flatFeatures[i] += ff[i]
            }
        }

        return flatFeatures
    }
}
