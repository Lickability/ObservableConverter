import Foundation
import SwiftSyntax
import SwiftParser
import ArgumentParser

// TODO: Tests

@main
struct ObservableConverterCommand: ParsableCommand {
    @Argument(help: "A list of file paths to convert those files to use @Observable.")
    var filePaths: [String]
    
    func run() throws {
        try filePaths.forEach { filePath in
            let fileURL = URL(fileURLWithPath: filePath)
            let updatedTempFileURL = fileURL.appendingPathExtension("temp")

            let sourceFileContents = try String(contentsOf: fileURL, encoding: .utf8)
            let sourceFileSyntax = Parser.parse(source: sourceFileContents)
            
            let recorder = ObservableObjectRecorder(viewMode: .all)
            recorder.walk(sourceFileSyntax)
            let observableConverted = ObservableConverterRewriter(knownClassNames: recorder.observableObjectClassNames).visit(sourceFileSyntax)

            try "".write(to: updatedTempFileURL, atomically: true, encoding: .utf8)
            let fileHandle = try FileHandle(forWritingTo: updatedTempFileURL)
            var fileWriter = FileHandlerOutputStream(fileHandle: fileHandle)
            observableConverted.write(to: &fileWriter)
            fileHandle.closeFile()

            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: updatedTempFileURL)
        }
    }
}

struct FileHandlerOutputStream: TextOutputStream {
    let fileHandle: FileHandle

    mutating func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        } else {
            print("Write error")
        }
    }
}
