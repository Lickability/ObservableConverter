//
//  ContentView.swift
//  ObservableObjectConversionExample
//
//  Created by Brian Capps on 8/16/23.
//

import SwiftUI

final class ViewModelTest: ObservableObject {
    @Published var publishedProperty: String?
}

protocol ViewStore: ObservableObject {}

final class ContentStore: ViewStore {
    @Published var state: String?
}

struct ContentView: View {
    @StateObject private var viewModel = ViewModelTest()
    @EnvironmentObject private var environmentModel: ViewModelTest
    @ObservedObject var observed: ContentStore

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Text("Hello, world!")
                .environmentObject(viewModel)
            
            ChildView(model: environmentModel)
        }
        .padding()
    }
}

struct ChildView: View {
    @ObservedObject var model: ViewModelTest
    
    var body: some View {
        Text(model.publishedProperty ?? "no value set")
            .onTapGesture {
                model.publishedProperty = "model value changed"
            }
    }
}

#Preview {
    ContentView(observed: ContentStore())
}
