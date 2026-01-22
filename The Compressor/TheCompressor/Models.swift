import Foundation
import SwiftUI

// MARK: - Output Format

enum OutputFormat: String, CaseIterable, Identifiable {
    case avif
    case webp

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        rawValue
    }

    var uti: String {
        switch self {
        case .avif: return "public.avif"
        case .webp: return "org.webmproject.webp"
        }
    }
}

// MARK: - Compressed File

struct CompressedFile: Identifiable {
    let id = UUID()
    let filename: String
    let originalSize: Int64
    let compressedSize: Int64
    let outputURL: URL

    var savedBytes: Int64 {
        originalSize - compressedSize
    }

    var savingsPercent: Int {
        guard originalSize > 0 else { return 0 }
        return Int(Double(savedBytes) / Double(originalSize) * 100)
    }

    var formattedSavedBytes: String {
        ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)
    }
}

// MARK: - Compression Queue

@Observable
class CompressionQueue {
    var compressedFiles: [CompressedFile] = []
    var selectedFormat: OutputFormat = .avif
    var quality: Double = 0.8

    var totalSavedBytes: Int64 {
        compressedFiles.reduce(0) { $0 + $1.savedBytes }
    }

    var formattedTotalSaved: String {
        ByteCountFormatter.string(fromByteCount: totalSavedBytes, countStyle: .file)
    }

    func addCompressedFile(_ file: CompressedFile) {
        compressedFiles.insert(file, at: 0)
    }
}
