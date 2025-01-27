//
//  ProductRevisionData.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import SwiftUI
import Foundation
import AppKit

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
