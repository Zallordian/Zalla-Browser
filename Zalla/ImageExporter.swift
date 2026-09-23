import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers
import UIKit

enum ImageExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case heic = "HEIC"
    case webp = "WebP"

    var id: String { rawValue }

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .webp: return .webP
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .webp: return "webp"
        }
    }
}

enum ImageExporter {
    static func convert(data: Data, to format: ImageExportFormat, jpegQuality: CGFloat = 0.92) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ExportError.invalidImage
        }
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutable, format.utType.identifier as CFString, 1, nil
        ) else {
            throw ExportError.unsupportedFormat
        }
        var props: [CFString: Any] = [:]
        if format == .jpeg {
            props[kCGImageDestinationLossyCompressionQuality] = jpegQuality
        }
        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.encodeFailed
        }
        return mutable as Data
    }

    static func writeTemporary(data: Data, format: ImageExportFormat, baseName: String = "zalla-image") throws -> URL {
        let converted = try convert(data: data, to: format)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName).\(format.fileExtension)")
        try converted.write(to: url, options: .atomic)
        return url
    }

    static func saveToPhotos(data: Data, format: ImageExportFormat) async throws {
        let converted = try convert(data: data, to: format)
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.photosDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: converted, options: nil)
        }
    }

    enum ExportError: LocalizedError {
        case invalidImage
        case unsupportedFormat
        case encodeFailed
        case photosDenied

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "That image could not be read."
            case .unsupportedFormat: return "That export format is not supported on this device."
            case .encodeFailed: return "Could not encode the image."
            case .photosDenied: return "Photos access is needed to save images."
            }
        }
    }
}
