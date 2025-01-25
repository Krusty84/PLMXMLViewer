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
    @Environment(\.dismiss) private var dismiss
    var highlightedSiteId: String?

    var body: some View {
        Form {
            Section(header: Text("Mapping: Teamcenter Site ID <-> Teamcenter AWC root URL")) {
                ScrollViewReader { proxy in
                    List {
                        ForEach($model.appSettings) { $setting in
                            HStack {
                                TextField("Site Id", text: $setting.tcSiteId)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 150)
                                    .background(
                                        highlightedSiteId == setting.tcSiteId ? Color.yellow.opacity(0.3) : Color.clear
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
                            .id(setting.id) // Assign a unique ID to each row
                        }
                        .onDelete(perform: deleteSettingsPairsRow)
                    }
                    .frame(minHeight: 200)
                    .listStyle(InsetListStyle())
                    .onAppear {
                        if let siteId = highlightedSiteId,
                           let setting = model.appSettings.first(where: { $0.tcSiteId == siteId }) {
                            // Scroll to the highlighted row
                            withAnimation {
                                proxy.scrollTo(setting.id, anchor: .center)
                            }
                        }
                    }
                }
            }
           
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
                        dismiss()
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
        .frame(minWidth: 600, minHeight: 400)
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
