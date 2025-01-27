//
//  ColumnHeaderDataSetView.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import Foundation
import SwiftUI

struct ColumnHeaderDataSetView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Name")
                .frame(width: 150, alignment: .leading)
            Text("Type")
                .frame(width: 80, alignment: .leading)
        }
        .font(.headline)
    }
}

struct DataSetListItem: View {
    let dataSet: DataSetData
    @Binding var selectedDataSetId: String?
    
    var body: some View {
        Button(action: {
            selectedDataSetId = dataSet.id
        }) {
            HStack(spacing: 8) {
                // 1) DataSet Name
                Text(dataSet.name ?? "Unnamed DataSet")
                    .frame(width: 150, alignment: .leading)
                // 2) DataSet Type
                Text(dataSet.type ?? "")
                    .frame(width: 80, alignment: .leading)
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle()) // Make the entire row tappable
            .background(selectedDataSetId == dataSet.id ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DataSetDetailView: View {
    let dataSet: DataSetData
    let model: BOMModel
    @ObservedObject var settingsModel: ApplicationSettingsModel
    @State private var isDetailsExpanded = true
    @State private var isRevisionExpanded = false
    @State private var isFormAttributesExpanded = false
    @State private var isDatasetsExpanded = false
    var body: some View {
        ScrollView {
            HStack(spacing: 8) { // Small gap between buttons
                // Icon-only button
                Button(action: {
                    if let matchingSiteId = model.findMatchingSiteId(settingsModel: settingsModel) {
                        openTCAWC(urlString: matchingSiteId.tcURL, uid: dataSet.uid ?? "")
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
                .disabled(!(model.findMatchingSiteId(settingsModel: settingsModel) != nil && dataSet.uid != nil))
                .opacity((model.findMatchingSiteId(settingsModel: settingsModel) != nil && dataSet.uid != nil) ? 1 : 0.6)
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
            
            VStack(alignment: .leading, spacing: 8) {
                
                DisclosureGroup(isExpanded: $isDetailsExpanded) {
                    Group {
                        //                    Text("ID: \(dataSet.id)")
                        //                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Name: \(dataSet.name ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Type: \(dataSet.type ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Version: \(dataSet.version ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Associated Files Section
                        if !dataSet.memberRefs.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            
                            Text("Associated Files")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            ForEach(dataSet.memberRefs, id: \.self) { fileId in
                                if let ef = model.externalFilesDict[fileId] {
                                    HStack {
                                        if let path = ef.fullPath {
                                            FileRow(filePath: path)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.leading, 8)
                                                .font(.caption2)
                                        } else {
                                            Text("File: \(ef.locationRef ?? "-") [\(ef.format ?? "")]")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .font(.caption)
                                        }
                                    }
                                } else {
                                    Text("Unknown ExternalFile id=\(fileId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
