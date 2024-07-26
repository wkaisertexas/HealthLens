import CoreData
import SwiftUI

/// `ExportFile` is a transferable class which allows an asynchronous operation to generate a file on button click.
///
/// It turns out that this is better, because you are able to export the file and then you need to request permissions.
///
/// from: https://stackoverflow.com/questions/76527347/how-to-use-sharelink-with-an-item-from-an-async-function
struct ExportFile {
  typealias FileExportType = () async -> String?
  typealias FileType = () -> String
  public var collectData: FileExportType?
  public var fileName: FileType?

  func exportData() async -> String? {
    guard let collectData = collectData, let returnData = await collectData() else {
      logger.error("Failed to return collected data")
      return nil
    }

    return returnData
  }

  func shareURL() async -> Data? {
    guard let shortURL = await exportData() else {
      return "example.com".data(using: .utf8)
    }
    return shortURL.data(using: .utf8)
  }
}

extension ExportFile: Transferable {
  enum ShareError: Error {
    case failed
  }

  /// Creates a data representation transfer which is setup as a comma separated text
  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .commaSeparatedText) { object in
      guard let data = await object.shareURL() else {
        throw ShareError.failed
      }
      return data
    }
    .suggestedFileName { $0.fileName?() ?? "healthData.csv" }
  }
}
