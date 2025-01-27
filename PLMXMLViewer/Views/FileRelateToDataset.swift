//
//  FileRow.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import Foundation
import SwiftUI

struct FileRow: View {
    let filePath: String   // e.g. "/Users/alex/PLMXMLStuff/SomePart.jt"
    
    var body: some View {
        // Use an HStack if you have other info or just a text by itself
        HStack {
            // The clickable, link-like text
            Text((filePath as NSString).lastPathComponent) // just the filename
                .foregroundColor(.blue)
                .underline()
            // 1) Make it open the file on left-click
                .onTapGesture {
                    openFile(at: filePath)
                }
            // 2) Add a context menu for right-click
                .contextMenu {
                    Button("Open File") {
                        openFile(at: filePath)
                    }
                    Button("Reveal in Finder") {
                        revealInFinder(filePath)
                    }
                    Button("Save As...") {
                        saveAs(filePath)
                    }
                }
        }
    }
    
    // MARK: - File Actions
    
    private func openFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)  // opens with default application
    }
    
    private func revealInFinder(_ path: String) {
        // Replace backslashes with forward slashes
        let sanitizedPath = path.replacingOccurrences(of: "\\", with: "/")
        let url = URL(fileURLWithPath: sanitizedPath)
        // Check if the file exists
        if FileManager.default.fileExists(atPath: url.path) {
            // Reveal the file in Finder
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            print("File does not exist at path: \(url.path)")
        }
    }
    
    private func saveAs(_ path: String) {
        // Replace backslashes with forward slashes
        //let sanitizedPath = path.replacingOccurrences(of: "\\", with: "/")
        
        // Create a URL from the sanitized path
        let sourceURL = URL(fileURLWithPath: sanitizedPath(path))
        
        // Sanitize the file name
        let sanitizedFileName = sanitizeFileName(sourceURL.lastPathComponent)
        
        // Check if the source file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("Source file does not exist at path: \(sourceURL.path)")
            return
        }
        
        let panel = NSSavePanel()
        panel.title = "Save File As..."
        panel.nameFieldStringValue = sanitizedFileName // Set only the file name
        panel.allowsOtherFileTypes = true
        
        panel.begin { response in
            if response == .OK, let destination = panel.url {
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                } catch {
                    print("Could not copy file: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct DataSetRow: View {
    let dataSet: DataSetData
    let model: BOMModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DataSet: \(dataSet.name ?? dataSet.id) [\(dataSet.type ?? "")]")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !dataSet.memberRefs.isEmpty {
                ForEach(dataSet.memberRefs, id: \.self) { fileId in
                    if let ef = model.externalFilesDict[fileId] {
                        // A row for the external file
                        HStack {
                            //                            Text("File: \(ef.locationRef ?? "-") [\(ef.format ?? "")]")
                            //                                .font(.caption)
                            //
                            // If we have a fullPath, show a button:
                            if let path = ef.fullPath {
                                FileRow(filePath: path)
                                    .padding(.leading, 8)
                                    .font(.caption2)
                                    .padding(.leading, 8)
                            }
                        }
                    } else {
                        Text("Unknown ExternalFile id=\(fileId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.leading, 8)
    }
    
    /// Attempt to open the file in Finder or the default application
    private func openFile(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
