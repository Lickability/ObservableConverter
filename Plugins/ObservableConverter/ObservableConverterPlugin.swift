import Foundation
import PackagePlugin

@main
struct ObservableConverterPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let observableConverter = try context.tool(named: "ObservableConverter")
        
        var argExtractor = ArgumentExtractor(arguments)
        let targetNames = argExtractor.extractOption(named: "target")
        let targets = targetNames.isEmpty ? context.package.targets : try context.package.targets(named: targetNames)
        
        for target in targets {
            guard let sourceFiles = target.sourceModule?.sourceFiles(withSuffix: ".swift") else { continue }
            let filePaths = sourceFiles.map { $0.path.string }
            
            let sometoolExec = URL(fileURLWithPath: observableConverter.path.string)
            let process = try Process.run(sometoolExec, arguments: filePaths)
            process.waitUntilExit()
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ObservableConverterPlugin: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let observableConverter = try context.tool(named: "ObservableConverter")
        
        var argExtractor = ArgumentExtractor(arguments)
        let targetNames = argExtractor.extractOption(named: "target")
        let targets = targetNames.isEmpty ? context.xcodeProject.targets : context.xcodeProject.targets.filter { targetNames.contains($0.displayName) }
        
        for target in targets {
            let observableConverterURL = URL(fileURLWithPath: observableConverter.path.string)
            
            let filePaths: [String] = target.inputFiles.compactMap { file in
                guard file.type == .source && file.path.extension == "swift" else { return nil }
                return file.path.string
            }
            
            let process = try Process.run(observableConverterURL, arguments: filePaths)
            process.waitUntilExit()
        }
    }
}
#endif
