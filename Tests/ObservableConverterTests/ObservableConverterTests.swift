import XCTest
@testable import ObservableConverter

final class ObservableConverterTests: XCTestCase {
    func testExampleConversion() throws {
        let before = Bundle.module.path(forResource: "ContentView-before", ofType: "swift", inDirectory: "Resources")
        let after = Bundle.module.url(forResource: "ContentView-after", withExtension: "swift", subdirectory: "Resources")
        
        let fileToConvertPath = try XCTUnwrap(before)
        let afterURL = try XCTUnwrap(after)
        
        let testingFileToConvertPath = fileToConvertPath.appending(".testing")
        try FileManager.default.copyItem(atPath: fileToConvertPath, toPath: testingFileToConvertPath)
        
        let converterURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath.appending("/ObservableConverter"))
        let process = try Process.run(converterURL, arguments: [testingFileToConvertPath])
        process.waitUntilExit()
        
        let convertedFileContents = try String(contentsOf: URL(fileURLWithPath: testingFileToConvertPath))
        let expectedOutput = try String(contentsOf: afterURL)

        try FileManager.default.removeItem(atPath: testingFileToConvertPath)
        
        XCTAssertEqual(convertedFileContents, expectedOutput)
    }
}
