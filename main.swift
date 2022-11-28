//
//  main.swift
//  OCRandDate
//
//  Created by Spencer Hong on 11/25/22.
//

import Cocoa
import Vision

enum LearningError: Error {
    case imageNotFound
}

struct DocumentData: Codable {
    let ID: String
    let Corpus: [String]
    let Dates: [DateRecord]
}

struct DateRecord: Codable {
    let date: String
    let duration: Double
}

struct nodeID {
    var nodeID: String
}

enum level {
    case fast, accurate
}

enum correct {
    case yes, no
}

class TextRequestManager {
    var request: VNRecognizeTextRequest!
    var outputPath: String
    var nodeID: String  = ""
    init(outputPath: String, recognitionLevel: level, languageCorrect: correct, customWords: [String] = []) {
        
        self.outputPath = outputPath
        var request = VNRecognizeTextRequest(completionHandler: self.recognizeTextHandler)
        
        
        switch recognitionLevel {
        case .fast:
            request.recognitionLevel = VNRequestTextRecognitionLevel.fast
        case .accurate:
            request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
            
        }
        
        switch languageCorrect {
        case .yes:
            request.usesLanguageCorrection = true
        case .no:
            request.usesLanguageCorrection = false
            
        }
        
        request.customWords = customWords
        self.request = request
    }
    
    func test(request: VNRequest, error: Error?) {
        
    }
    private func recognizeTextHandler(request: VNRequest, error: Error?) {
        
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        let recognizedStrings = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance.
            return observation.topCandidates(1).first?.string
        }
        
        self.processRequest(strings:recognizedStrings, nodeID: self.nodeID, outputPath: self.outputPath)
        
    }
    
    private func processRequest(strings:[String]?, nodeID: String, outputPath: String) {
        guard let strings = strings else {
            return
        }
        
        var allDates: [DateRecord] = []
        
        for string in strings {
            
            let range = NSRange(string.startIndex..<string.endIndex, in: string)
            detector.enumerateMatches(in: string,
                                      options: [],
                                      range: range) { (match, flags, _) in
                guard let match = match else {
                    return
                }
                
                switch match.resultType {
                case .date:
                    let date = match.date
                    let duration = match.duration
                    
                    if let date = date {
                        let dateRecord = DateRecord(date: dateFormatter.string(from: date), duration: duration)
                        
                        allDates.append(dateRecord)
                    }
                    
                default:
                    return
                }
            }
        }
        
        
        do {
            let encodedDictionary = try JSONEncoder().encode(DocumentData(ID: nodeID, Corpus: strings, Dates: allDates))
            
            let path = outputPath + nodeID + ".json"
            let pathAsURL = URL(fileURLWithPath: path)
            do {
                try encodedDictionary.write(to: pathAsURL)
            }
        } catch {
            print("Error: ", error)
        }
        
    }
    
    private func prepareImage(file: URL) throws -> CGImage {
        
        guard
            let image = NSImage(contentsOf: file),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                
        else {
            
            throw LearningError.imageNotFound
        }
        
        return cgImage
    }
    
    
    func recognizeText(file: URL) throws {
        
        self.nodeID = file.deletingPathExtension().lastPathComponent
        
        let cgImage = try prepareImage(file: file)
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        
        
        do {
            // Perform the text-recognition request.
            try requestHandler.perform([self.request])
        } catch {
            print("Unable to perform the requests: \(error).")
        }
        
    }
}

let detector = try NSDataDetector(types: NSTextCheckingAllTypes)

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "MM/dd/YYYY"

do {
    
    let manager = TextRequestManager(outputPath: "" ,//folder where you want to store outputs
        recognitionLevel: level.accurate, languageCorrect: correct.yes, customWords: ["ELSI", "NHGRI", "NCHGR", "NIH"])
    
    
    let corePath = "" // the input path with images to OCR
    let files = try FileManager.default.contentsOfDirectory(atPath: corePath)
    
    
    
    
    for fileIterator in 0 ..< files.count {
        print(fileIterator)
        
        
        try manager.recognizeText(file: URL(fileURLWithPath: corePath + "/" + files[fileIterator]))
        
    }
    
} catch {
    print(error)
}

