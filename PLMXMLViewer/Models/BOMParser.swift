//
//  BOMParser.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import SwiftUI
import Foundation
import AppKit

class BOMParser: NSObject, XMLParserDelegate {
    private let logger = Logger.shared
    let plmxmlDirectory: URL
    
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
                
            case "Header":
                // e.g. <Header id="id1" traverseRootRefs="#id5" transferContext="ConfiguredDataFilesExportDefault"></Header>
                let id   = attributeDict["id"] ?? ""
                let transferContext = attributeDict["transferContext"] ?? "(No transferContext)"
                let transferContextInfo = PLMXMLTransferContextlData(id: id, transferContext: transferContext)
                plmxmlTransferContextDataDict[id] = transferContextInfo
                //
                logger.log("Parsed Header: id=\(id), transferContext=\(transferContext).")
                
                
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
                
            case "RevisionRule":
                // e.g. <RevisionRule id="id2" name="Latest Working">
                let id   = attributeDict["id"] ?? ""
                let name = attributeDict["name"] ?? "(No Name)"
                let rule = RevisionRuleData(id: id, name: name)
                revisionRulesDict[id] = rule
                //
                logger.log("Parsed RevisionRule: id=\(id), name=\(name).")
                
                
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
                
            case "ApplicationRef":
                if let version = attributeDict["version"] {
                    if var currentProductRevision = currentProductRevision {
                        currentProductRevision.revisionUid = version
                        self.currentProductRevision = currentProductRevision // Reassign the updated copy
                        logger.log("Parsed ApplicationRef with version (uid) for ProductRevision: \(version)")
                    }
                }
                if let label = attributeDict["label"] {
                    if var currentProduct = currentProduct {
                        currentProduct.uid = label
                        self.currentProduct = currentProduct // Reassign the updated copy
                        self.productDict[currentProduct.id] = currentProduct
                        logger.log("Parsed ApplicationRef with label (uid) for Product: \(label)")
                    } else if var currentDataSet = currentDataSet {
                        currentDataSet.uid = label
                        self.currentDataSet = currentDataSet
                        self.dataSetsDict[currentDataSet.id] = currentDataSet
                        logger.log("Parsed ApplicationRef with label (uid) for Dataset: \(label)")
                    }  else if var currentForm = currentForm {
                        currentForm.uid = label
                        self.currentForm = currentForm
                        self.formsDict[currentForm.id] = currentForm
                        logger.log("Parsed ApplicationRef with label (uid) for Form: \(label)")
                    }
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
