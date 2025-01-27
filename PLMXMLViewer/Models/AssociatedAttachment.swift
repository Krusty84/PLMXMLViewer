//
//  AssociatedAttachment.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import SwiftUI
import Foundation
import AppKit

struct AssociatedAttachment: Identifiable {
    let id: String
    var attachmentRef: String? // References a Form
    var role: String?
}
