//
//  BOMModel.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import Foundation
import SwiftUI

class BOMModel: ObservableObject {
    @Published var rawPLMXML: String = ""
    @Published var productViews: [ProductView] = []
    @Published var revisionRules: [String: RevisionRuleData] = [:]
    @Published var plmxmlInfo: [String: PLMXMLGeneralData] = [:]
    @Published var plmxmlTransferContextInfo: [String: PLMXMLTransferContextlData] = [:]
    @Published var currentSiteId: String? = nil
    @Published var sitesDict: [String: SiteData] = [:]
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
    func findMatchingSiteId(settingsModel: ApplicationSettingsModel) -> (siteId: String, tcURL: String)? {
        for site in sitesDict.values {
            if let matchingSetting = settingsModel.appSettings.first(where: { $0.tcSiteId == site.siteId }) {
                return (siteId: site.siteId ?? "Unknown", tcURL: matchingSetting.tcAwcUrl)
            }
        }
        return nil
    }
    func getProductRevision(byID id: String) -> ProductRevisionData? {
        return productRevisionsDict[id]
    }
    
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
