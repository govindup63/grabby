import Foundation

/// Plain-text trace for gesture debugging. Active only while
/// ~/Library/Application Support/Grabby/trace.log exists; appends to it.
public enum Trace {
    public static let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Grabby", isDirectory: true).appendingPathComponent("trace.log")
    }()

    private static let enabled = FileManager.default.fileExists(atPath: url.path)
    private static let queue = DispatchQueue(label: "com.pixelstwo.grabby.trace")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    public static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let line = "\(formatter.string(from: Date())) \(message())\n"
        queue.async {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            }
        }
    }
}
