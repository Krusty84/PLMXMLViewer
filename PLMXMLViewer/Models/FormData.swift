//
//  FormData.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import SwiftUI
import Foundation
import AppKit

struct FormData: Identifiable {
    let id: String
    var name: String?
    var subType: String?
    var subClass: String?
    var userAttributes: [String: String] = [:]
    var uid: String?
}
