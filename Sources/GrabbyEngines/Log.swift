import os

public enum Log {
    public static let subsystem = "com.pixelstwo.grabby"
    public static let tap = Logger(subsystem: subsystem, category: "tap")
    public static let gesture = Logger(subsystem: subsystem, category: "gesture")
    public static let engine = Logger(subsystem: subsystem, category: "engine")
    public static let permission = Logger(subsystem: subsystem, category: "permission")
    public static let settings = Logger(subsystem: subsystem, category: "settings")
}
