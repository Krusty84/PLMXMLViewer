//
//  DataSetData.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import SwiftUI
import Foundation
import AppKit

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
