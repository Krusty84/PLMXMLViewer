//
//  XMLEditorView.swift
//  PLMXMLViewer
//
//  Created by Sedoykin Alexey on 27/01/2025.
//

import Foundation
import SwiftUI
import CodeEditor

struct XMLEditorView: View {
    @Binding var rawXMLData: String
    var body: some View {
        CodeEditor(source: $rawXMLData, language: .xml,flags: [ .selectable, .smartIndent])
    }
}
