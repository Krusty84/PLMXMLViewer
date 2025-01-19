//
//  ContentView.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 16/01/2025.
//

import SwiftUI
import Foundation
import AppKit

// MARK: - Data Models

/// Represents a high-level ProductView in PLMXML (like a BOM view).
struct ProductView: Identifiable {
    let id: String
    var ruleRefs: [String]?
    var primaryOccurrenceRef: String?
    var rootRefs: [String]?
    
    /// Once parsed and built, these become the top-level occurrences in the BOM.
    var occurrences: [Occurrence] = []
    
    /// Occurrence = a node in the BOM hierarchy.
    struct Occurrence: Identifiable {
        let id: String
        
        /// For example "#id24" -> references <ProductRevision id="id24">
        var instancedRef: String?
        
        /// Child occurrence IDs (from occurrenceRefs="id57 id65")
        var occurrenceRefIDs: [String] = []
        
        /// After post-processing, these are the nested child occurrences.
        var subOccurrences: [Occurrence] = []
        
        // Display / metadata from ProductRevision
        var displayName:  String?
        var name:         String?
        var subType:      String?
        var revision:     String?
        var lastModDate:  String?
        
        // From <UserData type="AttributesInContext"> <UserValue title="SequenceNumber" ...>
        var sequenceNumber: String?
        var quantity: String?
        
        // NEW: The productId from <Product productId="...">
        var productId: String?
        
        // Optionally store references to DataSets
        var dataSetRefs: [String] = []
    }
}

/// Holds data from <ProductRevision> elements.
struct ProductRevisionData: Identifiable {
    let id: String
    
    var name:         String?
    var subType:      String?
    var revision:     String?
    var objectString: String?
    var lastModDate:  String?
    
    /// The `masterRef` references a <Product id="...">. We store that ID (stripped of '#').
    var masterRef: String?
    
    // DataSet references (from <AssociatedDataSet> or similar)
    var dataSetRefs: [String] = []
}

/// Holds data from <Product> elements (where productId is stored).
struct ProductData: Identifiable {
    let id: String
    
    /// <Product id="id26" productId="8882" ...>
    var productId: String?
    var name: String?
    var subType: String?
}

// MARK: - DataSet / ExternalFile

struct DataSetData: Identifiable {
    let id: String
    var name: String?
    var type: String?
    var version: String?
    
    /// For example, `memberRefs="#id466 #id500"`
    var memberRefs: [String] = []
}

struct ExternalFileData: Identifiable {
    let id: String
    var locationRef: String?
    var format: String?
    /// Optional: An absolute file path to open
    var fullPath: String?
}

/// Holds data from <RevisionRule> elements (e.g., id="id2" name="Latest Working").
struct RevisionRuleData: Identifiable {
    let id: String
    var name: String
}

struct PLMXMLGeneralData: Identifiable {
    let id: String
    var author: String
    //var schemaVersion: String
    var date: String
    var time: String
}

//<Header id="id1" traverseRootRefs="#id5" transferContext="ConfiguredDataFilesExportDefault"></Header>
struct PLMXMLTransferContextlData: Identifiable {
    let id: String
    var transferContext: String
}
// MARK: - BOMParser

/// Parses PLMXML to build a hierarchical BOM, linking Occurrence → ProductRevision → Product.
class BOMParser: NSObject, XMLParserDelegate {
    private let logger = Logger.shared
    let plmxmlDirectory: URL
    // MARK: - Final parsed results
    
    private(set) var productViews: [ProductView] = []
    private(set) var revisionRulesDict: [String: RevisionRuleData] = [:]
    private(set) var plmxmlGeneralDataDict: [String: PLMXMLGeneralData] = [:]
    private(set) var plmxmlTransferContextDataDict: [String: PLMXMLTransferContextlData] = [:]
    
    private var productRevisionsDict: [String: ProductRevisionData] = [:]
    private var productDict: [String: ProductData] = [:]      // NEW: For <Product> elements
    private var occurrencesDict: [String: ProductView.Occurrence] = [:]
    
    // MARK: - State while parsing
    
    private var currentProductView: ProductView?
    private var currentOccurrence: ProductView.Occurrence?
    private var currentProductRevision: ProductRevisionData?
    private var currentProduct: ProductData?
    private var currentDataSet: DataSetData?
    private var currentExternalFile: ExternalFileData?
    /// Are we inside <UserData type="AttributesInContext"> for an occurrence?
    private var insideAttributesInContext = false
    
    private var foundCharactersBuffer = ""
    
    var dataSetsDict: [String: DataSetData] = [:]
    var externalFilesDict: [String: ExternalFileData] = [:]
    
    //
    // Initialize with the directory
    init(plmxmlDirectory: URL) {
        self.plmxmlDirectory = plmxmlDirectory
        super.init()
    }
    // MARK: - Public Parse Entry
    
    func parse(xmlData: Data) -> [ProductView] {
        logger.log("Starting PLMXML parsing process.")
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        
        if parser.parse() {
            // Post-process to build the hierarchy
            logger.log("PLMXML parsing completed successfully.")
            buildHierarchyAndLinkData()
            return productViews
        } else {
            logger.log("PLMXML parsing failed.")
            return []
        }
    }
    
    // MARK: - XMLParserDelegate
    
    func parserDidStartDocument(_ parser: XMLParser) {
        logger.log("XML parsing started.")
        // Clear all data
        productViews.removeAll()
        revisionRulesDict.removeAll()
        plmxmlGeneralDataDict.removeAll()
        plmxmlTransferContextDataDict.removeAll()
        productRevisionsDict.removeAll()
        productDict.removeAll()
        occurrencesDict.removeAll()
        dataSetsDict.removeAll()
        externalFilesDict.removeAll()
        
        currentProductView     = nil
        currentOccurrence      = nil
        currentProductRevision = nil
        currentProduct         = nil
        currentDataSet = nil
        currentExternalFile = nil
        
        insideAttributesInContext = false
        foundCharactersBuffer = ""
        //
        logger.log("Cleared all data and reset parser state.")
    }
    
    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        foundCharactersBuffer = ""
        logger.log("Started parsing element: \(elementName)")
        switch elementName {
                // 1) PLMXML Info
            case "PLMXML":
                let schemaVersion   = attributeDict["schemaVersion"] ?? ""
                let date = attributeDict["date"] ?? "(No Name)"
                let time = attributeDict["time"] ?? "(No Name)"
                let author = attributeDict["author"] ?? "(No Name)"
                let plmxmlInfo = PLMXMLGeneralData(id:schemaVersion,author:author,date:date,time:time)
                plmxmlGeneralDataDict[schemaVersion] = plmxmlInfo
                //
                logger.log("Parsed PLMXML header: schemaVersion=\(schemaVersion), author=\(author), date=\(date), time=\(time).")
                // 2) ConfContext Info
            case "Header":
                // e.g. <Header id="id1" traverseRootRefs="#id5" transferContext="ConfiguredDataFilesExportDefault"></Header>
                let id   = attributeDict["id"] ?? ""
                let transferContext = attributeDict["transferContext"] ?? "(No transferContext)"
                let transferContextInfo = PLMXMLTransferContextlData(id: id, transferContext: transferContext)
                plmxmlTransferContextDataDict[id] = transferContextInfo
                //
                logger.log("Parsed Header: id=\(id), transferContext=\(transferContext).")
                
                // 3) ProductView
            case "ProductView":
                let id = attributeDict["id"] ?? ""
                // For ruleRefs="#id2" we remove '#'
                let rawRuleRefs = attributeDict["ruleRefs"]?.components(separatedBy: " ")
                let ruleRefs = rawRuleRefs?.map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
                
                let primaryOccurrenceRef = attributeDict["primaryOccurrenceRef"]
                let rootRefs = attributeDict["rootRefs"]?.components(separatedBy: " ")
                
                currentProductView = ProductView(
                    id: id,
                    ruleRefs: ruleRefs,
                    primaryOccurrenceRef: primaryOccurrenceRef,
                    rootRefs: rootRefs,
                    occurrences: []
                )
                //
                logger.log("Parsed ProductView: id=\(id), ruleRefs=\(ruleRefs ?? []), primaryOccurrenceRef=\(primaryOccurrenceRef ?? "nil").")
                
                // 4) Occurrence
            case "Occurrence":
                let id = attributeDict["id"] ?? ""
                var occ = ProductView.Occurrence(id: id)
                
                if let instancedRef = attributeDict["instancedRef"] {
                    occ.instancedRef = instancedRef.hasPrefix("#")
                    ? String(instancedRef.dropFirst())
                    : instancedRef
                }
                
                if let refsString = attributeDict["occurrenceRefs"] {
                    let childIDs = refsString.components(separatedBy: " ")
                        .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
                    occ.occurrenceRefIDs = childIDs
                }
                
                occurrencesDict[id] = occ
                currentOccurrence = occ
                //
                logger.log("Parsed Occurrence: id=\(id), instancedRef=\(occ.instancedRef ?? "nil"), occurrenceRefIDs=\(occ.occurrenceRefIDs).")
                
                // 5) ProductRevision
            case "ProductRevision":
                let id = attributeDict["id"] ?? ""
                var rev = ProductRevisionData(id: id)
                
                rev.name     = attributeDict["name"]
                rev.subType  = attributeDict["subType"]
                rev.revision = attributeDict["revision"]
                
                // If there's masterRef="#id26", store "id26"
                if let masterRef = attributeDict["masterRef"] {
                    rev.masterRef = masterRef.hasPrefix("#")
                    ? String(masterRef.dropFirst())
                    : masterRef
                }
                
                currentProductRevision = rev
                //
                logger.log("Parsed ProductRevision: id=\(id), name=\(rev.name ?? "nil"), masterRef=\(rev.masterRef ?? "nil").")
                
                // 6) Product (NEW)
            case "Product":
                // E.g. <Product id="id26" name="Level1" subType="Item" productId="8882">
                let id = attributeDict["id"] ?? ""
                var pd = ProductData(id: id)
                pd.productId = attributeDict["productId"]
                pd.name      = attributeDict["name"]
                pd.subType   = attributeDict["subType"]
                
                productDict[id] = pd
                currentProduct = pd
                //
                logger.log("Parsed Product: id=\(id), productId=\(pd.productId ?? "nil"), name=\(pd.name ?? "nil").")
                
                // 7) RevisionRule
            case "RevisionRule":
                // e.g. <RevisionRule id="id2" name="Latest Working">
                let id   = attributeDict["id"] ?? ""
                let name = attributeDict["name"] ?? "(No Name)"
                let rule = RevisionRuleData(id: id, name: name)
                revisionRulesDict[id] = rule
                //
                logger.log("Parsed RevisionRule: id=\(id), name=\(name).")
                
                // 8) UserData
            case "UserData":
                // If type="AttributesInContext", we watch for SequenceNumber
                if let typeAttr = attributeDict["type"], typeAttr == "AttributesInContext" {
                    insideAttributesInContext = true
                    //
                    logger.log("Entered UserData block with type=AttributesInContext.")
                }
                
                // 9) UserValue
            case "UserValue":
                // Could be sequenceNumber for an Occurrence
                //            if insideAttributesInContext, let occ = currentOccurrence {
                //                if let title = attributeDict["title"], title == "SequenceNumber" {
                //                    let val = attributeDict["value"] ?? ""
                //                    var updatedOcc = occ
                //                    updatedOcc.sequenceNumber = val
                //                    occurrencesDict[occ.id] = updatedOcc
                //                    currentOccurrence = updatedOcc
                //                }
                //            }
                if insideAttributesInContext, let occ = currentOccurrence {
                    if let title = attributeDict["title"],
                       let val   = attributeDict["value"] {
                        switch title {
                            case "SequenceNumber":
                                // existing logic for SequenceNumber
                                var updatedOcc = occ
                                updatedOcc.sequenceNumber = val
                                occurrencesDict[occ.id] = updatedOcc
                                currentOccurrence = updatedOcc
                                //
                                logger.log("Updated Occurrence with SequenceNumber: \(val).")
                            case "Quantity":  // <-- new attribute
                                var updatedOcc = occ
                                updatedOcc.quantity = val
                                occurrencesDict[occ.id] = updatedOcc
                                currentOccurrence = updatedOcc
                                //
                                logger.log("Updated Occurrence with Quantity: \(val).")
                            default:
                                break
                        }
                    }
                }
                // Could also be object_string / last_mod_date for ProductRevision
                if let pr = currentProductRevision,
                   let title = attributeDict["title"],
                   let val   = attributeDict["value"] {
                    var updatedPR = pr
                    switch title {
                        case "object_string": updatedPR.objectString = val
                        case "last_mod_date": updatedPR.lastModDate  = val
                        default: break
                    }
                    currentProductRevision = updatedPR
                    //
                    logger.log("Updated ProductRevision with \(title): \(val).")
                }
            case "DataSet":
                let id = attributeDict["id"] ?? ""
                var ds = DataSetData(id: id)
                ds.name = attributeDict["name"]
                ds.type = attributeDict["type"]
                ds.version = attributeDict["version"]
                if let memRefs = attributeDict["memberRefs"] {
                    let fileIds = memRefs.components(separatedBy: " ")
                        .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
                    ds.memberRefs = fileIds
                }
                currentDataSet = ds
                //
                logger.log("Parsed DataSet: id=\(id), name=\(ds.name ?? "nil"), type=\(ds.type ?? "nil").")
                
            case "ExternalFile":
                let id = attributeDict["id"] ?? ""
                var ef = ExternalFileData(id: id)
                ef.format = attributeDict["format"]
                if let loc = attributeDict["locationRef"] {
                    ef.locationRef = loc  // store raw
                    // Or store absolute path:
                    let absoluteURL = plmxmlDirectory.appendingPathComponent(loc)
                    ef.fullPath = absoluteURL.path  // add a new property, e.g. `fullPath`
                }
                currentExternalFile = ef
                //
                logger.log("Parsed ExternalFile: id=\(id), format=\(ef.format ?? "nil"), locationRef=\(ef.locationRef ?? "nil").")
                
            case "AssociatedDataSet":
                // e.g. <AssociatedDataSet dataSetRef="#id465">
                if let dsRef = attributeDict["dataSetRef"],
                   let pr = currentProductRevision {
                    let dsId = dsRef.hasPrefix("#") ? String(dsRef.dropFirst()) : dsRef
                    var updated = pr
                    updated.dataSetRefs.append(dsId)
                    currentProductRevision = updated
                    //
                    logger.log("Updated ProductRevision with DataSetRef: \(dsId).")
                }
            default:
                break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        foundCharactersBuffer += string
    }
    
    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        logger.log("Finished parsing element: \(elementName).")
        switch elementName {
            case "ProductView":
                if let pv = currentProductView {
                    productViews.append(pv)
                }
                currentProductView = nil
                
            case "Occurrence":
                if let occ = currentOccurrence {
                    occurrencesDict[occ.id] = occ
                }
                currentOccurrence = nil
                
            case "ProductRevision":
                if let rev = currentProductRevision {
                    productRevisionsDict[rev.id] = rev
                }
                currentProductRevision = nil
                
            case "Product":
                // We already stored the product in productDict
                currentProduct = nil
                
            case "UserData":
                // End of "AttributesInContext" block
                insideAttributesInContext = false
                //
                logger.log("Exited UserData block.")
                
            case "DataSet":
                if let ds = currentDataSet {
                    dataSetsDict[ds.id] = ds
                }
                currentDataSet = nil
                
            case "ExternalFile":
                if let ef = currentExternalFile {
                    externalFilesDict[ef.id] = ef
                }
                currentExternalFile = nil
            default:
                break
        }
        
        foundCharactersBuffer = ""
    }
    
    // MARK: - Build BOM
    
    private func buildHierarchyAndLinkData() {
        logger.log("Building BOM hierarchy and linking data.")
        // For each ProductView, find the root Occurrence(s)
        for i in 0..<productViews.count {
            var pv = productViews[i]
            
            let rootIDs = pv.rootRefs ?? (pv.primaryOccurrenceRef.map { [$0] } ?? [])
            
            var rootOccs: [ProductView.Occurrence] = []
            for rootId in rootIDs {
                if let rootOccurrence = occurrencesDict[rootId] {
                    let builtRoot = buildSubOccurrences(for: rootOccurrence)
                    rootOccs.append(builtRoot)
                }
            }
            
            pv.occurrences = rootOccs
            productViews[i] = pv
        }
        logger.log("BOM hierarchy built successfully.")
    }
    
    /// Recursively build child occurrences and link them to productRevision and product
    private func buildSubOccurrences(for occurrence: ProductView.Occurrence) -> ProductView.Occurrence {
        var newOcc = occurrence
        
        // Link to ProductRevision
        if let refId = occurrence.instancedRef,
           let revisionData = productRevisionsDict[refId] {
            
            newOcc.displayName = revisionData.objectString ?? revisionData.name
            newOcc.name        = revisionData.name
            newOcc.subType     = revisionData.subType
            newOcc.revision    = revisionData.revision
            newOcc.lastModDate = revisionData.lastModDate
            newOcc.dataSetRefs = revisionData.dataSetRefs
            // Also link to Product (via masterRef)
            if let productIdRef = revisionData.masterRef,
               let productData = productDict[productIdRef] {
                // We can store productData.productId in newOcc
                newOcc.productId = productData.productId
            }
        }
        
        // Recursively handle children
        newOcc.subOccurrences = occurrence.occurrenceRefIDs.compactMap { childId in
            guard let child = occurrencesDict[childId] else { return nil }
            return buildSubOccurrences(for: child)
        }
        
        return newOcc
    }
}

// MARK: - BOMModel (ObservableObject)

/// We store the BOM data in this model, so the UI can react to changes.
class BOMModel: ObservableObject {
    @Published var productViews: [ProductView] = []
    @Published var revisionRules: [String: RevisionRuleData] = [:]
    @Published var plmxmlInfo: [String: PLMXMLGeneralData] = [:]
    @Published var plmxmlTransferContextInfo: [String: PLMXMLTransferContextlData] = [:]
    /// The name of the last opened file, e.g. "MyAssembly.xml"
    @Published var lastOpenedFileName: String = "(No file opened)"
    @Published var dataSetsDict: [String: DataSetData] = [:]
    @Published var externalFilesDict: [String: ExternalFileData] = [:]
    //
    private let logger = Logger.shared
    var logFileURL: URL? {
            return Logger.shared.logFileURL
        }
    /// Helper method for loading from data, using BOMParser.
    //    func loadPLMXML(from data: Data) {
    //        let parser = BOMParser()
    //        let views = parser.parse(xmlData: data)
    //        self.productViews = views
    //        self.revisionRules = parser.revisionRulesDict
    //    }
    func loadPLMXML(from data: Data, fileName: String,plmxmlDirectory: URL) {
        logger.log("Starting to load \(fileName)")
        let parser = BOMParser(plmxmlDirectory: plmxmlDirectory)
        let views = parser.parse(xmlData: data)
        
        productViews = views
        revisionRules = parser.revisionRulesDict
        plmxmlInfo = parser.plmxmlGeneralDataDict
        plmxmlTransferContextInfo = parser.plmxmlTransferContextDataDict
        dataSetsDict = parser.dataSetsDict
        externalFilesDict = parser.externalFilesDict
        lastOpenedFileName = fileName
        logger.log("Finished processing \(fileName) with \(views.count) ProductViews found.")
    }
}

// MARK: - SwiftUI: BOMView

/// Main view with:
///  - left side: BOM structure
///  - right side: detail for selected occurrence
///  - each ProductView's header shows RevisionRule name(s) if ruleRefs exist
struct BOMView: View {
    @ObservedObject var model: BOMModel
    @State private var productViews: [ProductView] = []
    @State private var isLoading = true
    /// We'll store the parser's revisionRulesDict
    @State private var revisionRules: [String: RevisionRuleData] = [:]
    @State private var plmxmlInfo: [String: PLMXMLGeneralData] = [:]
    @State private var plmxmlTransferContextInfo: [String: PLMXMLTransferContextlData] = [:]
    /// Currently selected occurrence
    @State private var selectedOccurrence: ProductView.Occurrence? = nil
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
                            Section() {
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
                                        
                                    }
                                }
                            }
                            Section(){
                                // **Column Header** row
                                ColumnHeaderView()
                                ForEach(pv.occurrences) { occ in
                                    OccurrenceListItem(
                                        occurrence: occ,
                                        selectedOccurrence: $selectedOccurrence
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 800)
            
            Divider()
            
            // Right: details
            VStack {
                if let occ = selectedOccurrence {
                    OccurrenceDetailView(occurrence: occ,model: model)
                } else {
                    Text("No Occurrence Selected")
                }
            }
            .frame(minWidth: 300)
        }
        .frame(minWidth: 1100, minHeight: 500)
        .onAppear {
            loadPLMXML()
        }
    }
    
    private func loadPLMXML() {
        guard let url = Bundle.main.url(forResource: "PLMXMLFile", withExtension: "xml"),
              let data = try? Data(contentsOf: url) else {
            print("Could not load PLMXMLFile.xml from the bundle.")
            isLoading = false
            return
        }
        
        //let parser = BOMParser()
        //        let views = parser.parse(xmlData: data)
        //
        //        productViews = views
        //        revisionRules = parser.revisionRulesDict
        isLoading = false
    }
}

// MARK: - ColumnHeaderView

/// A single row labeling each column, center-aligned.
struct ColumnHeaderView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Name")
                .frame(width: 150, alignment: .leading) // Use .leading
            
            Text("SubType")
                .frame(width: 80, alignment: .leading) // Use .leading
            
            Text("Rev")
                .frame(width: 30, alignment: .leading) // Use .leading
            
            Text("LastMod")
                .frame(width: 120, alignment: .leading) // Use .leading
            
            Text("Seq#")
                .frame(width: 50, alignment: .leading) // Use .leading
            
            Text("ProductId")
                .frame(width: 60, alignment: .leading) // Use .leading
            
            Text("Quantity")
                .frame(width: 60, alignment: .leading) // Use .leading
        }
        .font(.headline)
        // .padding(.vertical, 4)
    }
}

// MARK: - OccurrenceListItem

/// A row that shows columns, plus a DisclosureGroup for child occurrences.
/// Clicking it sets `selectedOccurrence`.
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
                        .frame(width: 120, alignment: .leading)
                    
                    // 5) SequenceNumber
                    Text(occurrence.sequenceNumber ?? "")
                        .frame(width: 50, alignment: .leading)
                        .foregroundColor(.blue)
                    
                    // 6) ProductId
                    Text(occurrence.productId ?? "")
                        .frame(width: 60, alignment: .leading)
                        .foregroundColor(.purple)
                    
                    // 7) Quantity
                    Text(occurrence.quantity ?? "")
                        .frame(width: 60, alignment: .leading)
                        .foregroundColor(.orange)
                }
                .foregroundColor(.primary)
                .contentShape(Rectangle()) // Make the entire row tappable
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - OccurrenceDetailView

/// Detailed view for selected occurrence (right panel).
struct OccurrenceDetailView: View {
    let occurrence: ProductView.Occurrence
    let model: BOMModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Details").font(.headline).padding(.bottom, 5)
            
            Text("ID: \(occurrence.id)")
            Text("Name: \(occurrence.name ?? "-")")
            Text("DisplayName: \(occurrence.displayName ?? "-")")
            Text("SubType: \(occurrence.subType ?? "-")")
            Text("Revision: \(occurrence.revision ?? "-")")
            Text("LastModDate: \(occurrence.lastModDate ?? "-")")
            Text("SequenceNumber: \(occurrence.sequenceNumber ?? "-")")
            Text("Quantity: \(occurrence.quantity ?? "-")")
            Text("ProductId: \(occurrence.productId ?? "-")")
            
            //Divider().padding(.vertical, 8)
            
            Text("Child Occurrences: \(occurrence.subOccurrences.count)")
            
            if !occurrence.dataSetRefs.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Datasets").font(.headline).padding(.bottom, 5)
                ForEach(occurrence.dataSetRefs, id: \.self) { dsId in
                    if let ds = model.dataSetsDict[dsId] {
                        DataSetRow(dataSet: ds, model: model)
                    } else {
                        Text("- Unknown DataSet id=\(dsId)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

struct FileRow: View {
    let filePath: String   // e.g. "/Users/alex/PLMXMLStuff/SomePart.jt"
    
    var body: some View {
        // Use an HStack if you have other info or just a text by itself
        HStack {
            // The clickable, link-like text
            Text((filePath as NSString).lastPathComponent) // just the filename
                .foregroundColor(.blue)
                .underline()
            // 1) Make it open the file on left-click
                .onTapGesture {
                    openFile(at: filePath)
                }
            // 2) Add a context menu for right-click
                .contextMenu {
                    Button("Open File") {
                        openFile(at: filePath)
                    }
                    Button("Reveal in Finder") {
                        revealInFinder(filePath)
                    }
                    Button("Save As...") {
                        saveAs(filePath)
                    }
                }
        }
    }
    
    // MARK: - File Actions
    
    private func openFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)  // opens with default application
    }
        
    private func revealInFinder(_ path: String) {
        // Replace backslashes with forward slashes
        let sanitizedPath = path.replacingOccurrences(of: "\\", with: "/")
        let url = URL(fileURLWithPath: sanitizedPath)
        // Check if the file exists
        if FileManager.default.fileExists(atPath: url.path) {
            // Reveal the file in Finder
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            print("File does not exist at path: \(url.path)")
        }
    }
    
    private func saveAs(_ path: String) {
        // Replace backslashes with forward slashes
        //let sanitizedPath = path.replacingOccurrences(of: "\\", with: "/")
        
        // Create a URL from the sanitized path
        let sourceURL = URL(fileURLWithPath: sanitizedPath(path))
        
        // Sanitize the file name
        let sanitizedFileName = sanitizeFileName(sourceURL.lastPathComponent)
        
        // Check if the source file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("Source file does not exist at path: \(sourceURL.path)")
            return
        }
        
        let panel = NSSavePanel()
        panel.title = "Save File As..."
        panel.nameFieldStringValue = sanitizedFileName // Set only the file name
        panel.allowsOtherFileTypes = true
        
        panel.begin { response in
            if response == .OK, let destination = panel.url {
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                } catch {
                    print("Could not copy file: \(error.localizedDescription)")
                }
            }
        }
    }
    
//    private func saveAs(_ path: String) {
//        let sourceURL = URL(fileURLWithPath: path)
//        
//        let panel = NSSavePanel()
//        panel.title = "Save File As..."
//        panel.nameFieldStringValue = sourceURL.lastPathComponent
//        panel.allowsOtherFileTypes = true
//        
//        // If you prefer asynchronous, use panel.begin. For simplicity, use runModal:
//        if panel.runModal() == .OK, let destination = panel.url {
//            do {
//                try FileManager.default.copyItem(at: sourceURL, to: destination)
//            } catch {
//                print("Could not copy file: \(error)")
//            }
//        }
//    }
}

struct DataSetRow: View {
    let dataSet: DataSetData
    let model: BOMModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DataSet: \(dataSet.name ?? dataSet.id) [\(dataSet.type ?? "")]")
                .font(.subheadline)
            
            if !dataSet.memberRefs.isEmpty {
                ForEach(dataSet.memberRefs, id: \.self) { fileId in
                    if let ef = model.externalFilesDict[fileId] {
                        // A row for the external file
                        HStack {
                            //                            Text("File: \(ef.locationRef ?? "-") [\(ef.format ?? "")]")
                            //                                .font(.caption)
                            //
                            // If we have a fullPath, show a button:
                            if let path = ef.fullPath {
                                FileRow(filePath: path)
                                    .padding(.leading, 8)
                                //                                Button("Open File") {
                                //                                    openFile(atPath: path)
                                //                                }
                                    .font(.caption2)
                                    .padding(.leading, 8)
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
        .padding(.leading, 8)
    }
    
    /// Attempt to open the file in Finder or the default application
    private func openFile(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

//#Preview {
//    BOMView(model: model)
//}
