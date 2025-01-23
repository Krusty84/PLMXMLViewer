//
//  SiteSetting.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 22/01/2025.
//

// SiteSetting.swift
import Foundation
import SwiftUI

struct ApplicationSettings: Identifiable, Codable {
    let id = UUID() // Unique ID for each row
    var tcSiteId: String
    var tcAwcUrl: String
}

class ApplicationSettingsModel: ObservableObject {
    static let shared = ApplicationSettingsModel() // Singleton instance
    @Published var appSettings: [ApplicationSettings] = []
    private let appSettingsKey = "AppSettings"
    
    private init() { // Private to enforce singleton
        loadSettings()
    }
    
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: appSettingsKey),
           let decoded = try? JSONDecoder().decode([ApplicationSettings].self, from: data) {
            appSettings = decoded
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(appSettings) {
            UserDefaults.standard.set(encoded, forKey: appSettingsKey)
        }
    }

    func hasMatchingSiteId(_ siteId: String?) -> Bool {
        guard let siteId = siteId else { return false }
        return appSettings.contains { $0.tcSiteId == siteId }
    }
}


struct ApplicationSettingsView: View {
    @ObservedObject var model: ApplicationSettingsModel
    @Environment(\.dismiss) private var dismiss // Use dismiss to close the window

    var body: some View {
        Form {
            // Section for managing site settings
            Section(header: Text("Mapping: Teamcenter Site ID <-> Teamcenter AWC root URL")) {
                List {
                    ForEach($model.appSettings) { $setting in
                        HStack {
                            TextField("Site Id", text: $setting.tcSiteId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 150)
                            TextField("TC AWC URL", text: $setting.tcAwcUrl)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 300)

                            Button(action: {
                                deleteSettingsPairsRow(with: setting.id)
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Delete this setting")
                        }
                    }
                    .onDelete(perform: deleteSettingsPairsRow) // Enable swipe-to-delete
                }
                .frame(minHeight: 200)
                .listStyle(InsetListStyle())
            }
           
            // Section for action buttons
            Section {
                HStack {
                    Button(action: addSettingsPairsRow) {
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
    private func addSettingsPairsRow() {
        model.appSettings.append(ApplicationSettings(tcSiteId: "", tcAwcUrl: ""))
    }

    // Delete a row using IndexSet (for swipe-to-delete)
    private func deleteSettingsPairsRow(at offsets: IndexSet) {
        model.appSettings.remove(atOffsets: offsets)
    }

    // Delete a row using UUID (for the delete button)
    private func deleteSettingsPairsRow(with id: UUID) {
        if let index = model.appSettings.firstIndex(where: { $0.id == id }) {
            model.appSettings.remove(at: index)
        }
    }
}
