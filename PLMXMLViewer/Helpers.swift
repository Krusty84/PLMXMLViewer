//
//  Helpers.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 19/01/2025.
//

import Foundation

class Logger {
    static let shared = Logger()
    
    private let logFileName = "PLMXMLViewer.log"
    var logFileURL: URL?
    
    private init() {
        setupLogFile()
    }
    
    private func setupLogFile() {
        // Get the application's executable directory
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "PLMXMLViewer"
            let appDirectory = appSupportURL.appendingPathComponent(appName)
            
            // Create the directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: appDirectory.path) {
                do {
                    try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create application support directory: \(error)")
                    return
                }
            }
            
            // Set the log file URL
            logFileURL = appDirectory.appendingPathComponent(logFileName)
        }
    }
    
    func log(_ message: String) {
        guard let logFileURL = logFileURL else {
            print("Log file URL is not set.")
            return
        }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Write to the log file
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                do {
                    try data.write(to: logFileURL, options: .atomic)
                } catch {
                    print("Failed to write to log file: \(error)")
                }
            }
        }
    }
    
    func clearLog() {
        guard let logFileURL = logFileURL else { return }
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            do {
                try FileManager.default.removeItem(at: logFileURL)
            } catch {
                print("Failed to clear log file: \(error)")
            }
        }
    }
}

public func sanitizeFileName(_ fileName: String) -> String {
    // Replace backslashes and other invalid characters with underscores
    let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
    return fileName.components(separatedBy: invalidCharacters).joined(separator: "_")
}

public func sanitizedPath (_ path:String) -> String {
    return path.replacingOccurrences(of: "\\", with: "/")
}

extension ProductView.Occurrence: Equatable {
    static func == (lhs: ProductView.Occurrence, rhs: ProductView.Occurrence) -> Bool {
        // Compare the properties that make two occurrences equal
        return lhs.id == rhs.id // Assuming `id` is a unique identifier for the occurrence
    }
}
