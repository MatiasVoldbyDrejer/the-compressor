import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Bindable var queue: CompressionQueue

    @State private var isTargeted = false
    @State private var isCompressing = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if isCompressing {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Compressing...")
                    .font(.headline)
            } else {
                // Icon
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                    .scaleEffect(isTargeted ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)

                // Text
                VStack(spacing: 4) {
                    Text(isTargeted ? "Release to compress" : "Drop images here")
                        .font(.headline)

                    Text("PNG, JPEG, HEIC, WebP, TIFF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .padding(8)
        }
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                urls.append(url)
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }

            isCompressing = true

            Task {
                await ImageCompressor.compressImages(
                    urls: urls,
                    format: queue.selectedFormat,
                    quality: queue.quality,
                    queue: queue
                )

                await MainActor.run {
                    isCompressing = false
                }
            }
        }
    }
}

#Preview {
    DropZoneView(queue: CompressionQueue())
        .frame(width: 240, height: 300)
}
