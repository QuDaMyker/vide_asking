//
//  PhotoScrollState.swift
//  Rocket
//
//  Created by Quốc Danh Phạm on 14/11/25.
//

import SwiftUI

@MainActor
class PhotoScrollState: ObservableObject {
    @Published var currentIndex: Int = 0
}
