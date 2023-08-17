//
//  ObservableObjectConversionExampleApp.swift
//  ObservableObjectConversionExample
//
//  Created by Brian Capps on 8/16/23.
//

import SwiftUI

@main
struct ObservableObjectConversionExampleApp: App {
    @StateObject private var test = ViewModelTest()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(test)
        }
    }
}
