//
//  SiteSetting.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 22/01/2025.
//

// SiteSetting.swift
import Foundation
import SwiftUI

struct SiteSettings: Identifiable, Codable {
    let id = UUID() // Unique ID for each row
    var siteId: String
    var tcURL: String
}

class SettingsModel: ObservableObject {
    static let shared = SettingsModel() // Singleton instance
    @Published var siteSettings: [SiteSettings] = []
    private let settingsKey = "SiteSettings"
    
    private init() { // Private to enforce singleton
        loadSettings()
    }
    
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode([SiteSettings].self, from: data) {
            siteSettings = decoded
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(siteSettings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    func hasMatchingSiteId(_ siteId: String?) -> Bool {
        print("SiteID inputed: ", siteId)
        guard let siteId = siteId else { return false }
        return siteSettings.contains { $0.siteId == siteId }
    }
}


struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.dismiss) private var dismiss // Use dismiss to close the window

    var body: some View {
        Form {
            // Section for managing site settings
            Section(header: Text("Site Settings")) {
                List {
                    ForEach($model.siteSettings) { $setting in
                        HStack {
                            TextField("Site Id", text: $setting.siteId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 150)
                            TextField("Tc URL", text: $setting.tcURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 300)

                            Button(action: {
                                deleteRow(with: setting.id)
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Delete this setting")
                        }
                    }
                    .onDelete(perform: deleteRow) // Enable swipe-to-delete
                }
                .frame(minHeight: 200)
                .listStyle(InsetListStyle())
            }

            // Section for action buttons
            Section {
                HStack {
                    Button(action: addRow) {
                        Label("Add Setting", systemImage: "plus.circle")
                    }
                    .help("Add a new setting row")

                    Spacer()

                    Button("Save Changes") {
                        model.saveSettings()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                    .help("Save changes")

                    Button("Close") {
                        dismiss() // Close the window
                    }
                    .help("Close this window")
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .onDisappear {
            model.saveSettings()
        }
        .frame(minWidth: 600, minHeight: 400) // Adjust size as needed
    }

    // Add a new row to the site settings
    private func addRow() {
        model.siteSettings.append(SiteSettings(siteId: "", tcURL: ""))
    }

    // Delete a row using IndexSet (for swipe-to-delete)
    private func deleteRow(at offsets: IndexSet) {
        model.siteSettings.remove(atOffsets: offsets)
    }

    // Delete a row using UUID (for the delete button)
    private func deleteRow(with id: UUID) {
        if let index = model.siteSettings.firstIndex(where: { $0.id == id }) {
            model.siteSettings.remove(at: index)
        }
    }
}
