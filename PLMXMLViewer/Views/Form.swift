//
//  ColumnHeaderFormView.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import Foundation
import SwiftUI

struct ColumnHeaderFormView: View {
    var body: some View {
        HStack(spacing: 8) {
            //  Text("Form ID").frame(width: 150, alignment: .leading)
            Text("Name")
                .frame(width: 150, alignment: .leading)
            Text("Type")
                .frame(width: 80, alignment: .leading)
        }
        .font(.headline)
    }
}

struct FormListItem: View {
    let form: FormData
    @Binding var selectedFormId: String?
    
    var body: some View {
        Button(action: {
            selectedFormId = form.id
        }) {
            HStack(spacing: 8) {
                // 1) Form ID
                //                Text(form.id)
                //                    .frame(width: 150, alignment: .leading)
                // 2) Form Name
                Text(form.name ?? "Unnamed Form")
                    .frame(width: 150, alignment: .leading)
                // 3) Form SubType
                Text(form.subType ?? "")
                    .frame(width: 80, alignment: .leading)
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle()) // Make the entire row tappable
            .background(selectedFormId == form.id ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FormDetailView: View {
    let form: FormData
    let model: BOMModel
    @ObservedObject var settingsModel: ApplicationSettingsModel
    @State private var isDetailsExpanded = true
    var body: some View {
        ScrollView {
            HStack(spacing: 8) { // Small gap between buttons
                    // Icon-only button
                    Button(action: {
                        if let matchingSiteId = model.findMatchingSiteId(settingsModel: settingsModel) {
                            openTCAWC(urlString: matchingSiteId.tcURL, uid: form.uid ?? "")
                        }
                    }) {
                        Image(systemName: "arrow.up.right.square") // SF Symbol for external link
                            .frame(width: 18, height: 18)
                            .font(.system(size: 18, weight: .medium))
                            .padding(10)
                            //.background(.white)
                            //.foregroundColor(.white)
                            //.cornerRadius(8)
                            //.shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .disabled(!(model.findMatchingSiteId(settingsModel: settingsModel) != nil && form.uid != nil))
                    .opacity((model.findMatchingSiteId(settingsModel: settingsModel) != nil && form.uid != nil) ? 1 : 0.6)
                    .help("Go to source Teamcenter") // Tooltip

                    // Stub button (placeholder for future functionality)
                    Button(action: {
                        // Placeholder action
                        print("#")
                    }) {
                        Image(systemName: "questionmark.circle") // SF Symbol for stub button
                            .frame(width: 18, height: 18)
                            .font(.system(size: 18, weight: .medium))
                            .padding(10)
                            //.background(.white)
                            //.foregroundColor(.white)
                            //.cornerRadius(8)
                    }
                    .disabled(true)
                    .help("This button is a placeholder for future functionality") // Tooltip
                    
                    // Stub button (placeholder for future functionality)
                    Button(action: {
                        // Placeholder action
                        print("#")
                    }) {
                        Image(systemName: "questionmark.circle") // SF Symbol for stub button
                            .frame(width: 18, height: 18)
                            .font(.system(size: 18, weight: .medium))
                            .padding(10)
                            //.background(.white)
                            //.foregroundColor(.white)
                            //.cornerRadius(8)
                    }
                    .disabled(true)
                    .help("This button is a placeholder for future functionality") // Tooltip
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Align buttons to the left
                .padding(.top, 8) // Add padding at the top
                .padding(.leading, 16) // Add left padding to align with other content
                //
                Divider()
                //
            VStack(alignment: .leading, spacing: 8) {
                // Form Details Section
                DisclosureGroup(isExpanded: $isDetailsExpanded) {
                    Group {
                        Text("Name: \(form.name ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Type: \(form.subType ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Class: \(form.subClass ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Associated Files Section
                        if !form.userAttributes.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            
                            Text("Form Attributes")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            ForEach(Array(form.userAttributes.keys.sorted()), id: \.self) { key in
                                if let value = form.userAttributes[key], !value.isEmpty {
                                    HStack {
                                        Text("\(key):")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(value)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }label: {
                    Text("Details")
                        .font(.headline)
                    //.padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    //.background(Color.orange.opacity(100))
                        .background(Color(nsColor: .windowBackgroundColor))
                    //.cornerRadius(8)
                        .onTapGesture {
                            withAnimation {
                                isDetailsExpanded.toggle()
                            }
                        }
                }.padding(.bottom, 8)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
