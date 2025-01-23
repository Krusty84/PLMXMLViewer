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
    //@StateObject private var settingsModel = SettingsModel()
    @StateObject private var settingsModel = SettingsModel.shared
    @State private var isShowingSettings = false
    
    var body: some Scene {
        WindowGroup {
            BOMView(model: model)
                .onChange(of: model.lastOpenedFileName) { newFileName in
                    if let keyWindow = NSApp.keyWindow {
                        keyWindow.title = "PLMXMLViewer: \(newFileName)"
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView(model: settingsModel)
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
                        print("No log file available.")
                    }
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    isShowingSettings = true
                }
                .keyboardShortcut(",", modifiers: [.command])
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
                model.loadPLMXML(from: data, fileName: url.lastPathComponent, plmxmlDirectory: plmxmlDirectory)
            } catch {
                print("Failed to read file: \(error)")
            }
        }
    }
}

