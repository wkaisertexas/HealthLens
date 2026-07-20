import CoreData
import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable {
  case csv
  case xlsx
}

struct CSVExportFile {
  typealias FileExportType = () async throws -> URL
  typealias FileType = () -> String
  public var collectData: FileExportType?
  public var fileName: FileType?
}

extension CSVExportFile: Transferable {
  enum ShareError: LocalizedError {
    case exportUnavailable

    var errorDescription: String? {
      String(localized: "The export is not available.")
    }
  }

  func shareURL() async throws -> URL {
    guard let collectData else {
      throw ShareError.exportUnavailable
    }
    return try await collectData()
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .commaSeparatedText) { object in
      .init(try await object.shareURL())
    }.suggestedFileName { $0.fileName?() ?? "healthData" }
      .visibility(.all)
  }
}

struct XLSXExportFile {
  typealias FileExportType = () async throws -> URL
  typealias FileType = () -> String
  public var collectData: FileExportType?
  public var fileName: FileType?
}

extension UTType {
  static let xlsx =
    UTType("org.openxmlformats.spreadsheetml.sheet")
    ?? .spreadsheet
}

extension XLSXExportFile: Transferable {
  enum ShareError: LocalizedError {
    case exportUnavailable

    var errorDescription: String? {
      String(localized: "The export is not available.")
    }
  }

  func shareURL() async throws -> URL {
    guard let collectData else {
      throw ShareError.exportUnavailable
    }
    return try await collectData()
  }

  /// Creates a data representation transfer which is setup as a comma separated text
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .xlsx) { object in
      .init(try await object.shareURL())
    }.suggestedFileName { $0.fileName?() ?? "healthData.xlsx" }
      .visibility(.all)
  }
}
