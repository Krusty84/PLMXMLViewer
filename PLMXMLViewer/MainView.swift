//
//  ContentView.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 16/01/2025.
//

import SwiftUI
import Foundation
import AppKit
import CodeEditor

struct BOMView: View {
    @ObservedObject var model: BOMModel
    @ObservedObject var settingsModel: ApplicationSettingsModel
    @State private var productViews: [ProductView] = []
    @State private var isLoading = true
    @State private var revisionRules: [String: RevisionRuleData] = [:]
    @State private var plmxmlInfo: [String: PLMXMLGeneralData] = [:]
    @State private var plmxmlTransferContextInfo: [String: PLMXMLTransferContextlData] = [:]
    @State private var selectedOccurrence: ProductView.Occurrence? = nil
    @State private var selectedProductId: String?
    @State private var selectedDataSetId: String?
    @State private var selectedFormId: String?
    @State private var selectedTab: Int = 0
    @State private var isGeneralExpanded = true
    @State private var isShowingSettings = false
    @State private var selectedSiteId: String? = nil
    var body: some View {
        HStack(spacing: 0) {
            // Left: BOM list
            VStack {
                if isLoading {
                    ProgressView("Loading BOM...")
                } else if model.productViews.isEmpty {
                    Text("No ProductViews found.")
                } else {
                    List {
                        ForEach(model.productViews) { pv in
                            let ruleNames = (pv.ruleRefs ?? []).compactMap { model.revisionRules[$0]?.name }
                            let appliedRevRule = ruleNames.isEmpty ? "No Revision Rule" : ruleNames.joined(separator: ", ")
                            DisclosureGroup(isExpanded: $isGeneralExpanded) {
                                ForEach(Array(model.plmxmlInfo.keys), id: \.self) { key in
                                    if let plmxmlData = model.plmxmlInfo[key]{
                                        (Text("Exported from: ").bold() + Text("\(plmxmlData.author) ").font(.body))
                                        ForEach(Array(model.plmxmlTransferContextInfo.keys), id: \.self) { contextKey in
                                            if let plmxmlContextData = model.plmxmlTransferContextInfo[contextKey] {
                                                Text("PLMXML Rules: ").bold() + Text("\(plmxmlContextData.transferContext)").font(.body)
                                            }
                                        }
                                        (Text("Date: ").bold() + Text("\(plmxmlData.date) ").font(.body)) +
                                        (Text("Time: ").bold() + Text("\(plmxmlData.time)").font(.body))
                                        (Text("Configured by: ").bold() + Text("\(appliedRevRule) ").font(.body))
                                        ForEach(model.sitesDict.values.sorted(by: { $0.id < $1.id })) { site in
                                                                          HStack(spacing: 10) {
                                                                              // Change background color based on matching siteId
                                                                              (Text("Site Id: ").bold() + Text("\(site.siteId ?? "Unknown")").font(.body))
                                                                                  .background(
                                                                                    settingsModel.hasMatchingSiteId(site.siteId) ? Color.green.opacity(0.3) : Color.yellow.opacity(0.3)
                                                                                  )
                                                                                  .contextMenu {
                                                                                                    Button(action: {
                                                                                                        selectedSiteId = site.siteId
                                                                                                        isShowingSettings = true
                                                                                                    }) {
                                                                                                        Text("Open Settings")
                                                                                                        //Image(systemName: "gear")
                                                                                                    }
                                                                                                }
                                                                                  .cornerRadius(4)
                                                                                  .help(settingsModel.hasMatchingSiteId(site.siteId) ? "The Site Id has an associated AWC URL, you can go to the original Teamcenter" : "The Site Id does not have an associated AWC URL, you can go to settings (open the context menu here) and add this link")
                                                                              (Text("Site Name: ").bold() + Text("\(site.name ?? "Unknown")").font(.body))
                                                                          }
                                                                      }
                                    }
                                }
                                
                            } label: {
                                Text("PLMXML Overview")
                                    .font(.headline)
                                //.padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                //.background(Color.orange.opacity(100))
                                    .background(Color(nsColor: .windowBackgroundColor))
                                //.cornerRadius(8)
                                    .onTapGesture {
                                        withAnimation {
                                            isGeneralExpanded.toggle()
                                        }
                                    }
                            }
                            .padding(.bottom, 2)
                            Section {
                                // Tab Picker
                                Picker("", selection: $selectedTab) {
                                    Text("xBOM").tag(0)
                                    Text("Items").tag(1)
                                    Text("Datasets").tag(2)
                                    Text("Forms").tag(3)
                                    Text("Raw PLMXML").tag(4)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.horizontal)
                                
                                // Display occurrences based on the selected tab
                                switch selectedTab {
                                    case 0:
                                        // Column Header
                                        ColumnHeaderOccurrenceView()
                                        // Tab 1: Show all occurrences
                                        ForEach(pv.occurrences) { occ in
                                            OccurrenceListItem(
                                                occurrence: occ,
                                                selectedOccurrence: $selectedOccurrence
                                            )
                                        }
                                    case 1:
                                        ColumnHeaderProductView()
                                        ForEach(model.productDict.values.sorted(by: { $0.id < $1.id })) { product in
                                            ProductListItem(product: product, selectedProductId: $selectedProductId)
                                        }
                                    case 2:
                                        ColumnHeaderDataSetView()
                                        ForEach(model.dataSetsDict.values.sorted(by: { $0.id < $1.id })) { dataSet in
                                            DataSetListItem(dataSet: dataSet, selectedDataSetId: $selectedDataSetId)
                                        }
                                    case 3:
                                        ColumnHeaderFormView()
                                        ForEach(model.formsDict.values.sorted(by: { $0.id < $1.id })) { form in
                                            FormListItem(form: form, selectedFormId: $selectedFormId)
                                        }
                                    case 4:
                                        XMLEditorView(rawXMLData: $model.rawPLMXML).frame(minHeight: 400)
                                    default:
                                        EmptyView()
                                }
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 800)
            
            Divider()
            
            // Right: details
            GeometryReader { geometry in
                VStack {
                    switch selectedTab{
                        case 0:
                            if let occ = selectedOccurrence {
                                OccurrenceDetailView(occurrence: occ, model: model,settingsModel: settingsModel)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            } else {
                                Text("No Occurrence Selected")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        case 1:
                            if let selectedProductId = selectedProductId,
                               let product = model.productDict[selectedProductId] {
                                ProductDetailView(product: product, model: model,settingsModel: settingsModel)
                                    .frame(minWidth: 400)
                            } else {
                                Text("No Product Selected")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        case 2:
                            if let selectedDataSetId = selectedDataSetId,
                               let dataSet = model.dataSetsDict[selectedDataSetId] {
                                DataSetDetailView(dataSet: dataSet, model: model,settingsModel: settingsModel)
                                    .frame(minWidth: 400)
                            } else {
                                Text("No Dataset Selected")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        case 3:
                            if let selectedFormId = selectedFormId,
                               let form = model.formsDict[selectedFormId] {
                                FormDetailView(form: form, model: model,settingsModel: settingsModel)
                                    .frame(minWidth: 400)
                            } else {
                                Text("No Form Selected")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        default:
                            EmptyView()
                    }
                    
                }
            }
            .frame(minWidth: 300)
        }
        .frame(minWidth: 1100, minHeight: 500)
        .onAppear {
            loadPLMXML()
        }
        .sheet(isPresented: $isShowingSettings) {
            ApplicationSettingsView(model: settingsModel, highlightedSiteId:$selectedSiteId)
                   .onAppear {
                       if let siteId = selectedSiteId {
                           handleSiteIdInSettings(siteId)
                       }
                   }
           }
    }
    
    private func handleSiteIdInSettings(_ siteId: String) {
         if !settingsModel.hasMatchingSiteId(siteId) {
             // Add a new row with the Site Id
             settingsModel.appSettings.append(ApplicationSettings(tcSiteId: siteId, tcAwcUrl: ""))
         }
     }
    
    private func loadPLMXML() {
        guard let url = Bundle.main.url(forResource: "PLMXMLFile", withExtension: "xml"),
              let data = try? Data(contentsOf: url) else {
            //print("Could not load PLMXMLFile.xml from the bundle.")
            isLoading = false
            return
        }
        isLoading = false
    }
}
