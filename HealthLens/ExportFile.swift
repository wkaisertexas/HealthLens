import CoreData
import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable {
  case csv
  case xlsx
}

struct CSVExportFile {
  typealias FileExportType = () async -> URL?
  typealias FileType = () -> String
  public var collectData: FileExportType?
  public var fileName: FileType?
}

extension CSVExportFile: Transferable {
  enum ShareError: Error {
    case failed
  }

  func shareURL() async -> URL? {
    guard let collectData = collectData else {
      return nil
    }

    guard let result = await collectData() else {
      return nil
    }

    return result
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .commaSeparatedText) { object in
      .init(await object.shareURL()!)
    }.suggestedFileName { $0.fileName?() ?? "healthData" }
      .visibility(.all)
  }
}

struct XLSXExportFile {
  typealias FileExportType = () async -> URL?
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
  enum ShareError: Error {
    case failed
  }

  func shareURL() async -> URL? {
    guard let collectData = collectData else {
      return nil
    }

    guard let result = await collectData() else {
      return nil
    }

    return result
  }

  /// Creates a data representation transfer which is setup as a comma separated text
  static var transferRepresentation: some TransferRepresentation {    
    FileRepresentation(exportedContentType: .xlsx) { object in
          .init(await object.shareURL()!)
      }.suggestedFileName { $0.fileName?() ?? "healthData.xlsx" }
        .visibility(.all)
  }
}
