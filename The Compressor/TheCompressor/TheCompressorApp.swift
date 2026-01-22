import SwiftUI

@main
struct TheCompressorApp: App {
    @State private var queue = CompressionQueue()

    var body: some Scene {
        WindowGroup {
            ContentView(queue: queue)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 480)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Clear All") {
                    queue.compressedFiles.removeAll()
                }
                .keyboardShortcut("K", modifiers: .command)
                .disabled(queue.compressedFiles.isEmpty)

                Divider()

                Button("Open Output Folder") {
                    ImageCompressor.openOutputFolder(for: queue.selectedFormat)
                }
                .keyboardShortcut("O", modifiers: [.command, .shift])
            }
        }
    }
}
