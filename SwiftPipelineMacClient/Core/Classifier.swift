//
//  Classifier.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

// Classifier errors
public enum ClassifierError : Error {
    case CatchInParallelLearner
    case CatchInParallelLabelLearner
    case InputCountDifferentFromLabelCount
    case SplitTestGreatherThanOne
    case InsufficientNumberOfLabels
}

public let defaultSplitTest:Float = 0.3
public let binaryPredictionThreshold:Float = 0.0

// Classifier object to train and predict with several Learner Protocols Classifiers
public struct Classifier : Codable {
    public var pipeline: Pipeline
    public var learners: [LearnerProtocol]
    private var learnersInfo: [LearnerInfo]
    public var splitTest: Float
    public var trainedLabels: VectorDataString
    public var trainResults: [TrainResult]
    public var multiClass: Bool 
    public var multiLabel: Bool
    private var modelDataArray: [[Data]]

    enum CodingKeys: String, CodingKey {
        case pipeline
        case learnersInfo
        case splitTest
        case trainedLabels
        case trainResults
        case multiClass 
        case multiLabel
        case modelDataArray
    }
    
    public init() {
        self.pipeline = Pipeline()
        self.learners = [LearnerProtocol]()
        self.learnersInfo = [LearnerInfo]()
        self.splitTest = defaultSplitTest
        self.trainedLabels = VectorDataString()
        self.trainResults = [TrainResult]()
        self.multiClass = false
        self.multiLabel = false
        self.modelDataArray = [[Data]]()
    }

    public init(pipeline: Pipeline = Pipeline(), learners: [LearnerProtocol], splitTest: Float = defaultSplitTest) {
        self.pipeline = pipeline
        self.learners = learners
        self.learnersInfo = learners.map{ $0.info }
        self.splitTest = splitTest
        self.trainedLabels = VectorDataString()
        self.trainResults = [TrainResult]()
        self.multiClass = false
        self.multiLabel = false
        self.modelDataArray = [[Data]]()
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.pipeline = try values.decode(Pipeline.self, forKey: .pipeline)
        self.learnersInfo = try values.decode([LearnerInfo].self, forKey: .learnersInfo)
        self.learners = [LearnerProtocol]()
        self.splitTest = try values.decode(Float.self, forKey: .splitTest)
        self.trainedLabels = try values.decode(VectorDataString.self, forKey: .trainedLabels)
        self.trainResults = try values.decode([TrainResult].self, forKey: .trainResults)
        self.multiClass = try values.decode(Bool.self, forKey: .multiClass)
        self.multiLabel = try values.decode(Bool.self, forKey: .multiLabel)
        self.modelDataArray = try values.decode([[Data]].self, forKey: .modelDataArray)
    }
    
    public mutating func injectLearnersAndTransformers(learnerMap: [DataString : LearnerProtocol.Type], transformerMap: [DataString : TransformProtocol.Type]) throws {
        for info in learnersInfo {
            if let type: LearnerProtocol.Type  = learnerMap[info.type] {
                let learner = type.init(name: info.name)
                learners.append(learner)
            }
        }
        try pipeline.injectTransformers(transformerMap: transformerMap)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pipeline, forKey: CodingKeys.pipeline)
        try container.encode(learnersInfo, forKey: CodingKeys.learnersInfo)
        try container.encode(splitTest, forKey: CodingKeys.splitTest)
        try container.encode(trainedLabels, forKey: CodingKeys.trainedLabels)
        try container.encode(trainResults, forKey: CodingKeys.trainResults)
        try container.encode(multiClass, forKey: CodingKeys.multiClass) 
        try container.encode(multiLabel, forKey: CodingKeys.multiLabel)
        try container.encode(modelDataArray, forKey: CodingKeys.modelDataArray)
    }
    
    public func trained(input: VectorDataString, labels: VectorDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> Classifier {
        return try trained(input: input.map { [$0] }, labels: labels.map { [$0] }, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public func trained(input: VectorDataString, labels: MatrixDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> Classifier {
        return try trained(input: input.map { [$0] }, labels: labels, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public func trained(input: MatrixDataString, labels: VectorDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> Classifier {
        return try trained(input: input.toMatrixDataIO(), labels: labels.map { [$0] }, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public func trained(input: MatrixDataString, labels: MatrixDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> Classifier {
        return try trained(input: input.toMatrixDataIO(), labels: labels, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public func trained(input: MatrixDataIO, labels: VectorDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> Classifier {
        return try trained(input: input, labels: labels.map { [$0] }, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public func trained(input: MatrixDataIO, labels: MatrixDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> Classifier {
        var t = self
        try t.train(input: input, labels: labels, selectedFeatures: selectedFeatures, parallel: parallel)
        return t
    }

    public mutating func train(input: VectorDataString, labels: VectorDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws {
        try self.train(input: input.map { [$0] }, labels: labels.map { [$0] }, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public mutating func train(input: VectorDataString, labels: MatrixDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws {
        try self.train(input: input.map { [$0] }, labels: labels, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public mutating func train(input: MatrixDataString, labels: VectorDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws {
        try self.train(input: input.toMatrixDataIO(), labels: labels.map { [$0] }, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public mutating func train(input: MatrixDataString, labels: MatrixDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws {
        try self.train(input: input.toMatrixDataIO(), labels: labels, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public mutating func train(input: MatrixDataIO, labels: MatrixDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws {
        //Transform input & Concatenate features
        try pipeline.transform(input: input, generateMetadata: true)
        let floatFeatures = try pipeline.concatenatedFeatures(selectedFeatures: selectedFeatures)

        try train(input: floatFeatures, labels: labels, parallel: parallel)
    }

    public mutating func train(input floatFeatures: MatrixDataFloat, labels: MatrixDataString, parallel: Bool = true) throws {
        //Serial queue to serialize access to shared objects
        let serialQueue = DispatchQueue(label: "train-serialqueue")

        let countOfLearners = learners.count

        //Allocate data for learners model weights
        modelDataArray = [[Data]](repeating: [Data](), count: countOfLearners)

        //Pre Allocate label and result array
        trainResults = [TrainResult](repeating: TrainResult(), count: countOfLearners)

        //Get unique label set
        var allLabels = Set<DataString>()
        for larray in labels {
            for l in larray {
                allLabels.insert(l)
            }
        }
        trainedLabels = Array(allLabels)

        //Check if at least is a binary classifier
        guard trainedLabels.count > 1 else {
            throw ClassifierError.InsufficientNumberOfLabels
        }
        
        //Check if MultiClass input dataset
        multiClass = trainedLabels.count > 2

        //Map labels to categories
        let catLabels:[[Int]] = labels.map { $0.map { trainedLabels.firstIndex(of: $0) ?? -1 } }

        //Check if MultiLabel input dataset
        multiLabel = !catLabels.filter{ $0.count > 1 }.isEmpty

        //Random Split Training input dataset and labels
        let countOfRecords = floatFeatures.count
        guard countOfRecords == catLabels.count else {
            throw ClassifierError.InputCountDifferentFromLabelCount
        }
        guard splitTest < 1.0 && splitTest >= 0.0 else {
            throw ClassifierError.SplitTestGreatherThanOne
        }
        var randomPos:[Int] = (0..<countOfRecords).map{$0}
        randomPos.randomize()
        let (testFeatures, trainFeatures) = randomPos.map{ floatFeatures[$0] }.split(percentage: splitTest)
        let (testLabels, trainLabels) = randomPos.map{ catLabels[$0] }.split(percentage: splitTest)

        //Train and Evaluate the different learners
        if parallel {
            //Execute each Learner in parallel
            var asyncCatched = false
            let _ = DispatchQueue.global(qos: .background)
            DispatchQueue.concurrentPerform(iterations: countOfLearners) { i in
                do {
                    let trainResult = try train(learnerPos: i, trainFeatures: trainFeatures, testFeatures: testFeatures, trainLabels: trainLabels, testLabels: testLabels, parallel: parallel)
                    serialQueue.sync { 
                        trainResults[i] = trainResult
                    }
                }
                catch {
                    asyncCatched = true
                    print("Catch in Learner Train")
                }
            }

            if asyncCatched {
                throw ClassifierError.CatchInParallelLearner
            }
        }
        else {
            for i in 0..<countOfLearners {
                trainResults[i] = try train(learnerPos: i, trainFeatures: trainFeatures, testFeatures: testFeatures, trainLabels: trainLabels, testLabels: testLabels, parallel: parallel)
            }
        }
    }

    private mutating func train(learnerPos: Int, trainFeatures: MatrixDataFloat, testFeatures: MatrixDataFloat, trainLabels: [[Int]], testLabels: [[Int]], parallel: Bool) throws -> TrainResult {
        //Serial queue to serialize access to shared objects
        let serialQueue = DispatchQueue(label: "trainBinary-serialqueue")

        //Check if learner support multiClass/multiLabel case as the input training dataset
        if learners[learnerPos].info.multiClass == multiClass && learners[learnerPos].info.multiLabel == multiLabel {
            //Binary or multiClass|multiLabel learner
            let (trainResult, modelData) = try learners[learnerPos].train(trainFeatures: trainFeatures, testFeatures: testFeatures, trainLabels: trainLabels, testLabels: testLabels)
            modelDataArray[learnerPos].append(modelData)
            return trainResult
        }
        else { //Manage MultiClass and MultiLabel using One-Vs-All approach
            //Allocate data for learner model weights
            modelDataArray[learnerPos] = [Data](repeating: Data(), count: trainedLabels.count) 

            //Prepare array of Binary Labels
            var binaryTrainLabels = [[[Int]]](repeating: [[Int]](), count: trainedLabels.count)
            var binaryTestLabels = [[[Int]]](repeating: [[Int]](), count: trainedLabels.count)
            for i in 0..<trainedLabels.count {
                binaryTrainLabels[i] = trainLabels.map { $0.contains(i) ? [1] : [0] }
                binaryTestLabels[i] = testLabels.map { $0.contains(i) ? [1] : [0] }
            }

            //Prepare array of Binary Train Results
            var binaryTrainResults = [TrainResult](repeating: TrainResult(), count: trainedLabels.count)

            //Train and Evaluate a Binary learner for each Label
            if parallel {
                //Execute each Label Learner in parallel
                var asyncCatched = false
                let _ = DispatchQueue.global(qos: .background)
                DispatchQueue.concurrentPerform(iterations: trainedLabels.count) { i in
                    do {
                        let (trainResult, modelData) = try learners[learnerPos].train(trainFeatures: trainFeatures, testFeatures: testFeatures, trainLabels: binaryTrainLabels[i], testLabels: binaryTestLabels[i])
                        serialQueue.sync { 
                            modelDataArray[learnerPos][i] = modelData
                            binaryTrainResults[i] = trainResult
                        }
                    }
                    catch {
                        asyncCatched = true
                        print("Catch in Label Learner Train")
                    }
                }

                if asyncCatched {
                    throw ClassifierError.CatchInParallelLabelLearner
                }
            }
            else {
                for i in 0..<trainedLabels.count {
                    let (trainResult, modelData) = try learners[learnerPos].train(trainFeatures: trainFeatures, testFeatures: testFeatures, trainLabels: binaryTrainLabels[i], testLabels: binaryTestLabels[i])
                    modelDataArray[learnerPos][i] = modelData
                    binaryTrainResults[i] = trainResult
                }
            }

            //Summirize Train results from different Binary Learners
            var cost = Float(0)
            var euclideanDistance = Float(0)
            var f1 = Float(0)
            var microAvgAccuracy = Float(0)
            var macroAvgAccuracy = Float(0)
            var precision = [Float]()
            var recall = [Float]()
            for result in binaryTrainResults {
                cost += result.cost
                euclideanDistance += result.euclideanDistance
                f1 += result.f1
                microAvgAccuracy += result.microAvgAccuracy
                macroAvgAccuracy += result.macroAvgAccuracy
                precision.append(contentsOf: result.precision)
                recall.append(contentsOf: result.recall)
            }

            //Average f1 and Accuracies
            cost /= Float(trainedLabels.count)
            euclideanDistance /= Float(trainedLabels.count)
            f1 /= Float(trainedLabels.count)
            microAvgAccuracy /= Float(trainedLabels.count)
            macroAvgAccuracy /= Float(trainedLabels.count)

            return TrainResult(cost: cost,
                               euclideanDistance: euclideanDistance,
                               f1: f1, 
                               microAvgAccuracy: microAvgAccuracy, 
                               macroAvgAccuracy: macroAvgAccuracy, 
                               precision: precision, 
                               recall: recall)
        }
    }

    public func predict(input: VectorDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> [PredictResult] {
        return try predict(input: input.map { [$0] }, selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public func predict(input: MatrixDataString, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> [PredictResult] {
        return try predict(input: input.toMatrixDataIO(), selectedFeatures: selectedFeatures, parallel: parallel)
    }

    public func predict(input: MatrixDataIO, selectedFeatures: VectorDataString? = nil, parallel: Bool = true) throws -> [PredictResult] {
        //Transform input & Concatenate features
        let transformedInput = try pipeline.transformed(input: input, generateMetadata: false)
        let floatFeatures = try transformedInput.concatenatedFeatures(selectedFeatures: selectedFeatures)

        return try predict(input: floatFeatures, parallel: parallel)
    }

    public func predict(input: MatrixDataFloat, parallel: Bool = true) throws -> [PredictResult] {
        //Serial queue to serialize access to shared objects
        let serialQueue = DispatchQueue(label: "predict-serialqueue")

        //Pre Allocate result array
        let countOfLearners = learners.count
        var predictResults = [PredictResult](repeating: PredictResult(), count: countOfLearners)

        //Predict the different learners
        if parallel {
            //Execute each Learner in parallel
            var asyncCatched = false
            let _ = DispatchQueue.global(qos: .background)
            DispatchQueue.concurrentPerform(iterations: countOfLearners) { i in
                do {
                    let predictionResult = try predict(learnerPos: i, input: input, parallel: parallel)
                    serialQueue.sync { 
                        predictResults[i] = predictionResult
                    }
                }
                catch {
                    asyncCatched = true
                    print("Catch in Learner Predict")
                }
            }

            if asyncCatched {
                throw ClassifierError.CatchInParallelLearner
            }
        }
        else {
            for i in 0..<countOfLearners {
                predictResults[i] = try predict(learnerPos: i, input: input, parallel: parallel)
            }
        }

        return predictResults
    }

    private func predict(learnerPos: Int, input: MatrixDataFloat, parallel: Bool) throws -> PredictResult {
        //Serial queue to serialize access to shared objects
        let serialQueue = DispatchQueue(label: "predictBinary-serialqueue")

        //Check if learner support multiClass/multiLabel case as the original input training dataset
        if learners[learnerPos].info.multiClass == multiClass && learners[learnerPos].info.multiLabel == multiLabel {
            //Binary or multiClass|multiLabel learner
            return try learners[learnerPos].predict(modelData: modelDataArray[learnerPos][0], features: input)
        }
        else { //Manage MultiClass and MultiLabel using One-Vs-All approach
            //Prepare array of Binary Predict Results
            var binaryPredictResults = [PredictResult](repeating: PredictResult(), count: trainedLabels.count)

            //Train and Evaluate a Binary learner for each Label
            if parallel {
                //Execute each Label Learner in parallel
                var asyncCatched = false
                let _ = DispatchQueue.global(qos: .background)
                DispatchQueue.concurrentPerform(iterations: trainedLabels.count) { i in
                    do {
                        let predictionResult = try learners[learnerPos].predict(modelData: modelDataArray[learnerPos][i], features: input)
                        serialQueue.sync { 
                            binaryPredictResults[i] = predictionResult
                        }
                    }
                    catch {
                        asyncCatched = true
                        print("Catch in Label Learner Predict")
                    }
                }

                if asyncCatched {
                    throw ClassifierError.CatchInParallelLabelLearner
                }
            }
            else {
                for i in 0..<trainedLabels.count {
                    binaryPredictResults[i] = try learners[learnerPos].predict(modelData: modelDataArray[learnerPos][i], features: input)
                }
            }

            //Summirize Predict results from different Binary Learners
            var labels = [[Int]](repeating: [Int](), count: input.count)
            var confidences = [[Float]](repeating: [Float](), count: input.count)
            for resultPos in 0..<binaryPredictResults.count {
                for recordPos in 0..<input.count {
                    for labelPos in 0..<binaryPredictResults[resultPos].labels[recordPos].count {
                        if binaryPredictResults[resultPos].labels[recordPos][labelPos] == 1 && binaryPredictResults[resultPos].confidences[recordPos][labelPos] > binaryPredictionThreshold {
                            labels[recordPos].append(resultPos)
                            confidences[recordPos].append(binaryPredictResults[resultPos].confidences[recordPos][labelPos])
                        }
                    }
                }
            }

            return PredictResult(labels: labels, confidences: confidences)
        }
    }
}
