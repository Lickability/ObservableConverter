# ObservableConverter

ObservableConverter from [Lickability](https://lickability.com) is a super simple plugin to convert your SwiftUI code using `ObservableObject` and related property wrappers and view modifiers to instead use Apple's new `@Observable` macro, [introduced](https://developer.apple.com/wwdc23/10149) at WWDC 2023.


<img width="429" alt="Screenshot 2023-08-17 at 2 25 13 PM" src="https://github.com/Lickability/ObservableConverter/assets/25009/60249cc4-9b9f-4ed9-9ce6-465a5c45d5bd">

# Installation

ObservableConverter is a Swift Package Manager command plugin, so installation is only available through SPM on Xcode 15 beta 6. 

In Xcode, go to your project and choose Package Dependencies and hit the + button. Paste the URL of this repo into the search bar and select it. When it asks what framework to embed in your target, select None, as this tool is purely for code conversion purposes and should not be built as part of your app.

# Usage

As a command plgun, once ObservableConverter is installed it's as simple to use as right clicking on the target you want to convert in Xcode and choosing the _Convert Target to Use @Observable_ option in the menu!

# Notes

While this tool handles most common conversion instances, it is still in beta and may still need some functionality. It will remain in Please use under source control so that you can revert any changes that you don't like.

More advances use cases that could be handled in the future:
* Converting the `assign(to published:)` operator in Combine to a different one.
* Scanning for binding use cases of `@EnvironmentObject` and applying `@Bindable` in line when necessary.
  
# Need More Help?

Need more help getting your app ready for iOS 17+? That's what we do at [Lickability](https://lickability.com) – reach out to see how we can be of service!
