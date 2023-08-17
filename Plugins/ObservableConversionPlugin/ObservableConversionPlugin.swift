import Foundation
import PackagePlugin

@main
struct ObservableConversionPlugin: CommandPlugin {
    
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        // We'll be invoking `sometool` to format code, so start by locating it.
        let observableConverter = try context.tool(named: "ObservableConverter")

        // Extract the target arguments (if there are none, we assume all).
                var argExtractor = ArgumentExtractor(arguments)
                let targetNames = argExtractor.extractOption(named: "target")
                let targets = targetNames.isEmpty
                    ? context.package.targets
                    : try context.package.targets(named: targetNames)

                // Iterate over the targets we've been asked to format.
                for target in targets {
                    // Skip any type of target that doesn't have source files.
                    // Note: We could choose to instead emit a warning or error here.
//                    guard let target = target.sourceModule else { continue }

                    // Invoke `sometool` on the target directory, passing a configuration
                    // file from the package directory.
                    let sometoolExec = URL(fileURLWithPath: observableConverter.path.string)
//                    let sometoolArgs = [
//                        "--config", "\(configFile)",
//                        "--cache", "\(context.pluginWorkDirectory.appending("cache-dir"))",
//                        "\(target.directory)"
//                    ]
                    let process = try Process.run(sometoolExec, arguments: [])
                    process.waitUntilExit()
//
//                    // Check whether the subprocess invocation was successful.
//                    if process.terminationReason == .exit && process.terminationStatus == 0 {
//                        print("Formatted the source code in \(target.directory).")
//                    }
//                    else {
//                        let problem = "\(process.terminationReason):\(process.terminationStatus)"
//                        Diagnostics.error("Formatting invocation failed: \(problem)")
//                    }
                }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ObservableConversionPlugin: XcodeCommandPlugin {

    /// 👇 This entry point is called when operating on an Xcode project.
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
       print("Command plugin execution for Xcode project \(context.xcodeProject.displayName)")
        
        // We'll be invoking `sometool` to format code, so start by locating it.
        let observableConverter = try context.tool(named: "ObservableConverter")

        // Extract the target arguments (if there are none, we assume all).
                var argExtractor = ArgumentExtractor(arguments)
                let targetNames = argExtractor.extractOption(named: "target")
                let targets = targetNames.isEmpty ? context.xcodeProject.targets : context.xcodeProject.targets.filter { targetNames.contains($0.displayName) }

                // Iterate over the targets we've been asked to format.
                for target in targets {
//                    try target.inputFiles.forEach { file in
//                        if file.type == .source {
//                            print("found source file: \(file.path)")
//                            let fileContents = try String(contentsOfFile: file.path.string)
//                            print("found body of file: \(fileContents)")
//                        }
//                    }
                    
                    // Skip any type of target that doesn't have source files.
                    // Note: We could choose to instead emit a warning or error here.
//                    guard let target = target.sourceModule else { continue }

                    // Invoke `sometool` on the target directory, passing a configuration
                    // file from the package directory.
                    let sometoolExec = URL(fileURLWithPath: observableConverter.path.string)
//                    let sometoolArgs = [
//                        "--config", "\(configFile)",
//                        "--cache", "\(context.pluginWorkDirectory.appending("cache-dir"))",
//                        "\(target.directory)"
//                    ]
                    
                    let filePaths: [String] = target.inputFiles.compactMap { file in
                        guard file.type == .source else { return nil }
                        guard file.path.extension == "swift" else { return nil }
                        return file.path.string
                    }
                    
                    print("BOC Command paths: \(filePaths)")
                    
                    let process = try Process.run(sometoolExec, arguments: filePaths)
                    process.waitUntilExit()
//
//                    // Check whether the subprocess invocation was successful.
//                    if process.terminationReason == .exit && process.terminationStatus == 0 {
//                        print("Formatted the source code in \(target.directory).")
//                    }
//                    else {
//                        let problem = "\(process.terminationReason):\(process.terminationStatus)"
//                        Diagnostics.error("Formatting invocation failed: \(problem)")
//                    }
                }

    }
}
#endif
