import SwiftUI

struct ContentView: View {
    @Bindable var queue: CompressionQueue

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                // Left: Drop zone
                DropZoneView(queue: queue)
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

                // Right: Compressed files list
                CompressedFilesListView(queue: queue)
                    .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 500, minHeight: 350)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 12) {
                    Picker("Format", selection: $queue.selectedFormat) {
                        ForEach(OutputFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Slider(value: $queue.quality, in: 0.1...1.0, step: 0.1)
                        .frame(width: 150)
                    Text("\(Int(queue.quality * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .leading)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    ImageCompressor.openOutputFolder(for: queue.selectedFormat)
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
            }
        }
    }
}

#Preview {
    ContentView(queue: CompressionQueue())
}
