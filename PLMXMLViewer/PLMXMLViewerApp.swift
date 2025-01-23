import SwiftUI

@main
struct PLMXMLViewerApp: App {
    @StateObject private var model = BOMModel()
    @StateObject private var settingsModel = SettingsModel.shared
    
    var body: some Scene {
        // Main Window
        WindowGroup {
            BOMView(model: model, settingsModel: settingsModel)
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
                        print("No log file available.")
                    }
                }
            }
//            CommandGroup(replacing: .appSettings) {
//                SettingsLink() // Use SettingsLink for the "Settings" menu item
//                    .keyboardShortcut(",", modifiers: [.command])
//            }
        }
        
        // Settings Window
        Settings {
            SettingsView(model: settingsModel)
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
