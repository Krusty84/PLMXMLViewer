//
//  PLMXMLViewerApp.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 16/01/2025.
//

import SwiftUI

@main
struct PLMXMLViewerApp: App {
    @StateObject private var model = BOMModel()
      var body: some Scene {
          WindowGroup {
              BOMView(model: model)    // Whenever lastOpenedFileName changes, update the macOS window title.
                  .onChange(of: model.lastOpenedFileName) { newFileName in
                      if let keyWindow = NSApp.keyWindow {
                          keyWindow.title = "PLMXMLViewer: \(newFileName)"
                      }
                  }
          }
          .commands {
              CommandGroup(after: .newItem) {
                  Button("Open...") {
                      openPLMXMLFile()
                  }
                  .keyboardShortcut("o", modifiers: [.command])
              }
              CommandGroup(replacing: .help) {
                  Button("Open log file") {
                      if let logURL = model.logFileURL {
                          NSWorkspace.shared.open(logURL)
                      } else {
                          // Optionally handle absence of a log file
                          print("No log file available.")
                      }
                  }
              }
          }
      }
      
      private func openPLMXMLFile() {
          let panel = NSOpenPanel()
          panel.title = "Open PLMXML File"
          panel.canChooseFiles = true
          panel.canChooseDirectories = false
          panel.allowsMultipleSelection = false
          panel.allowedFileTypes = ["xml", "plmxml"]
          
          panel.begin { response in
              guard response == .OK, let url = panel.url else { return }
              
              do {
                  let data = try Data(contentsOf: url)
                  let plmxmlDirectory = url.deletingLastPathComponent()
                  // Pass the file name to BOMModel
                  model.loadPLMXML(from: data, fileName: url.lastPathComponent,plmxmlDirectory: plmxmlDirectory)
              } catch {
                  print("Failed to read file: \(error)")
              }
          }
      }
  }
