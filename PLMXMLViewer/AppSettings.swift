//
//  SiteSetting.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 22/01/2025.
//

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
    @Environment(\.dismiss) private var dismiss
    @Binding var highlightedSiteId: String?

    // Default initializer with highlightedSiteId as nil
    init(model: ApplicationSettingsModel, highlightedSiteId: Binding<String?>? = nil) {
        self.model = model
        self._highlightedSiteId = highlightedSiteId ?? .constant(nil)
    }

    var body: some View {
        Form {
            Section(header: Text("Mapping: Teamcenter Site ID <-> Teamcenter AWC root URL")) {
                List {
                    ForEach($model.appSettings) { $setting in
                        HStack {
                            TextField("Site Id", text: $setting.tcSiteId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 150)
                                .background(
                                    highlightedSiteId != nil && highlightedSiteId == setting.tcSiteId ? Color.yellow.opacity(0.3) : Color.clear
                                )
                                .cornerRadius(4)
                                .overlay(
                                    highlightedSiteId != nil && highlightedSiteId == setting.tcSiteId ? RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.orange, lineWidth: 2) : nil
                                )
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
                        .onAppear {
                            if highlightedSiteId == setting.tcSiteId {
                                print("Highlighted Site Id: \(setting.tcSiteId)")
                            }
                        }
                    }
                    .onDelete(perform: deleteSettingsPairsRow)
                }
                .frame(minHeight: 200)
                .listStyle(InsetListStyle())
            }
           
            Section {
                HStack {
                    Button(action: {
                        addSettingsPairsRow() // Calls the function without arguments
                    }) {
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
                        dismiss()
                    }
                    .help("Close this window")
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .onAppear {
            print("SettingsView appeared with highlightedSiteId: \(highlightedSiteId ?? "nil")")
            // Add a new row if highlightedSiteId is not already in the settings
            if let highlightedSiteId = highlightedSiteId,
               !model.appSettings.contains(where: { $0.tcSiteId == highlightedSiteId }) {
                addSettingsPairsRow(with: highlightedSiteId)
            }
        }
        .onDisappear {
            model.saveSettings()
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // Add a new row to the site settings with a pre-filled Site Id
    private func addSettingsPairsRow(with siteId: String? = nil) {
        let newSetting = ApplicationSettings(tcSiteId: siteId ?? "", tcAwcUrl: "")
        model.appSettings.append(newSetting)
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
