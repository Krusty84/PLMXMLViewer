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
    var occurrences: [Occurrence] = []
    struct Occurrence: Identifiable {
        let id: String
        var instancedRef: String?
        var associatedAttachmentRefs: [String] = []
        var occurrenceRefIDs: [String] = []
        var subOccurrences: [Occurrence] = []
        var displayName:  String?
        var name:         String?
        var subType:      String?
        var revision:     String?
        var lastModDate:  String?
        var sequenceNumber: String?
        var quantity: String?
        var productId: String?
        var userAttributes: [String: String] = [:]
        var dataSetRefs: [String] = []
    }
}

struct AssociatedAttachment: Identifiable {
    let id: String
    var attachmentRef: String? // References a Form
    var role: String?
}

struct FormData: Identifiable {
    let id: String
    var name: String?
    var subType: String?
    var subClass: String?
    var userAttributes: [String: String] = [:]
}

/// Holds data from <ProductRevision> elements.
struct ProductRevisionData: Identifiable {
    let id: String
    var name:         String?
    var subType:      String?
    var revision:     String?
    var objectString: String?
    var lastModDate:  String?
    var masterRef: String?
    var dataSetRefs: [String] = []
    var userAttributes: [String: String] = [:]
    var revisionUid: String?
}

/// Holds data from <Product> elements (where productId is stored).
struct ProductData: Identifiable {
    let id: String
    var productId: String?
    var name: String?
    var subType: String?
    var uid: String?
}

// MARK: - DataSet / ExternalFile

struct DataSetData: Identifiable {
    let id: String
    var name: String?
    var type: String?
    var version: String?
    var memberRefs: [String] = []
    var uid: String?
}

struct ExternalFileData: Identifiable {
    let id: String
    var locationRef: String?
    var format: String?
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


struct PLMXMLTransferContextlData: Identifiable {
    let id: String
    var transferContext: String
}

struct SiteData: Identifiable {
    let id: String
    var name: String?
    var siteId: String?
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
    private(set) var sitesDict: [String: SiteData] = [:]
    private(set) var plmxmlTransferContextDataDict: [String: PLMXMLTransferContextlData] = [:]
    private(set) var productRevisionsDict: [String: ProductRevisionData] = [:]
    private(set) var productDict: [String: ProductData] = [:]
    private(set) var occurrencesDict: [String: ProductView.Occurrence] = [:]
    private(set) var associatedAttachmentsDict: [String: AssociatedAttachment] = [:]
    private(set) var formsDict: [String: FormData] = [:]
    
    // MARK: - State while parsing
    
    private var currentProductView: ProductView?
    private var currentOccurrence: ProductView.Occurrence?
    private var currentProductRevision: ProductRevisionData?
    private var currentProduct: ProductData?
    private var currentForm: FormData?
    private var currentDataSet: DataSetData?
    private var currentExternalFile: ExternalFileData?
    private var currentSite: SiteData?
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
        associatedAttachmentsDict.removeAll()
        formsDict.removeAll()
        dataSetsDict.removeAll()
        sitesDict.removeAll()
        externalFilesDict.removeAll()
        
        currentProductView     = nil
        currentOccurrence      = nil
        currentProductRevision = nil
        currentProduct         = nil
        currentForm = nil
        currentDataSet = nil
        currentExternalFile = nil
        currentSite = nil
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
            case "Site":
                let id = attributeDict["id"]
                var site = SiteData(id: id ?? "")
                site.name = attributeDict["name"]
                site.siteId = attributeDict["siteId"]
                sitesDict[id ?? ""] = site
                currentSite = site
                logger.log("Parsed Site: id=\(id), name=\(site.name ?? "nil"), siteId=\(site.siteId ?? "nil").")
                
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
                    occ.instancedRef = instancedRef.hasPrefix("#") ? String(instancedRef.dropFirst()) : instancedRef
                }
                
                if let refsString = attributeDict["associatedAttachmentRefs"] {
                    let attachmentRefs = refsString.components(separatedBy: " ")
                        .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
                    occ.associatedAttachmentRefs = attachmentRefs
                }
                
                if let refsString = attributeDict["occurrenceRefs"] {
                    let childIDs = refsString.components(separatedBy: " ")
                        .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
                    occ.occurrenceRefIDs = childIDs
                }
                
                occurrencesDict[id] = occ
                currentOccurrence = occ
                logger.log("Parsed Occurrence: id=\(id), instancedRef=\(occ.instancedRef ?? "nil"), associatedAttachmentRefs=\(occ.associatedAttachmentRefs), occurrenceRefIDs=\(occ.occurrenceRefIDs).")
                
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
                
            case "ApplicationRef":
                if let version = attributeDict["version"] {
                    currentProductRevision?.revisionUid = version
                    logger.log("Parsed ApplicationRef with version (uid) for ProductRevision: \(version)")
                }
                if let label = attributeDict["label"] {
                    currentProduct?.uid = label
                    logger.log("Parsed ApplicationRef with label (uid) for Product: \(label)")
                }
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
                    logger.log("Entered UserData block with type=AttributesInContext.")
                } else if let typeAttr = attributeDict["type"], typeAttr == "FormAttributes" {
                    // Handle FormAttributes specifically
                    logger.log("Entered UserData block with type=FormAttributes.")
                }
                
            case "AssociatedAttachment":
                let id = attributeDict["id"] ?? ""
                var attachment = AssociatedAttachment(id: id)
                
                if let attachmentRef = attributeDict["attachmentRef"] {
                    attachment.attachmentRef = attachmentRef.hasPrefix("#") ? String(attachmentRef.dropFirst()) : attachmentRef
                }
                
                attachment.role = attributeDict["role"]
                associatedAttachmentsDict[id] = attachment
                logger.log("Parsed AssociatedAttachment: id=\(id), attachmentRef=\(attachment.attachmentRef ?? "nil"), role=\(attachment.role ?? "nil").")
                
            case "Form":
                let id = attributeDict["id"] ?? ""
                var form = FormData(id: id)
                form.name = attributeDict["name"]
                form.subType = attributeDict["subType"]
                form.subClass = attributeDict["subClass"]
                formsDict[id] = form
                currentForm = form
                logger.log("Parsed Form: id=\(id), name=\(form.name ?? "nil"), subType=\(form.subType ?? "nil").")
                
                // 9) UserValue
            case "UserValue":
                if insideAttributesInContext, let occ = currentOccurrence {
                    if let title = attributeDict["title"],
                       let val   = attributeDict["value"] {
                        var updatedOcc = occ
                        switch title {
                            case "SequenceNumber":
                                // existing logic for SequenceNumber
                                updatedOcc.sequenceNumber = val
                                occurrencesDict[occ.id] = updatedOcc
                                currentOccurrence = updatedOcc
                                //
                                logger.log("Updated Occurrence with SequenceNumber: \(val).")
                            case "Quantity":  // <-- new attribute
                                updatedOcc.quantity = val
                                occurrencesDict[occ.id] = updatedOcc
                                currentOccurrence = updatedOcc
                                //
                                logger.log("Updated Occurrence with Quantity: \(val).")
                            default:
                                // Handle dynamic attributes for Occurrence
                                updatedOcc.userAttributes[title] = val
                                logger.log("Updated Occurrence with dynamic attribute: \(title) = \(val).")
                        }
                        occurrencesDict[occ.id] = updatedOcc
                        currentOccurrence = updatedOcc
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
                        default:
                            updatedPR.userAttributes[title] = val
                            logger.log("Updated ProductRevision with dynamic attribute: \(title) = \(val).")
                    }
                    productRevisionsDict[pr.id] = updatedPR // Update the dictionary
                    currentProductRevision = updatedPR
                    //
                    logger.log("Updated ProductRevision with \(title): \(val).")
                }
                //
                if let form = currentForm, let title = attributeDict["title"], let val = attributeDict["value"] {
                    var updatedForm = form
                    updatedForm.userAttributes[title] = val
                    formsDict[form.id] = updatedForm
                    currentForm = updatedForm
                    logger.log("Updated Form with attribute: \(title) = \(val).")
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
    @Published var currentSiteId: String? = nil
    @Published var sitesDict: [String: SiteData] = [:]
    /// The name of the last opened file, e.g. "MyAssembly.xml"
    @Published var lastOpenedFileName: String = "(No file opened)"
    @Published var dataSetsDict: [String: DataSetData] = [:]
    @Published var externalFilesDict: [String: ExternalFileData] = [:]
    @Published var productDict: [String: ProductData] = [:] // Expose productDict
    @Published var productRevisionsDict: [String: ProductRevisionData] = [:]
    @Published var associatedAttachmentsDict: [String: AssociatedAttachment] = [:]
    @Published var formsDict: [String: FormData] = [:]
    //
    private let logger = Logger.shared
    var logFileURL: URL? {
        return Logger.shared.logFileURL
    }
    func findMatchingSiteId(settingsModel: SettingsModel) -> (siteId: String, tcURL: String)? {
        for site in sitesDict.values {
            if let matchingSetting = settingsModel.siteSettings.first(where: { $0.siteId == site.siteId }) {
                return (siteId: site.siteId ?? "Unknown", tcURL: matchingSetting.tcURL)
            }
        }
        return nil
    }
    func getProductRevision(byID id: String) -> ProductRevisionData? {
        return productRevisionsDict[id]
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
        sitesDict = parser.sitesDict
        dataSetsDict = parser.dataSetsDict
        externalFilesDict = parser.externalFilesDict
        productDict = parser.productDict
        productRevisionsDict = parser.productRevisionsDict
        associatedAttachmentsDict = parser.associatedAttachmentsDict
        formsDict = parser.formsDict
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
    @ObservedObject var settingsModel: SettingsModel
    @State private var productViews: [ProductView] = []
    @State private var isLoading = true
    /// We'll store the parser's revisionRulesDict
    @State private var revisionRules: [String: RevisionRuleData] = [:]
    @State private var plmxmlInfo: [String: PLMXMLGeneralData] = [:]
    @State private var plmxmlTransferContextInfo: [String: PLMXMLTransferContextlData] = [:]
    /// Currently selected occurrence
    @State private var selectedOccurrence: ProductView.Occurrence? = nil
    @State private var selectedProductId: String?
    @State private var selectedDataSetId: String?
    @State private var selectedFormId: String?
    //
    @State private var selectedTab: Int = 0
    @State private var isGeneralExpanded = true
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
                                            HStack(spacing: 10) { // Adjust the spacing value as needed
                                                (Text("Site Id: ").bold() + Text("\(site.siteId ?? "Unknown")").font(.body))
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
                                ProductDetailView(product: product, model: model)
                                    .frame(minWidth: 400)
                            } else {
                                Text("No Product Selected")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        case 2:
                            if let selectedDataSetId = selectedDataSetId,
                               let dataSet = model.dataSetsDict[selectedDataSetId] {
                                DataSetDetailView(dataSet: dataSet, model: model)
                                    .frame(minWidth: 400)
                            } else {
                                Text("No Dataset Selected")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        case 3:
                            if let selectedFormId = selectedFormId,
                               let form = model.formsDict[selectedFormId] {
                                FormDetailView(form: form, model: model)
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

// MARK: - OccurrenceDetailView

/// Detailed view for selected occurrence (right panel).
struct OccurrenceDetailView: View {
    let occurrence: ProductView.Occurrence
    let model: BOMModel
    @ObservedObject var settingsModel: SettingsModel
    // State variables to control section expansion
    @State private var isDetailsExpanded = true
    @State private var isRevisionAttributesExpanded = false
    @State private var isFormAttributesExpanded = false
    @State private var isDatasetsExpanded = false
    
    var body: some View {
        ScrollView {
            if let matchingSite = model.findMatchingSiteId(settingsModel: settingsModel),
               let instancedRef = occurrence.instancedRef,
               let productRevision = model.productRevisionsDict[instancedRef] {
                Button(action: {
                    openTCAWC(urlString: matchingSite.tcURL, uid: productRevision.revisionUid ?? "")
                }) {
                    Text("Open in External System")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Product Details Section
                Group {
                    Text("Product Details")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    //                    Text("ID: \(product.id)")
                    //                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Item Id: \(product.productId ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Name: \(product.name ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Type: \(product.subType ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Associated Product Revisions Section
                let revisions = model.productRevisionsDict.values.filter { $0.masterRef == product.id }
                if !revisions.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Associated Revisions")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ForEach(revisions) { revision in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Revision: \(revision.revision ?? "-")")
                                .font(.subheadline)
                                .bold()
                            Text("Name: \(revision.name ?? "-")")
                            Text("Type: \(revision.subType ?? "-")")
                            Text("Last Modified: \(revision.lastModDate ?? "-")")
                            
                            // Revision Attributes Section (only if userAttributes has valid data)
                            if !revision.userAttributes.isEmpty && revision.userAttributes.values.contains(where: { !$0.isEmpty }) {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                Text("Revision Attributes")
                                    .font(.subheadline)
                                    .bold()
                                
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
                
                // Associated DataSets Section
                let dataSetRefs = revisions.flatMap { $0.dataSetRefs }
                if !dataSetRefs.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Associated DataSets")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ForEach(dataSetRefs, id: \.self) { dsId in
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Dataset Details Section
                Group {
                    Text("DataSet Details")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    //                    Text("ID: \(dataSet.id)")
                    //                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Name: \(dataSet.name ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Type: \(dataSet.type ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Version: \(dataSet.version ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Associated Files Section
                if !dataSet.memberRefs.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Associated Files")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ForEach(dataSet.memberRefs, id: \.self) { fileId in
                        if let ef = model.externalFilesDict[fileId] {
                            HStack {
                                if let path = ef.fullPath {
                                    FileRow(filePath: path)
                                        .padding(.leading, 8)
                                        .font(.caption2)
                                } else {
                                    Text("File: \(ef.locationRef ?? "-") [\(ef.format ?? "")]")
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
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ColumnHeaderFormView: View {
    var body: some View {
        HStack(spacing: 8) {
            //            Text("Form ID")
            //                .frame(width: 150, alignment: .leading)
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Form Details Section
                Group {
                    Text("Form Details")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    //                    Text("ID: \(form.id)")
                    //                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Name: \(form.name ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Type: \(form.subType ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Class: \(form.subClass ?? "-")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Form Attributes Section
                if !form.userAttributes.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Form Attributes")
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
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

//#Preview {
//    BOMView(model: model)
//}
