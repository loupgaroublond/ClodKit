//
//  FileReadOutput.swift
//  ClodKit
//
//  Output type for the FileRead tool.
//

import Foundation

// MARK: - File Read Output

/// Output from a file read operation.
public enum FileReadOutput: Sendable, Equatable, Codable {
    /// Text file content.
    case text(FileReadTextOutput)

    /// Image file content.
    case image(FileReadImageOutput)

    /// Jupyter notebook content.
    case notebook(FileReadNotebookOutput)

    /// PDF file content.
    case pdf(FileReadPdfOutput)

    /// Multi-part content (e.g., extracted PDF pages).
    case parts(FileReadPartsOutput)

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try FileReadTextOutput(from: decoder))
        case "image":
            self = .image(try FileReadImageOutput(from: decoder))
        case "notebook":
            self = .notebook(try FileReadNotebookOutput(from: decoder))
        case "pdf":
            self = .pdf(try FileReadPdfOutput(from: decoder))
        case "parts":
            self = .parts(try FileReadPartsOutput(from: decoder))
        default:
            self = .text(try FileReadTextOutput(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let output): try output.encode(to: encoder)
        case .image(let output): try output.encode(to: encoder)
        case .notebook(let output): try output.encode(to: encoder)
        case .pdf(let output): try output.encode(to: encoder)
        case .parts(let output): try output.encode(to: encoder)
        }
    }
}

// MARK: - File Read Text Output

/// Text file read result.
public struct FileReadTextOutput: Sendable, Equatable, Codable {
    public let type: String
    public let file: FileReadTextFile

    public init(file: FileReadTextFile) {
        self.type = "text"
        self.file = file
    }
}

/// Text file information.
public struct FileReadTextFile: Sendable, Equatable, Codable {
    public let filePath: String
    public let content: String
    public let numLines: Int
    public let startLine: Int
    public let totalLines: Int

    enum CodingKeys: String, CodingKey {
        case filePath = "filePath"
        case content
        case numLines = "numLines"
        case startLine = "startLine"
        case totalLines = "totalLines"
    }

    public init(filePath: String, content: String, numLines: Int, startLine: Int, totalLines: Int) {
        self.filePath = filePath
        self.content = content
        self.numLines = numLines
        self.startLine = startLine
        self.totalLines = totalLines
    }
}

// MARK: - File Read Image Output

/// Image file read result.
public struct FileReadImageOutput: Sendable, Equatable, Codable {
    public let type: String
    public let file: FileReadImageFile

    public init(file: FileReadImageFile) {
        self.type = "image"
        self.file = file
    }
}

/// Image file information.
public struct FileReadImageFile: Sendable, Equatable, Codable {
    public let base64: String
    public let type: String
    public let originalSize: Int
    public let dimensions: FileReadImageDimensions?

    public init(base64: String, type: String, originalSize: Int, dimensions: FileReadImageDimensions? = nil) {
        self.base64 = base64
        self.type = type
        self.originalSize = originalSize
        self.dimensions = dimensions
    }
}

/// Image dimension information.
public struct FileReadImageDimensions: Sendable, Equatable, Codable {
    public let originalWidth: Int?
    public let originalHeight: Int?
    public let displayWidth: Int?
    public let displayHeight: Int?

    enum CodingKeys: String, CodingKey {
        case originalWidth = "originalWidth"
        case originalHeight = "originalHeight"
        case displayWidth = "displayWidth"
        case displayHeight = "displayHeight"
    }

    public init(
        originalWidth: Int? = nil,
        originalHeight: Int? = nil,
        displayWidth: Int? = nil,
        displayHeight: Int? = nil
    ) {
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
    }
}

// MARK: - File Read Notebook Output

/// Notebook file read result.
public struct FileReadNotebookOutput: Sendable, Equatable, Codable {
    public let type: String
    public let file: FileReadNotebookFile

    public init(file: FileReadNotebookFile) {
        self.type = "notebook"
        self.file = file
    }
}

/// Notebook file information.
public struct FileReadNotebookFile: Sendable, Equatable, Codable {
    public let filePath: String
    public let cells: [JSONValue]

    enum CodingKeys: String, CodingKey {
        case filePath = "filePath"
        case cells
    }

    public init(filePath: String, cells: [JSONValue]) {
        self.filePath = filePath
        self.cells = cells
    }
}

// MARK: - File Read PDF Output

/// PDF file read result.
public struct FileReadPdfOutput: Sendable, Equatable, Codable {
    public let type: String
    public let file: FileReadPdfFile

    public init(file: FileReadPdfFile) {
        self.type = "pdf"
        self.file = file
    }
}

/// PDF file information.
public struct FileReadPdfFile: Sendable, Equatable, Codable {
    public let filePath: String
    public let base64: String
    public let originalSize: Int

    enum CodingKeys: String, CodingKey {
        case filePath = "filePath"
        case base64
        case originalSize = "originalSize"
    }

    public init(filePath: String, base64: String, originalSize: Int) {
        self.filePath = filePath
        self.base64 = base64
        self.originalSize = originalSize
    }
}

// MARK: - File Read Parts Output

/// Multi-part file read result (e.g., extracted PDF pages).
public struct FileReadPartsOutput: Sendable, Equatable, Codable {
    public let type: String
    public let file: FileReadPartsFile

    public init(file: FileReadPartsFile) {
        self.type = "parts"
        self.file = file
    }
}

/// Parts file information.
public struct FileReadPartsFile: Sendable, Equatable, Codable {
    public let filePath: String
    public let originalSize: Int
    public let count: Int
    public let outputDir: String

    enum CodingKeys: String, CodingKey {
        case filePath = "filePath"
        case originalSize = "originalSize"
        case count
        case outputDir = "outputDir"
    }

    public init(filePath: String, originalSize: Int, count: Int, outputDir: String) {
        self.filePath = filePath
        self.originalSize = originalSize
        self.count = count
        self.outputDir = outputDir
    }
}
