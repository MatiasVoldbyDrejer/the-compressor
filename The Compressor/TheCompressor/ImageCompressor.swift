import Foundation
import AppKit
import ImageIO
import UserNotifications
import SDWebImageWebPCoder

// MARK: - Compression Error

enum CompressionError: LocalizedError {
    case imageLoadFailed
    case cgImageCreationFailed
    case destinationCreationFailed
    case finalizationFailed
    case directoryCreationFailed

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed: return "Failed to load image"
        case .cgImageCreationFailed: return "Failed to create image representation"
        case .destinationCreationFailed: return "Failed to create output file"
        case .finalizationFailed: return "Failed to write compressed image"
        case .directoryCreationFailed: return "Failed to create output directory"
        }
    }
}

// MARK: - Image Compressor

enum ImageCompressor {

    private static let maxConcurrent = 10

    // MARK: - Public API

    static func compressImages(urls: [URL], format: OutputFormat, quality: Double, queue: CompressionQueue) async {
        guard let outputDir = try? createOutputDirectory(for: format) else {
            return
        }

        let supportedExtensions = ["jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "bmp", "gif"]
        let validURLs = urls.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }

        var completedCount = 0
        var totalSaved: Int64 = 0

        await withTaskGroup(of: CompressedFile?.self) { group in
            var iterator = validURLs.makeIterator()
            var running = 0

            // Start initial batch
            while running < maxConcurrent, let url = iterator.next() {
                running += 1
                group.addTask {
                    await Self.compressSingleImage(url: url, outputDir: outputDir, format: format, quality: quality)
                }
            }

            // Process results and start new tasks
            for await result in group {
                running -= 1

                if let file = result {
                    completedCount += 1
                    totalSaved += file.savedBytes
                    await MainActor.run {
                        queue.addCompressedFile(file)
                    }
                }

                if let url = iterator.next() {
                    running += 1
                    group.addTask {
                        await Self.compressSingleImage(url: url, outputDir: outputDir, format: format, quality: quality)
                    }
                }
            }
        }

        // Send notification
        if completedCount > 0 {
            await sendCompletionNotification(
                completedCount: completedCount,
                totalSaved: ByteCountFormatter.string(fromByteCount: totalSaved, countStyle: .file)
            )
        }
    }

    // MARK: - Private Methods

    private static func compressSingleImage(
        url: URL,
        outputDir: URL,
        format: OutputFormat,
        quality: Double
    ) async -> CompressedFile? {
        // Get original size
        let originalSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            originalSize = attributes[.size] as? Int64 ?? 0
        } catch {
            return nil
        }

        // Load image
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }

        // Get CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Generate output URL
        let outputFilename = url.deletingPathExtension().lastPathComponent + "." + format.fileExtension
        let outputURL = outputDir.appendingPathComponent(outputFilename)

        // Encode based on format
        let success: Bool
        switch format {
        case .webp:
            success = encodeWebP(cgImage: cgImage, to: outputURL, quality: quality)
        case .avif:
            success = encodeWithCoreGraphics(cgImage: cgImage, to: outputURL, format: format, quality: quality)
        }

        guard success else {
            return nil
        }

        // Get compressed size
        let compressedSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            compressedSize = attributes[.size] as? Int64 ?? 0
        } catch {
            return nil
        }

        return CompressedFile(
            filename: url.lastPathComponent,
            originalSize: originalSize,
            compressedSize: compressedSize,
            outputURL: outputURL
        )
    }

    private static func encodeWebP(cgImage: CGImage, to outputURL: URL, quality: Double) -> Bool {
        let coder = SDImageWebPCoder.shared
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

        let options: [SDImageCoderOption: Any] = [
            .encodeCompressionQuality: quality
        ]

        guard let webpData = coder.encodedData(with: image, format: .webP, options: options) else {
            return false
        }

        do {
            try webpData.write(to: outputURL)
            return true
        } catch {
            return false
        }
    }

    private static func encodeWithCoreGraphics(cgImage: CGImage, to outputURL: URL, format: OutputFormat, quality: Double) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            format.uti as CFString,
            1,
            nil
        ) else {
            return false
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        return CGImageDestinationFinalize(destination)
    }

    private static func createOutputDirectory(for format: OutputFormat) throws -> URL {
        let fileManager = FileManager.default

        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            throw CompressionError.directoryCreationFailed
        }

        let baseFolder = desktopURL.appendingPathComponent("Compressed Images")
        let formatFolder = baseFolder.appendingPathComponent(format.rawValue)

        try fileManager.createDirectory(at: formatFolder, withIntermediateDirectories: true)

        return formatFolder
    }

    private static func sendCompletionNotification(completedCount: Int, totalSaved: String) async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { return }
        } catch {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Compression Complete"
        content.body = "\(completedCount) image\(completedCount == 1 ? "" : "s") compressed. Saved \(totalSaved)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    // MARK: - Utility

    static func revealInFinder(url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    static func openOutputFolder(for format: OutputFormat) {
        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else { return }
        let folderURL = desktopURL
            .appendingPathComponent("Compressed Images")
            .appendingPathComponent(format.rawValue)
        NSWorkspace.shared.open(folderURL)
    }
}
