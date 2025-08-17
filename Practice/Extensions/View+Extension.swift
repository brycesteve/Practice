//
//  View+Extension.swift
//  Practice
//
//  Created by Steve Bryce on 17/08/2025.
//

import SwiftUI

struct CleanListItemModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .listRowInsets(.vertical, 8)
    }
}


extension View {
    func cleanListItem() -> some View {
        modifier(CleanListItemModifier())
    }
}
