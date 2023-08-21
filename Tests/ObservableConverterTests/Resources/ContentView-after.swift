//
//  ContentView.swift
//  ObservableObjectConversionExample
//
//  Created by Brian Capps on 8/16/23.
//

import SwiftUI

@Observable
final class ViewModelTest {
    var publishedProperty: String?
}

protocol ViewStore: ObservableObject {}

@Observable
final class ContentStore: ViewStore {
    var state: String?
}

struct ContentView: View {
    @State private var viewModel = ViewModelTest()
    @Environment(ViewModelTest.self) private var environmentModel 
    var observed: ContentStore

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Text("Hello, world!")
                .environment(viewModel)
            
            ChildView(model: environmentModel)
        }
        .padding()
    }
}

struct ChildView: View {
    var model: ViewModelTest
    
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
