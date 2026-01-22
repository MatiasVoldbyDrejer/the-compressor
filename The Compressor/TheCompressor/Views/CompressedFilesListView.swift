import SwiftUI

struct CompressedFilesListView: View {
    @Bindable var queue: CompressionQueue

    var body: some View {
        VStack(spacing: 0) {
            if queue.compressedFiles.isEmpty {
                emptyState
            } else {
                // Header
                HStack {
                    Text("\(queue.compressedFiles.count) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if queue.totalSavedBytes > 0 {
                        Text("Saved \(queue.formattedTotalSaved)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                // File list
                List {
                    ForEach(queue.compressedFiles) { file in
                        CompressedFileRow(file: file)
                    }
                    .onDelete { indexSet in
                        queue.compressedFiles.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(.inset)

                // Footer
                Divider()
                HStack {
                    Button("Clear All") {
                        queue.compressedFiles.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .disabled(queue.compressedFiles.isEmpty)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("No compressed files")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Drop images to the left to compress")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CompressedFileRow: View {
    let file: CompressedFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    Text("Saved \(file.savingsPercent)%")
                        .foregroundStyle(.green)
                    Text("(\(file.formattedSavedBytes))")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            Button {
                ImageCompressor.revealInFinder(url: file.outputURL)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CompressedFilesListView(queue: CompressionQueue())
        .frame(width: 350, height: 400)
}
