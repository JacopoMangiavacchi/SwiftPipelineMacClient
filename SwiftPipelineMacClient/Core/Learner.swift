//
//  Learner.swift
//  TransformationPipeline
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 JacopoMangia. All rights reserved.
//

import Foundation

// Learner basic info used for Learner pipeline persistence
public struct LearnerInfo : Codable {
    public let name: DataString
    public let type: DataString
    public let multiClass: Bool
    public let multiLabel: Bool
    
    public init(name: DataString, type: Any, multiClass: Bool, multiLabel: Bool) {
        self.name = name
        self.type = "\(type)"
        self.multiClass = multiClass
        self.multiLabel = multiLabel
    }
}

// Learner Train Result info
public struct TrainResult : Codable {
    public let cost: Float
    public let euclideanDistance: Float
    public let f1: Float
    public let microAvgAccuracy: Float
    public let macroAvgAccuracy: Float
    public let precision: [Float]
    public let recall: [Float]

    public init() {
        cost = 0.0
        euclideanDistance = 0.0
        f1 = 0.0
        microAvgAccuracy = 0.0
        macroAvgAccuracy = 0.0
        precision = [Float]()
        recall = [Float]()
    }

    public init(cost: Float, euclideanDistance: Float, f1: Float, microAvgAccuracy: Float, macroAvgAccuracy: Float, precision: [Float], recall: [Float]) {
        self.cost = cost
        self.euclideanDistance = euclideanDistance
        self.f1 = f1
        self.microAvgAccuracy = microAvgAccuracy
        self.macroAvgAccuracy = macroAvgAccuracy
        self.precision = precision
        self.recall = recall
    }

    public init(f1: Float, microAvgAccuracy: Float, macroAvgAccuracy: Float, precision: [Float], recall: [Float]) {
        self.cost = 0.0
        self.euclideanDistance = 0.0
        self.f1 = f1
        self.microAvgAccuracy = microAvgAccuracy
        self.macroAvgAccuracy = macroAvgAccuracy
        self.precision = precision
        self.recall = recall
    }

    public init(cost: Float, euclideanDistance: Float) {
        self.cost = cost
        self.euclideanDistance = euclideanDistance
        self.f1 = 0.0
        self.microAvgAccuracy = 0.0
        self.macroAvgAccuracy = 0.0
        self.precision = [Float]()
        self.recall = [Float]()
    }
}

// Learner Predict Result info
public struct PredictResult : Codable {
    public let labels: [[Int]]
    public let confidences: [[Float]]

    public init() {
        labels = [[Int]]()
        confidences = [[Float]]()
    }

    public init(labels: [[Int]], confidences: [[Float]]) {
        self.labels = labels
        self.confidences = confidences
    }
}

// Learner interface for generic Classifier
public protocol LearnerProtocol {
    var info: LearnerInfo { get }
    
    init(name: DataString)

    func train(trainFeatures: MatrixDataFloat, testFeatures: MatrixDataFloat, trainLabels: [[Int]], testLabels: [[Int]]) throws -> (trainResult: TrainResult, modelData: Data)
    func predict(modelData: Data, features: MatrixDataFloat) throws -> PredictResult
}
