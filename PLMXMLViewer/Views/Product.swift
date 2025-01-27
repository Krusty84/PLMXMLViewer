//
//  ColumnHeaderProductView.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import Foundation
import SwiftUI

struct ColumnHeaderProductView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Item Id")
                .frame(width: 150, alignment: .leading) // Use .leading
            
            Text("Name")
                .frame(width: 150, alignment: .leading) // Use .leading
            
            Text("Type")
                .frame(width: 80, alignment: .leading) // Use .leading
            // .padding(.vertical, 4)
        }.font(.headline)
    }
}

struct ProductListItem: View {
    let product: ProductData
    @Binding var selectedProductId: String?
    
    var body: some View {
        Button(action: {
            selectedProductId = product.id
        }) {
            HStack(spacing: 8) {
                // 1) Product Id
                Text(product.productId ?? "No ID")
                    .frame(width: 150, alignment: .leading)
                // 2) Product ID
                Text(product.name ?? "Unnamed Product")
                    .frame(width: 150, alignment: .leading)
                // 3) SubType
                Text(product.subType ?? "")
                    .frame(width: 80, alignment: .leading)
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle()) // Make the entire row tappable
            .background(selectedProductId == product.id ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProductDetailView: View {
    let product: ProductData
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
                            openTCAWC(urlString: matchingSiteId.tcURL, uid: product.uid ?? "")
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
                    .disabled(!(model.findMatchingSiteId(settingsModel: settingsModel) != nil && product.uid != nil))
                    .opacity((model.findMatchingSiteId(settingsModel: settingsModel) != nil && product.uid != nil) ? 1 : 0.6)
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
                // Product Details Section
                DisclosureGroup(isExpanded: $isDetailsExpanded) {
                    Group {
                        //                    Text("ID: \(product.id)")
                        //                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Item Id: \(product.productId ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Name: \(product.name ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Type: \(product.subType ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } label: {
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
                            
                // Associated Product Revisions Section
                let revisions = model.productRevisionsDict.values.filter { $0.masterRef == product.id }
                if !revisions.isEmpty {
                    DisclosureGroup(isExpanded: $isRevisionExpanded) {
                        Group {
                            ForEach(revisions) { revision in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Revision: \(revision.revision ?? "-")")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Name: \(revision.name ?? "-")")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Type: \(revision.subType ?? "-")")
                                    Text("Last Modified: \(revision.lastModDate ?? "-")")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // Revision Attributes Section (only if userAttributes has valid data)
                                    if !revision.userAttributes.isEmpty && revision.userAttributes.values.contains(where: { !$0.isEmpty }) {
                                        Divider()
                                            .padding(.vertical, 4)
                                        
                                        Text("Revision Attributes")
                                            .font(.headline)
                                        
                                        ForEach(Array(revision.userAttributes.keys.sorted()), id: \.self) { key in
                                            if let value = revision.userAttributes[key], !value.isEmpty {
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
                                .padding(.vertical, 4)
                            }
                        }
                        
                    }label: {
                        Text("Associated Revisions")
                            .font(.headline)
                        //.padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        //.background(Color.orange.opacity(100))
                            .background(Color(nsColor: .windowBackgroundColor))
                        //.cornerRadius(8)
                            .onTapGesture {
                                withAnimation {
                                    isRevisionExpanded.toggle()
                                }
                            }
                    }.padding(.bottom, 8)
                
      
                }
                
                // Associated DataSets Section
                let dataSetRefs = revisions.flatMap { $0.dataSetRefs }
                if !dataSetRefs.isEmpty {
                    DisclosureGroup(isExpanded: $isDatasetsExpanded) {
                        Group {
                            ForEach(dataSetRefs, id: \.self) { dsId in
                                if let ds = model.dataSetsDict[dsId] {
                                    DataSetRow(dataSet: ds, model: model)
                                } else {
                                    Text("- Unknown DataSet id=\(dsId)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }label: {
                        Text("Associated Datsets")
                            .font(.headline)
                        //.padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        //.background(Color.orange.opacity(100))
                            .background(Color(nsColor: .windowBackgroundColor))
                        //.cornerRadius(8)
                            .onTapGesture {
                                withAnimation {
                                    isDatasetsExpanded.toggle()
                                }
                            }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
