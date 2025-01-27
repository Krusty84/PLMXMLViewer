//
//  ProductView.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import SwiftUI
import Foundation
import AppKit

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
