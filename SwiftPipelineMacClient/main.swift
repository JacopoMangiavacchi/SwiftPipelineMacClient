//
//  main.swift
//  SwiftPipelineMacClient
//
//  Created by Jacopo Mangiavacchi on 2018.
//  Copyright © 2018 Jacopo Mangiavacchi. All rights reserved.
//

import Foundation
import Cocoa
import CreateML
import CoreML

struct SemEval : Codable {
    let text: String
    let label: String
}

let url = URL(fileURLWithPath: "/Users/jacopo/SwiftPipelineMacClient/SwiftPipelineMacClient/semeval.json")
let semevalData = try! Data(contentsOf: url)
var semevalDictionary = try! JSONDecoder().decode(Array<SemEval>.self, from: semevalData)

//semevalDictionary = semevalDictionary.filter{ $0.label != "neutral" }

let data = semevalDictionary.map{$0.text}
let labels = semevalDictionary.map{$0.label}

let pipeline = Pipeline(transformers: [//FastText(fastTextModelPath: "/Jacopo/fastText/model.bin"),
    //                                        MultiRegex(regexValues: ["\\$\\ ?[+-]?[0-9]{1,3}(?:,?[0-9])*(?:\\.[0-9]{1,2})?"]),
                                            Tokenizer(separators: " .,!?-", stopWords: ["text", "like"]),
                                            BOW(name: "Words"),
    //                                        BOW(name: "WordGrams3", keyType: .WordGram, ngramLength: 3, valueType: .TFIDF(minCount: 1)),
    //                                        BOW(name: "CharGrams5", keyType: .CharGram, ngramLength: 5, valueType: .TFIDF(minCount: 2)),
                                            BOW(name: "HashWords", keyType: .CharGram, ngramLength: 4, valueType: .HashingTrick(algorithm: .DJB2, vectorSize: 5000)),
                                            BOW(name: "HashWords", keyType: .WordGram, ngramLength: 1, valueType: .HashingTrick(algorithm: .DJB2, vectorSize: 800)),
    //                                        MultiDictionary(words: ["long", "big"]),
    //                                        BinaryDictionary(words: ["long", "big"]),
                                      ],
                        splitRate: 0.3,
                        minNumberOfRowInSplit: 3)


//TRAIN
let features = try! pipeline.transformed(input: data)
print("OK")

//let features = try! pipeline.transformed(input: data).concatenatedFeatures()
//let dataCount = features.count
//let featuresCount = features[0].count
//let labelCount = labels.count
//
//var featureArray = [[Double]](repeating: [Double](), count: featuresCount)
//
//for dc in 0..<dataCount {
//    for f in 0..<featuresCount {
//        featureArray[f].append(Double(features[dc][f]))
//    }
//}
//
//var dictionary = [String : MLDataValueConvertible]()
//dictionary["labels"] = labels
//
//for f in 0..<featuresCount {
//    dictionary[String(f)] = featureArray[f]
//}
//
//let table = try! MLDataTable(dictionary: dictionary)
//let classifier = try! MLLogisticRegressionClassifier(trainingData: table, targetColumn: "labels")
//
//
//let model = classifier.model
//
//
////PREDICT //TODO: Check MLArrayBatchProvider
//func predict(predictionText: String) {
//    let predictionfeatures = try! pipeline.transformed(input: [predictionText]).concatenatedFeatures()
//    var predictionDictionary = [String : Any]()
//    for f in 0..<featuresCount {
//        predictionDictionary[String(f)] = Double(predictionfeatures[0][f])
//    }
//
//    let predictions = try! model.prediction(from: MLDictionaryFeatureProvider(dictionary: predictionDictionary))
//
//    //print(predictions.featureNames)
//    print(predictions.featureValue(for: "labels")!)
//    print(predictions.featureValue(for: "labelsProbability")!)
//}
//
//predict(predictionText: "I hate driving in the traffic")
//predict(predictionText: "I love go to the cinema")
//predict(predictionText: "fuck you asshole")
//predict(predictionText: "so cute lovely")



// ------------------------



//var classifier = Classifier(pipeline: pipeline,
//                            learners: [LogisticRegressionLearner()],
//                            splitTest: 0.1)
//
////TRAINING
//try! classifier.train(input: data, labels: labels)
//print(classifier.trainResults)
//
//
////SCORING
////print(try! classifier.predict(input: data).map{$0.confidences})
//print(try! classifier.predict(input: ["today is really a beautiful day to go to the sea"]).map{$0.confidences})
//print(try! classifier.predict(input: ["Should be great to watch a movie at the cinema"]).map{$0.confidences})
//print(try! classifier.predict(input: ["I hate work till late"]).map{$0.confidences})
//print(try! classifier.predict(input: ["you're really an idiot"]).map{$0.confidences})

