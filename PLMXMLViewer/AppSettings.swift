//
//  SiteSetting.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 22/01/2025.
//
import SwiftUI
import Foundation

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
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.presentationMode) var presentationMode // For closing the sheet

    var body: some View {
        VStack {
            // Title
            Text("Settings")
                .font(.title2)
                .padding(.top)

            // List of settings
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
            }
            .frame(minHeight: 300)
            .listStyle(InsetListStyle())

            // Action buttons
            HStack {
                Button(action: addRow) {
                    Label("Add Setting", systemImage: "plus.circle")
                }
                .help("Add a new setting row")

                Spacer()

                Button("Save") {
                    model.saveSettings()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .help("Save changes")

                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .help("Close this window")
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .onDisappear {
            model.saveSettings()
        }
        .frame(width: 600, height: 400) // Adjust size as needed
    }

    private func addRow() {
        model.siteSettings.append(SiteSettings(siteId: "", tcURL: ""))
    }

    private func deleteRow(with id: UUID) {
        if let index = model.siteSettings.firstIndex(where: { $0.id == id }) {
            model.siteSettings.remove(at: index)
        }
    }
}
