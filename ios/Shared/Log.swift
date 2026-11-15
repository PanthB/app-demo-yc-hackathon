import os

extension Logger {
    static let subsystem = "com.panthb.appdemo"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let inbox = Logger(subsystem: subsystem, category: "inbox")
    static let share = Logger(subsystem: subsystem, category: "share")
}
