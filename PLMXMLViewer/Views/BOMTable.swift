//
//  ColumnHeaderOccurrenceView.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import Foundation
import SwiftUI

struct ColumnHeaderOccurrenceView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Item Id")
                .frame(width: 150, alignment: .leading) // Use .leading
            
            Text("Name")
                .frame(width: 150, alignment: .leading) // Use .leading
            
            Text("Type")
                .frame(width: 80, alignment: .leading) // Use .leading
            
            Text("Rev")
                .frame(width: 30, alignment: .leading) // Use .leading
            
            Text("LastMod")
                .frame(width: 170, alignment: .leading) // Use .leading
            
            Text("Seq#")
                .frame(width: 50, alignment: .leading) // Use .leading
            
            Text("Quantity")
                .frame(width: 60, alignment: .leading) // Use .leading
        }
        .font(.headline)
        // .padding(.vertical, 4)
    }
}

struct OccurrenceListItem: View {
    let occurrence: ProductView.Occurrence
    @Binding var selectedOccurrence: ProductView.Occurrence?
    
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Recursively show children
            ForEach(occurrence.subOccurrences) { child in
                OccurrenceListItem(occurrence: child, selectedOccurrence: $selectedOccurrence)
                //.padding(.leading, 16)
            }
        } label: {
            Button(action: {
                selectedOccurrence = occurrence
            }) {
                HStack(spacing: 8) { // Add spacing between columns
                    // 6) ProductId
                    Text(occurrence.productId ?? "")
                        .frame(width: 150, alignment: .leading)
                    //.foregroundColor(.purple)
                    
                    // 1) DisplayName
                    Text(occurrence.displayName ?? occurrence.id)
                        .frame(width: 150, alignment: .leading)
                    
                    // 2) subType
                    Text(occurrence.subType ?? "")
                        .frame(width: 80, alignment: .leading)
                    
                    // 3) revision
                    Text(occurrence.revision ?? "")
                        .frame(width: 30, alignment: .leading)
                    
                    // 4) last_mod_date
                    Text(occurrence.lastModDate ?? "")
                        .frame(width: 170, alignment: .leading)
                    
                    // 5) SequenceNumber
                    Text(occurrence.sequenceNumber ?? "")
                        .frame(width: 50, alignment: .leading)
                    //.foregroundColor(.blue)
                    
                    // 7) Quantity
                    Text(occurrence.quantity ?? "")
                        .frame(width: 60, alignment: .leading)
                    //.foregroundColor(.orange)
                }
                .foregroundColor(.primary)
                .background(selectedOccurrence == occurrence ? Color.blue.opacity(0.1) : Color.clear)
                .contentShape(Rectangle()) // Make the entire row tappable
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}


struct OccurrenceDetailView: View {
    let occurrence: ProductView.Occurrence
    let model: BOMModel
    @ObservedObject var settingsModel: ApplicationSettingsModel
    @State private var isDetailsExpanded = true
    @State private var isRevisionAttributesExpanded = false
    @State private var isFormAttributesExpanded = false
    @State private var isDatasetsExpanded = false
    
    var body: some View {
        ScrollView {
            HStack(spacing: 8) { // Small gap between buttons
                // Icon-only button
                Button(action: {
                    if let matchingSite = model.findMatchingSiteId(settingsModel: settingsModel),
                       let instancedRef = occurrence.instancedRef,
                       let productRevision = model.productRevisionsDict[instancedRef] {
                        openTCAWC(urlString: matchingSite.tcURL, uid: productRevision.revisionUid ?? "")
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
                .disabled(!(model.findMatchingSiteId(settingsModel: settingsModel) != nil && occurrence.instancedRef != nil && model.productRevisionsDict[occurrence.instancedRef!] != nil))
                .opacity((model.findMatchingSiteId(settingsModel: settingsModel) != nil && occurrence.instancedRef != nil && model.productRevisionsDict[occurrence.instancedRef!] != nil) ? 1 : 0.6)
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
                // Details Section (expanded by default)
                DisclosureGroup(isExpanded: $isDetailsExpanded) {
                    Group {
                        //                        Text("ID: \(occurrence.id)")
                        //                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Item Id: \(occurrence.productId ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Revision: \(occurrence.revision ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Name: \(occurrence.name ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        //                        Text("DisplayName: \(occurrence.displayName ?? "-")")
                        //                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Type: \(occurrence.subType ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("LastModDate: \(occurrence.lastModDate ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("SequenceNumber: \(occurrence.sequenceNumber ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Quantity: \(occurrence.quantity ?? "-")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Child Occurrences: \(occurrence.subOccurrences.count)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
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
                }
                .padding(.bottom, 8)
                // Revision Attributes Section
                if let instancedRef = occurrence.instancedRef,
                   let productRevision = model.productRevisionsDict[instancedRef] {
                    let validAttributes = productRevision.userAttributes.filter { !$0.value.isEmpty }
                    if !validAttributes.isEmpty {
                        DisclosureGroup(isExpanded: $isRevisionAttributesExpanded) {
                            ForEach(Array(validAttributes.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text("\(key):")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(validAttributes[key] ?? "-")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } label: {
                            Text("Revision Attributes")
                                .font(.headline)
                            //.padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            //.background(Color.orange.opacity(100))
                                .background(Color(nsColor: .windowBackgroundColor))
                            //.cornerRadius(8)
                                .onTapGesture {
                                    withAnimation {
                                        isRevisionAttributesExpanded.toggle()
                                    }
                                }
                        }
                        .padding(.bottom, 8)
                    }
                }
                
                // Form Attributes Section
                if !occurrence.associatedAttachmentRefs.isEmpty {
                    DisclosureGroup(isExpanded: $isFormAttributesExpanded) {
                        ForEach(occurrence.associatedAttachmentRefs, id: \.self) { attachmentRef in
                            // Clean the attachmentRef (remove '#' prefix)
                            let cleanedAttachmentRef = attachmentRef.hasPrefix("#") ? String(attachmentRef.dropFirst()) : attachmentRef
                            
                            // Look up the AssociatedAttachment
                            if let attachment = model.associatedAttachmentsDict[cleanedAttachmentRef] {
                                // Clean the attachmentRef (remove '#' prefix)
                                if let formRef = attachment.attachmentRef {
                                    let cleanedFormRef = formRef.hasPrefix("#") ? String(formRef.dropFirst()) : formRef
                                    
                                    // Look up the Form using the cleanedFormRef
                                    if let form = model.formsDict[cleanedFormRef] {
                                        if !form.userAttributes.isEmpty {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Form: \(form.name ?? cleanedFormRef)")
                                                    .font(.subheadline)
                                                    .bold()
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                ForEach(Array(form.userAttributes.keys.sorted()), id: \.self) { key in
                                                    HStack {
                                                        Text("\(key):")
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                        Text(form.userAttributes[key] ?? "-")
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        } else {
                                            Text("Form \(cleanedFormRef) has no attributes.")
                                                .foregroundColor(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    } else {
                                        // For exclude wrong message when has link on DataSet, cause associatedAttachments is the same!
                                        // Text("Form \(cleanedFormRef) not found.")
                                        //     .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Attachment \(cleanedAttachmentRef) has no form reference.")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                Text("Attachment \(cleanedAttachmentRef) not found.")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } label: {
                        Text("Form Attributes")
                            .font(.headline)
                        //.padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        //.background(Color.orange.opacity(100))
                            .background(Color(nsColor: .windowBackgroundColor))
                        //.cornerRadius(8)
                            .onTapGesture {
                                withAnimation {
                                    isFormAttributesExpanded.toggle()
                                }
                            }
                    }
                    .padding(.bottom, 8)
                }
                
                // Datasets Section
                if !occurrence.dataSetRefs.isEmpty {
                    DisclosureGroup(isExpanded: $isDatasetsExpanded) {
                        ForEach(occurrence.dataSetRefs, id: \.self) { dsId in
                            if let ds = model.dataSetsDict[dsId] {
                                DataSetRow(dataSet: ds, model: model)
                            } else {
                                Text("- Unknown DataSet id=\(dsId)")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } label: {
                        Text("Datasets")
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
                    .padding(.bottom, 8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading) // Align content to the top-left
        }
    }
}
