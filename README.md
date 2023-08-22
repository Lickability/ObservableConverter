<img width="512" alt="ObservableConverter" src="https://github.com/Lickability/ObservableConverter/assets/25009/ac0d3112-1d01-47df-a561-6c1dbec1c771">
<br /><br />

**ObservableConverter** from [Lickability](https://lickability.com) is a basic plugin to help convert your SwiftUI code using `ObservableObject` and related property wrappers and view modifiers to instead use Apple's new `@Observable` macro, [introduced](https://developer.apple.com/wwdc23/10149) at WWDC 2023 in iOS 17, macOS 14, watchOS 10, and tvOS 17.

<img width="429" alt="A screenshot of the menu you see when right-clicking a target, with the ObservableConverter plugin option highlighted" src="https://github.com/Lickability/ObservableConverter/assets/25009/3bf5ee31-3d6b-4313-a988-d176c4fa31cb">


# Installation

ObservableConverter is a Swift Package Manager command plugin, so installation is only available through SPM on Xcode 15 beta 6 and later. 

In Xcode, go to File and select Add Package Dependencies. Paste the URL of this repo into the search bar and select it. When it asks what framework to embed in your target, select None, as this tool is purely for code conversion purposes and should not be built as part of your app.

# Usage

As a command plugin, once ObservableConverter is installed it's as simple to use as right clicking on the target you want to convert in the Xcode project navigator and choosing the _Convert Target to Use @Observable_ option in the menu!

This repo also includes an example project using `ObservableObject` so you can see the conversion yourself. Open up the `xcodeproj` in the Examples folder and right click on the target to see it convert the existing code to use `@Observable`!

Here's what some of the example code looks like before the conversion:
```swift
final class ViewModelTest: ObservableObject {
    @Published var publishedProperty: String?
}

struct ContentView: View {
    @StateObject private var viewModel = ViewModelTest()
    @EnvironmentObject private var environmentModel: ViewModelTest
    
    var body: some View {
        VStack {
            ChildView(model: viewModel)
                .environmentObject(environmentModel)
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
```

And here's after 🎉:
```swift
@Observable
final class ViewModelTest {
    var publishedProperty: String?
}

struct ContentView: View {
    @State private var viewModel = ViewModelTest()
    @Environment(ViewModelTest.self) private var environmentModel 
    
    var body: some View {
        VStack {
            ChildView(model: viewModel)
                .environment(environmentModel)
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
```

# Notes

While this tool handles basic conversion instances, it is still very much in beta and will need some additional functionality. Please use under source control so that you can revert any changes that you don't like.

More advanced use cases that could be handled in the future:
* Optionally converting lazy properties to `@ObservationIgnored`
* Converting `onReceive` usage for converted `@Published` properties.
* Better handling of Combine within `ObservableObject` classes, such as converting the `assign(to published:)` operator and handling `@Published` property observation.
* Scanning for binding use cases of `@EnvironmentObject` and applying `@Bindable` in line when necessary.
  
# Need More Help?

Need more help getting your app ready for iOS 17+? That's what we do at [**Lickability**](https://lickability.com) – reach out to see how we can be of service!

<a href="https://lickability.com">
    <p align="center">
        <img src="https://github.com/Lickability/ObservableConverter/assets/25009/ea5ec8fa-0f0e-4409-9c33-8bcd20425a53" alt="Lickability" width="56">
    </p>
</a>
