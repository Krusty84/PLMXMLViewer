import SwiftUI

@main
struct PLMXMLViewerApp: App {
    @StateObject private var model = BOMModel()
    @StateObject private var settingsModel = ApplicationSettingsModel.shared
    
    var body: some Scene {
        // Main Window
        WindowGroup {
            BOMView(model: model, settingsModel: settingsModel)
                .onChange(of: model.lastOpenedFileName) { newFileName in
                    if let keyWindow = NSApp.keyWindow {
                        keyWindow.title = "PLMXMLViewer: \(newFileName)"
                    }
                }
                .frame(minHeight: 400)
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
            ApplicationSettingsView(model: settingsModel)
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
                // Convert raw XML bytes into a String:
                let rawXML = String(data: data, encoding: .utf8) ?? "Failed to decode as UTF-8"
                
                let plmxmlDirectory = url.deletingLastPathComponent()
                
                // 1) Store it in your model so you can show it in a CodeEditor or TextEditor:
                model.rawPLMXML = rawXML
                
                // 2) Then parse as usual:
                model.loadPLMXML(
                    from: data,
                    fileName: url.lastPathComponent,
                    plmxmlDirectory: plmxmlDirectory
                )
            } catch {
                print("Failed to read file: \(error)")
            }
        }
    }

}
