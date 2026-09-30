import Foundation

public enum TaskLane: String, CaseIterable, Codable, Sendable, Identifiable {
    case action
    case external
    case `internal`
    case blocked
    case done

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .action:
            return "Perlu saya gerakkan"
        case .external:
            return "Nunggu pihak luar"
        case .internal:
            return "Nunggu internal"
        case .blocked:
            return "Terhambat"
        case .done:
            return "Selesai"
        }
    }
}

public enum QueueFilter: String, CaseIterable, Sendable, Identifiable {
    case all
    case action
    case waiting
    case noFollowUp = "no-followup"
    case blocked

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all:
            return "Semua kerjaan"
        case .action:
            return "Perlu saya gerakkan"
        case .waiting:
            return "Nunggu orang lain"
        case .noFollowUp:
            return "Belum ada follow-up"
        case .blocked:
            return "Terhambat"
        }
    }
}

public enum AppAppearanceMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: return "Mengikuti Sistem"
        case .light: return "Mode Terang"
        case .dark: return "Mode Gelap"
        }
    }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

public struct TaskEvent: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var date: String
    public var note: String

    public init(id: String = UUID().uuidString.lowercased(), date: String, note: String) {
        self.id = id
        self.date = date
        self.note = note
    }
}

public struct Workspace: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var name: String
    public var createdAt: String

    public init(id: String = UUID().uuidString.lowercased(), name: String, createdAt: String = WorkDateFormatting.localISODate()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public enum StickyColor: String, CaseIterable, Codable, Sendable, Identifiable {
    case yellow
    case blue
    case purple
    case pink
    case orange
    case green
    case gray

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .yellow: return "Kuning"
        case .blue: return "Biru"
        case .purple: return "Ungu"
        case .pink: return "Pink"
        case .orange: return "Oranye"
        case .green: return "Hijau"
        case .gray: return "Abu-abu"
        }
    }
}

public enum StickyType: String, CaseIterable, Codable, Sendable, Identifiable {
    case sticky
    case text
    case card

    public var id: String { rawValue }
}

public struct StickyNote: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var workspaceId: String
    public var content: String
    public var color: StickyColor
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var author: String
    public var noteType: StickyType
    public var createdAt: String
    public var updatedAt: String

    public init(
        id: String = UUID().uuidString.lowercased(),
        workspaceId: String = "default",
        content: String = "",
        color: StickyColor = .yellow,
        x: Double = 100,
        y: Double = 100,
        width: Double = 180,
        height: Double = 180,
        author: String = "Saya",
        noteType: StickyType = .sticky,
        createdAt: String = WorkDateFormatting.localISODate(),
        updatedAt: String = WorkDateFormatting.localISODate()
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.content = content
        self.color = color
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.author = author
        self.noteType = noteType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum LineCapStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case arrow
    case plain
    case doubleArrow

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .arrow: return "Panah Satu Arah"
        case .plain: return "Garis Lurus"
        case .doubleArrow: return "Panah Dua Arah"
        }
    }
}

public struct BoardLine: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var workspaceId: String
    public var startX: Double
    public var startY: Double
    public var endX: Double
    public var endY: Double
    public var color: String
    public var style: LineCapStyle
    public var isCurved: Bool
    public var controlX: Double?
    public var controlY: Double?
    public var control2X: Double?
    public var control2Y: Double?
    public var label: String
    public var createdAt: String

    public init(
        id: String = UUID().uuidString.lowercased(),
        workspaceId: String = "default",
        startX: Double,
        startY: Double,
        endX: Double,
        endY: Double,
        color: String = "#334155",
        style: LineCapStyle = .arrow,
        isCurved: Bool = false,
        controlX: Double? = nil,
        controlY: Double? = nil,
        control2X: Double? = nil,
        control2Y: Double? = nil,
        label: String = "",
        createdAt: String = WorkDateFormatting.localISODate()
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.startX = startX
        self.startY = startY
        self.endX = endX
        self.endY = endY
        self.color = color
        self.style = style
        self.isCurved = isCurved
        self.controlX = controlX
        self.controlY = controlY
        self.control2X = control2X
        self.control2Y = control2Y
        self.label = label
        self.createdAt = createdAt
    }
}

public struct Person: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var name: String

    public init(id: String = UUID().uuidString.lowercased(), name: String) {
        self.id = id
        self.name = name
    }
}

public enum CodeEditorApp: String, CaseIterable, Codable, Sendable, Identifiable {
    case antiGravity = "antigravity"
    case vscode = "vscode"
    case cursor = "cursor"
    case xcode = "xcode"
    case windsurf = "windsurf"
    case zed = "zed"
    case terminal = "terminal"
    case finder = "finder"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .antiGravity: return "AntiGravity"
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        case .xcode: return "Xcode"
        case .windsurf: return "Windsurf"
        case .zed: return "Zed"
        case .terminal: return "Terminal"
        case .finder: return "Finder"
        }
    }

    public var systemIcon: String {
        switch self {
        case .antiGravity: return "chevron.left.forwardslash.chevron.right"
        case .vscode: return "curlybraces"
        case .cursor: return "cursorarrow.rays"
        case .xcode: return "hammer"
        case .windsurf: return "wind"
        case .zed: return "bolt"
        case .terminal: return "terminal"
        case .finder: return "folder"
        }
    }

    public var bundleIdentifiers: [String] {
        switch self {
        case .antiGravity:
            return ["com.google.antigravity-ide", "com.google.antigravity"]
        case .vscode:
            return ["com.microsoft.VSCode", "com.visualstudio.code.oss"]
        case .cursor:
            return ["com.todesktop.230313mzl4w4u92"]
        case .xcode:
            return ["com.apple.dt.Xcode"]
        case .windsurf:
            return ["com.codeium.windsurf"]
        case .zed:
            return ["dev.zed.Zed"]
        case .terminal:
            return ["com.apple.Terminal"]
        case .finder:
            return ["com.apple.finder"]
        }
    }

    public var appNames: [String] {
        switch self {
        case .antiGravity:
            return ["Antigravity IDE", "Antigravity"]
        case .vscode:
            return ["Visual Studio Code", "Code"]
        case .cursor:
            return ["Cursor"]
        case .xcode:
            return ["Xcode"]
        case .windsurf:
            return ["Windsurf"]
        case .zed:
            return ["Zed"]
        case .terminal:
            return ["Terminal"]
        case .finder:
            return ["Finder"]
        }
    }
}

public struct WorkTask: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var title: String
    public var project: String
    public var lane: TaskLane
    public var owner: String
    public var nextAction: String
    public var followUpAt: String
    public var updatedAt: String
    public var isExample: Bool
    public var workspaceId: String
    public var projectPath: String
    public var events: [TaskEvent]

    public init(
        id: String = UUID().uuidString.lowercased(),
        title: String,
        project: String = "",
        lane: TaskLane = .action,
        owner: String,
        nextAction: String,
        followUpAt: String = "",
        updatedAt: String,
        isExample: Bool = false,
        workspaceId: String = "default",
        projectPath: String = "",
        events: [TaskEvent] = []
    ) {
        self.id = id
        self.title = title
        self.project = project
        self.lane = lane
        self.owner = owner
        self.nextAction = nextAction
        self.followUpAt = followUpAt
        self.updatedAt = updatedAt
        self.isExample = isExample
        self.workspaceId = workspaceId
        self.projectPath = projectPath
        self.events = events
    }
}

public struct TaskDraft: Sendable {
    public var id: String?
    public var title: String
    public var project: String
    public var lane: TaskLane
    public var owner: String
    public var nextAction: String
    public var followUpAt: String
    public var isExample: Bool
    public var workspaceId: String
    public var projectPath: String
    public var events: [TaskEvent]?

    public init(
        id: String? = nil,
        title: String,
        project: String = "",
        lane: TaskLane = .action,
        owner: String,
        nextAction: String,
        followUpAt: String = "",
        isExample: Bool = false,
        workspaceId: String = "default",
        projectPath: String = "",
        events: [TaskEvent]? = nil
    ) {
        self.id = id
        self.title = title
        self.project = project
        self.lane = lane
        self.owner = owner
        self.nextAction = nextAction
        self.followUpAt = followUpAt
        self.isExample = isExample
        self.workspaceId = workspaceId
        self.projectPath = projectPath
        self.events = events
    }
}

public struct QueueCounts: Equatable, Sendable {
    public var all: Int
    public var action: Int
    public var waiting: Int
    public var noFollowUp: Int
    public var blocked: Int

    public init(all: Int = 0, action: Int = 0, waiting: Int = 0, noFollowUp: Int = 0, blocked: Int = 0) {
        self.all = all
        self.action = action
        self.waiting = waiting
        self.noFollowUp = noFollowUp
        self.blocked = blocked
    }

    public func count(for filter: QueueFilter) -> Int {
        switch filter {
        case .all:
            return all
        case .action:
            return action
        case .waiting:
            return waiting
        case .noFollowUp:
            return noFollowUp
        case .blocked:
            return blocked
        }
    }
}

public enum FollowUpStatus: Equatable, Sendable {
    case unset
    case overdue(formattedDate: String)
    case dueToday
    case scheduled(formattedDate: String)
}

public enum WorkQueueError: LocalizedError, Equatable {
    case validation(String)
    case duplicatePerson(String)
    case notFound(String)
    case unsupportedDatabaseVersion(Int)
    case databaseFailure(String)

    public var errorDescription: String? {
        switch self {
        case .validation(let message),
             .duplicatePerson(let message),
             .notFound(let message),
             .databaseFailure(let message):
            return message
        case .unsupportedDatabaseVersion(let version):
            return "Versi database \(version) lebih baru dari versi aplikasi ini."
        }
    }
}

public enum WorkDateFormatting {
    private static let isoPattern = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)

    public static func collapseWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public static func localISODate(from date: Date = Date(), calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func validateISODate(_ value: String, field: String, allowEmpty: Bool = false) throws -> String {
        if allowEmpty && value.isEmpty {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard isoPattern.firstMatch(in: value, options: [], range: range) != nil else {
            throw WorkQueueError.validation("\(field) harus berupa tanggal YYYY-MM-DD.")
        }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw WorkQueueError.validation("\(field) harus berupa tanggal YYYY-MM-DD.")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let parsed = calendar.date(from: components),
              calendar.component(.year, from: parsed) == parts[0],
              calendar.component(.month, from: parsed) == parts[1],
              calendar.component(.day, from: parsed) == parts[2] else {
            throw WorkQueueError.validation("\(field) bukan tanggal kalender yang valid.")
        }
        return value
    }

    public static func parseISODate(_ value: String, calendar: Calendar = .current) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components),
              calendar.component(.year, from: date) == parts[0],
              calendar.component(.month, from: date) == parts[1],
              calendar.component(.day, from: date) == parts[2] else {
            return nil
        }
        return date
    }

    public static func formatShortDate(_ isoDate: String) -> String {
        guard !isoDate.isEmpty else { return "Belum diatur" }
        guard let date = parseISODate(isoDate) else { return "Tanggal tidak valid" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    public static func formatHeaderDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: date)
    }

    public static func followUpStatus(for task: WorkTask, today: String = localISODate()) -> FollowUpStatus {
        guard !task.followUpAt.isEmpty else { return .unset }
        if task.followUpAt < today && task.lane != .done {
            return .overdue(formattedDate: formatShortDate(task.followUpAt))
        }
        if task.followUpAt == today {
            return .dueToday
        }
        return .scheduled(formattedDate: formatShortDate(task.followUpAt))
    }
}

public enum WorkQueueLogic {
    public static func counts(for tasks: [WorkTask]) -> QueueCounts {
        let active = tasks.filter { $0.lane != .done }
        return QueueCounts(
            all: tasks.count,
            action: active.filter { $0.lane == .action }.count,
            waiting: active.filter { $0.lane == .external || $0.lane == .internal }.count,
            noFollowUp: active.filter { $0.followUpAt.isEmpty }.count,
            blocked: active.filter { $0.lane == .blocked }.count
        )
    }

    public static func matchesWorkspace(_ task: WorkTask, workspaceId: String?) -> Bool {
        guard let workspaceId, !workspaceId.isEmpty else { return true }
        return task.workspaceId == workspaceId
    }

    public static func matchesFilter(_ task: WorkTask, filter: QueueFilter) -> Bool {
        let isActive = task.lane != .done
        switch filter {
        case .all:
            return true
        case .action:
            return task.lane == .action
        case .waiting:
            return task.lane == .external || task.lane == .internal
        case .noFollowUp:
            return isActive && task.followUpAt.isEmpty
        case .blocked:
            return task.lane == .blocked
        }
    }

    public static func matchesQuery(_ task: WorkTask, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let locale = Locale(identifier: "id_ID")
        let needle = trimmed.lowercased(with: locale)
        let haystack = ([
            task.title,
            task.project,
            task.owner,
            task.nextAction
        ] + task.events.map(\.note))
            .joined(separator: " ")
            .lowercased(with: locale)
        return haystack.contains(needle)
    }

    public static func sortTasks(_ list: [WorkTask]) -> [WorkTask] {
        list.sorted { a, b in
            let aFollowUp = a.followUpAt.isEmpty ? "9999-12-31" : a.followUpAt
            let bFollowUp = b.followUpAt.isEmpty ? "9999-12-31" : b.followUpAt
            if aFollowUp != bFollowUp {
                return aFollowUp < bFollowUp
            }
            return a.updatedAt > b.updatedAt
        }
    }
}

#if canImport(AppKit)
import AppKit

public enum ProjectLauncher {
    public static func resolveURL(path: String) -> URL? {
        let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let expanded = (clean as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public static func isEditorInstalled(_ editor: CodeEditorApp) -> Bool {
        if editor == .finder || editor == .terminal {
            return true
        }
        for bundleId in editor.bundleIdentifiers {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil {
                return true
            }
        }
        for appName in editor.appNames {
            let standardPath = "/Applications/\(appName).app"
            let userPath = (NSHomeDirectory() as NSString).appendingPathComponent("Applications/\(appName).app")
            if FileManager.default.fileExists(atPath: standardPath) || FileManager.default.fileExists(atPath: userPath) {
                return true
            }
        }
        return false
    }

    @discardableResult
    public static func open(path: String, with editor: CodeEditorApp) -> (success: Bool, message: String) {
        let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return (false, "Path folder belum ditentukan.")
        }

        let expanded = (clean as NSString).expandingTildeInPath
        let folderURL = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            return (false, "Folder \"\(clean)\" tidak ditemukan di disk.")
        }

        if editor == .finder {
            NSWorkspace.shared.activateFileViewerSelecting([folderURL])
            return (true, "Membuka di Finder.")
        }

        for bundleId in editor.bundleIdentifiers {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.open([folderURL], withApplicationAt: appURL, configuration: configuration)
                return (true, "Membuka di \(editor.displayName)...")
            }
        }

        for appName in editor.appNames {
            let standardPath = "/Applications/\(appName).app"
            let userPath = (NSHomeDirectory() as NSString).appendingPathComponent("Applications/\(appName).app")
            let appPath = FileManager.default.fileExists(atPath: standardPath) ? standardPath : (FileManager.default.fileExists(atPath: userPath) ? userPath : nil)

            if let appPath {
                let appURL = URL(fileURLWithPath: appPath)
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.open([folderURL], withApplicationAt: appURL, configuration: configuration)
                return (true, "Membuka di \(editor.displayName)...")
            }
        }

        for appName in editor.appNames {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", appName, folderURL.path]
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return (true, "Membuka di \(editor.displayName)...")
                }
            } catch {
                continue
            }
        }

        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        return (false, "\(editor.displayName) tidak ditemukan. Membuka di Finder.")
    }
}

#if canImport(ServiceManagement)
import ServiceManagement

public enum LaunchAtLoginHelper {
    public static var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    public static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Result<Bool, Error> {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                return .success(SMAppService.mainApp.status == .enabled)
            } catch {
                return .failure(error)
            }
        }
        return .success(false)
    }
}
#endif
#endif


