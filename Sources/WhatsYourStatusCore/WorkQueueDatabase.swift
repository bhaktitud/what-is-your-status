import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class WorkQueueDatabase: @unchecked Sendable {
    public let databaseURL: URL

    public static var defaultDatabaseURL: URL {
        if let envPath = ProcessInfo.processInfo.environment["WORK_QUEUE_DB"], !envPath.isEmpty {
            let expanded = (envPath as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Work Queue", isDirectory: true)
            .appendingPathComponent("work-queue.sqlite3", isDirectory: false)
    }

    public init(databaseURL: URL = WorkQueueDatabase.defaultDatabaseURL) throws {
        self.databaseURL = databaseURL
        try initializeDatabase()
    }

    private func withConnection<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        let parentDir = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let openCode = sqlite3_open_v2(databaseURL.path, &db, flags, nil)
        guard openCode == SQLITE_OK, let connection = db else {
            if let db { sqlite3_close(db) }
            throw WorkQueueError.databaseFailure("SQLite gagal membaca atau menyimpan data. Periksa lokasi dan izin database.")
        }
        defer { sqlite3_close(connection) }

        sqlite3_busy_timeout(connection, 10_000)
        try execute(connection, sql: "PRAGMA foreign_keys = ON")
        return try body(connection)
    }

    private func inTransaction<T>(_ connection: OpaquePointer, _ body: () throws -> T) throws -> T {
        try execute(connection, sql: "BEGIN IMMEDIATE TRANSACTION")
        do {
            let result = try body()
            try execute(connection, sql: "COMMIT")
            return result
        } catch {
            _ = try? execute(connection, sql: "ROLLBACK")
            throw error
        }
    }

    private func execute(_ connection: OpaquePointer, sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(connection, sql, nil, nil, &errorMessage)
        if rc != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "SQLite error (\(rc))"
            sqlite3_free(errorMessage)
            if rc == SQLITE_CONSTRAINT {
                throw WorkQueueError.validation("Data bertabrakan dengan task yang sudah tersimpan.")
            }
            throw WorkQueueError.databaseFailure("SQLite gagal membaca atau menyimpan data: \(message)")
        }
    }

    private func prepare(_ connection: OpaquePointer, sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(connection, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let statement = stmt else {
            let msg = String(cString: sqlite3_errmsg(connection))
            throw WorkQueueError.databaseFailure("Gagal menyiapkan query SQLite: \(msg)")
        }
        return statement
    }

    private func bindText(_ statement: OpaquePointer, index: Int32, value: String) {
        _ = value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, sqliteTransient)
        }
    }

    private func columnString(_ statement: OpaquePointer, index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    private func bindDouble(_ statement: OpaquePointer, index: Int32, value: Double) {
        sqlite3_bind_double(statement, index, value)
    }

    private func columnDouble(_ statement: OpaquePointer, index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    private func bindOptionalDouble(_ statement: OpaquePointer, index: Int32, value: Double?) {
        if let value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func columnOptionalDouble(_ statement: OpaquePointer, index: Int32) -> Double? {
        if sqlite3_column_type(statement, index) == SQLITE_NULL {
            return nil
        }
        return sqlite3_column_double(statement, index)
    }

    private func bindBool(_ statement: OpaquePointer, index: Int32, value: Bool) {
        sqlite3_bind_int(statement, index, value ? 1 : 0)
    }

    private func columnBool(_ statement: OpaquePointer, index: Int32) -> Bool {
        sqlite3_column_int(statement, index) != 0
    }

    public func initializeDatabase() throws {
        try withConnection { connection in
            try execute(connection, sql: "PRAGMA journal_mode = WAL")
            let versionStmt = try prepare(connection, sql: "PRAGMA user_version")
            defer { sqlite3_finalize(versionStmt) }
            var version = 0
            if sqlite3_step(versionStmt) == SQLITE_ROW {
                version = Int(sqlite3_column_int(versionStmt, 0))
            }

            if version > 5 {
                throw WorkQueueError.unsupportedDatabaseVersion(version)
            }

            if version == 0 {
                try inTransaction(connection) {
                    try execute(
                        connection,
                        sql: """
                        CREATE TABLE tasks (
                            id TEXT PRIMARY KEY,
                            title TEXT NOT NULL,
                            project TEXT NOT NULL DEFAULT '',
                            lane TEXT NOT NULL CHECK (lane IN ('action', 'external', 'internal', 'blocked', 'done')),
                            owner TEXT NOT NULL,
                            next_action TEXT NOT NULL,
                            follow_up_at TEXT NOT NULL DEFAULT '',
                            updated_at TEXT NOT NULL,
                            is_example INTEGER NOT NULL DEFAULT 0 CHECK (is_example IN (0, 1)),
                            project_path TEXT NOT NULL DEFAULT ''
                        )
                        """
                    )
                    try execute(
                        connection,
                        sql: """
                        CREATE TABLE events (
                            sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                            id TEXT NOT NULL UNIQUE,
                            task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
                            date TEXT NOT NULL,
                            note TEXT NOT NULL
                        )
                        """
                    )
                    try execute(connection, sql: "CREATE INDEX tasks_updated_at_idx ON tasks(updated_at)")
                    try execute(connection, sql: "CREATE INDEX events_task_date_idx ON events(task_id, date, sequence)")
                    try execute(connection, sql: "PRAGMA user_version = 1")
                }
                version = 1
            }

            if version == 1 {
                try inTransaction(connection) {
                    try execute(
                        connection,
                        sql: """
                        CREATE TABLE people (
                            id TEXT PRIMARY KEY,
                            name TEXT NOT NULL COLLATE NOCASE UNIQUE
                        )
                        """
                    )

                    var ownersByLower: [String: String] = [:]
                    let ownerScan = try prepare(connection, sql: "SELECT id, owner FROM tasks ORDER BY id")
                    defer { sqlite3_finalize(ownerScan) }
                    var taskOwners: [(id: String, normalized: String)] = []
                    while sqlite3_step(ownerScan) == SQLITE_ROW {
                        let taskId = columnString(ownerScan, index: 0)
                        let rawOwner = columnString(ownerScan, index: 1)
                        let normalized = WorkDateFormatting.collapseWhitespace(rawOwner)
                        if !normalized.isEmpty {
                            let key = normalized.lowercased()
                            let resolved = key == "gue" ? "Saya" : normalized
                            let resolvedKey = resolved.lowercased()
                            if ownersByLower[resolvedKey] == nil {
                                ownersByLower[resolvedKey] = resolved
                            }
                            taskOwners.append((id: taskId, normalized: resolved))
                        }
                    }
                    ownersByLower["saya"] = "Saya"

                    let sortedNames = ownersByLower.values.sorted {
                        $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                    }
                    for name in sortedNames {
                        let insertStmt = try prepare(
                            connection,
                            sql: "INSERT OR IGNORE INTO people (id, name) VALUES (?, ?)"
                        )
                        defer { sqlite3_finalize(insertStmt) }
                        bindText(insertStmt, index: 1, value: UUID().uuidString.lowercased())
                        bindText(insertStmt, index: 2, value: name)
                        guard sqlite3_step(insertStmt) == SQLITE_DONE else {
                            throw WorkQueueError.databaseFailure("Gagal memigrasikan daftar orang.")
                        }
                    }

                    for item in taskOwners {
                        let canonical = try lookupPersonName(connection, name: item.normalized) ?? item.normalized
                        let updateStmt = try prepare(
                            connection,
                            sql: "UPDATE tasks SET owner = ? WHERE id = ?"
                        )
                        defer { sqlite3_finalize(updateStmt) }
                        bindText(updateStmt, index: 1, value: canonical)
                        bindText(updateStmt, index: 2, value: item.id)
                        guard sqlite3_step(updateStmt) == SQLITE_DONE else {
                            throw WorkQueueError.databaseFailure("Gagal menormalisasi penanggung jawab task.")
                        }
                    }

                    try execute(connection, sql: "PRAGMA user_version = 2")
                }
                version = 2
            }

            if version == 2 {
                try inTransaction(connection) {
                    try execute(
                        connection,
                        sql: """
                        CREATE TABLE workspaces (
                            id TEXT PRIMARY KEY,
                            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
                            created_at TEXT NOT NULL
                        )
                        """
                    )
                    let insertDefaultStmt = try prepare(
                        connection,
                        sql: "INSERT OR IGNORE INTO workspaces (id, name, created_at) VALUES ('default', 'Personal', ?)"
                    )
                    defer { sqlite3_finalize(insertDefaultStmt) }
                    bindText(insertDefaultStmt, index: 1, value: WorkDateFormatting.localISODate())
                    guard sqlite3_step(insertDefaultStmt) == SQLITE_DONE else {
                        throw WorkQueueError.databaseFailure("Gagal membuat workspace default.")
                    }

                    try execute(connection, sql: "ALTER TABLE tasks ADD COLUMN workspace_id TEXT NOT NULL DEFAULT 'default'")
                    try execute(connection, sql: "CREATE INDEX tasks_workspace_idx ON tasks(workspace_id)")
                    try execute(connection, sql: "PRAGMA user_version = 3")
                }
                version = 3
            }

            if version == 3 {
                try inTransaction(connection) {
                    try execute(
                        connection,
                        sql: "UPDATE tasks SET owner = 'Saya' WHERE LOWER(owner) = 'gue'"
                    )
                    let personId = UUID().uuidString.lowercased()
                    let insertStmt = try prepare(
                        connection,
                        sql: "INSERT OR IGNORE INTO people (id, name) VALUES (?, 'Saya')"
                    )
                    defer { sqlite3_finalize(insertStmt) }
                    bindText(insertStmt, index: 1, value: personId)
                    _ = sqlite3_step(insertStmt)

                    try execute(
                        connection,
                        sql: "DELETE FROM people WHERE LOWER(name) = 'gue'"
                    )
                    try execute(
                        connection,
                        sql: "UPDATE events SET note = REPLACE(note, 'Perlu gue gerakkan', 'Perlu saya gerakkan')"
                    )
                    try execute(
                        connection,
                        sql: "UPDATE events SET note = REPLACE(note, 'ke Gue', 'ke Saya')"
                    )
                    try execute(connection, sql: "PRAGMA user_version = 4")
                }
                version = 4
            }

            if version == 4 {
                try inTransaction(connection) {
                    try execute(
                        connection,
                        sql: """
                        CREATE TABLE sticky_notes (
                            id TEXT PRIMARY KEY,
                            workspace_id TEXT NOT NULL DEFAULT 'default',
                            content TEXT NOT NULL,
                            color TEXT NOT NULL,
                            x REAL NOT NULL,
                            y REAL NOT NULL,
                            width REAL NOT NULL,
                            height REAL NOT NULL,
                            author TEXT NOT NULL DEFAULT 'Saya',
                            note_type TEXT NOT NULL DEFAULT 'sticky',
                            created_at TEXT NOT NULL,
                            updated_at TEXT NOT NULL
                        )
                        """
                    )
                    try execute(connection, sql: "CREATE INDEX sticky_notes_workspace_idx ON sticky_notes(workspace_id)")
                    try execute(connection, sql: "PRAGMA user_version = 5")
                }
                version = 5
            }

            try execute(
                connection,
                sql: """
                CREATE TABLE IF NOT EXISTS board_lines (
                    id TEXT PRIMARY KEY,
                    workspace_id TEXT NOT NULL DEFAULT 'default',
                    start_x REAL NOT NULL,
                    start_y REAL NOT NULL,
                    end_x REAL NOT NULL,
                    end_y REAL NOT NULL,
                    color TEXT NOT NULL,
                    style TEXT NOT NULL DEFAULT 'arrow',
                    is_curved INTEGER NOT NULL DEFAULT 0,
                    control_x REAL,
                    control_y REAL,
                    control2_x REAL,
                    control2_y REAL,
                    label TEXT NOT NULL DEFAULT '',
                    created_at TEXT NOT NULL
                )
                """
            )
            _ = try? execute(connection, sql: "ALTER TABLE board_lines ADD COLUMN is_curved INTEGER NOT NULL DEFAULT 0")
            _ = try? execute(connection, sql: "ALTER TABLE board_lines ADD COLUMN control_x REAL")
            _ = try? execute(connection, sql: "ALTER TABLE board_lines ADD COLUMN control_y REAL")
            _ = try? execute(connection, sql: "ALTER TABLE board_lines ADD COLUMN control2_x REAL")
            _ = try? execute(connection, sql: "ALTER TABLE board_lines ADD COLUMN control2_y REAL")
            try execute(connection, sql: "CREATE INDEX IF NOT EXISTS board_lines_workspace_idx ON board_lines(workspace_id)")
            _ = try? execute(connection, sql: "ALTER TABLE tasks ADD COLUMN project_path TEXT NOT NULL DEFAULT ''")
        }
    }

    private func lookupPersonName(_ connection: OpaquePointer, name: String) throws -> String? {
        let stmt = try prepare(
            connection,
            sql: "SELECT name FROM people WHERE name = ? COLLATE NOCASE"
        )
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, index: 1, value: name)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return columnString(stmt, index: 0)
        }
        return nil
    }

    private func ensurePerson(_ connection: OpaquePointer, name: String) throws -> String {
        let normalized = WorkDateFormatting.collapseWhitespace(name)
        let insertStmt = try prepare(
            connection,
            sql: "INSERT OR IGNORE INTO people (id, name) VALUES (?, ?)"
        )
        defer { sqlite3_finalize(insertStmt) }
        bindText(insertStmt, index: 1, value: UUID().uuidString.lowercased())
        bindText(insertStmt, index: 2, value: normalized)
        guard sqlite3_step(insertStmt) == SQLITE_DONE else {
            throw WorkQueueError.databaseFailure("Gagal menyimpan penanggung jawab.")
        }
        return try lookupPersonName(connection, name: normalized) ?? normalized
    }

    private func addEventRow(
        _ connection: OpaquePointer,
        taskId: String,
        date: String,
        note: String,
        eventId: String? = nil
    ) throws {
        let stmt = try prepare(
            connection,
            sql: "INSERT INTO events (id, task_id, date, note) VALUES (?, ?, ?, ?)"
        )
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, index: 1, value: eventId ?? UUID().uuidString.lowercased())
        bindText(stmt, index: 2, value: taskId)
        bindText(stmt, index: 3, value: date)
        bindText(stmt, index: 4, value: note)
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE else {
            throw WorkQueueError.databaseFailure("Gagal menyimpan catatan update.")
        }
    }

    private func fetchTaskById(_ connection: OpaquePointer, taskId: String) throws -> WorkTask {
        let stmt = try prepare(
            connection,
            sql: """
            SELECT id, title, project, lane, owner, next_action, follow_up_at,
                   updated_at, is_example, workspace_id, project_path
            FROM tasks
            WHERE id = ?
            """
        )
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, index: 1, value: taskId)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw WorkQueueError.notFound("Task tidak ditemukan.")
        }

        let id = columnString(stmt, index: 0)
        let title = columnString(stmt, index: 1)
        let project = columnString(stmt, index: 2)
        let laneRaw = columnString(stmt, index: 3)
        let owner = columnString(stmt, index: 4)
        let nextAction = columnString(stmt, index: 5)
        let followUpAt = columnString(stmt, index: 6)
        let updatedAt = columnString(stmt, index: 7)
        let isExample = sqlite3_column_int(stmt, 8) != 0
        let workspaceId = columnString(stmt, index: 9)
        let projectPath = columnString(stmt, index: 10)

        guard let lane = TaskLane(rawValue: laneRaw) else {
            throw WorkQueueError.databaseFailure("Status task di database tidak dikenali.")
        }

        let eventStmt = try prepare(
            connection,
            sql: "SELECT id, date, note FROM events WHERE task_id = ? ORDER BY date, sequence"
        )
        defer { sqlite3_finalize(eventStmt) }
        bindText(eventStmt, index: 1, value: taskId)
        var events: [TaskEvent] = []
        while sqlite3_step(eventStmt) == SQLITE_ROW {
            events.append(
                TaskEvent(
                    id: columnString(eventStmt, index: 0),
                    date: columnString(eventStmt, index: 1),
                    note: columnString(eventStmt, index: 2)
                )
            )
        }

        return WorkTask(
            id: id,
            title: title,
            project: project,
            lane: lane,
            owner: owner,
            nextAction: nextAction,
            followUpAt: followUpAt,
            updatedAt: updatedAt,
            isExample: isExample,
            workspaceId: workspaceId.isEmpty ? "default" : workspaceId,
            projectPath: projectPath,
            events: events
        )
    }

    private func validateDraft(_ draft: TaskDraft) throws -> (
        title: String,
        project: String,
        lane: TaskLane,
        owner: String,
        nextAction: String,
        followUpAt: String,
        projectPath: String
    ) {
        let title = WorkDateFormatting.collapseWhitespace(draft.title)
        let project = WorkDateFormatting.collapseWhitespace(draft.project)
        let owner = WorkDateFormatting.collapseWhitespace(draft.owner)
        let nextAction = WorkDateFormatting.collapseWhitespace(draft.nextAction)
        let followUpAt = WorkDateFormatting.collapseWhitespace(draft.followUpAt)
        let projectPath = WorkDateFormatting.collapseWhitespace(draft.projectPath)

        if title.count > 140 {
            throw WorkQueueError.validation("Field title melebihi batas 140 karakter.")
        }
        if project.count > 100 {
            throw WorkQueueError.validation("Field project melebihi batas 100 karakter.")
        }
        if owner.count > 80 {
            throw WorkQueueError.validation("Field owner melebihi batas 80 karakter.")
        }
        if nextAction.count > 240 {
            throw WorkQueueError.validation("Field nextAction melebihi batas 240 karakter.")
        }
        if projectPath.count > 1000 {
            throw WorkQueueError.validation("Path folder proyek melebihi batas 1000 karakter.")
        }
        if title.isEmpty {
            throw WorkQueueError.validation("Field title harus diisi.")
        }
        if owner.isEmpty {
            throw WorkQueueError.validation("Field owner harus diisi.")
        }
        if nextAction.isEmpty {
            throw WorkQueueError.validation("Field nextAction harus diisi.")
        }
        _ = try WorkDateFormatting.validateISODate(followUpAt, field: "followUpAt", allowEmpty: true)

        return (title, project, draft.lane, owner, nextAction, followUpAt, projectPath)
    }

    public func listPeople() throws -> [Person] {
        try withConnection { connection in
            let stmt = try prepare(
                connection,
                sql: "SELECT id, name FROM people ORDER BY name COLLATE NOCASE, id"
            )
            defer { sqlite3_finalize(stmt) }
            var people: [Person] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                people.append(
                    Person(
                        id: columnString(stmt, index: 0),
                        name: columnString(stmt, index: 1)
                    )
                )
            }
            return people
        }
    }

    public func addPerson(name: String) throws -> Person {
        let normalized = WorkDateFormatting.collapseWhitespace(name)
        guard !normalized.isEmpty else {
            throw WorkQueueError.validation("Nama orang harus diisi.")
        }
        guard normalized.count <= 80 else {
            throw WorkQueueError.validation("Nama orang tidak boleh lebih dari 80 karakter.")
        }

        return try withConnection { connection in
            try inTransaction(connection) {
                if try lookupPersonName(connection, name: normalized) != nil {
                    throw WorkQueueError.duplicatePerson("Nama orang ini sudah ada.")
                }
                let personId = UUID().uuidString.lowercased()
                let insertStmt = try prepare(
                    connection,
                    sql: "INSERT INTO people (id, name) VALUES (?, ?)"
                )
                defer { sqlite3_finalize(insertStmt) }
                bindText(insertStmt, index: 1, value: personId)
                bindText(insertStmt, index: 2, value: normalized)
                guard sqlite3_step(insertStmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal menyimpan orang baru.")
                }

                let selectStmt = try prepare(
                    connection,
                    sql: "SELECT id, name FROM people WHERE name = ? COLLATE NOCASE"
                )
                defer { sqlite3_finalize(selectStmt) }
                bindText(selectStmt, index: 1, value: normalized)
                guard sqlite3_step(selectStmt) == SQLITE_ROW else {
                    throw WorkQueueError.databaseFailure("Gagal membaca orang yang baru disimpan.")
                }
                return Person(
                    id: columnString(selectStmt, index: 0),
                    name: columnString(selectStmt, index: 1)
                )
            }
        }
    }

    public func listWorkspaces() throws -> [Workspace] {
        try withConnection { connection in
            let stmt = try prepare(
                connection,
                sql: "SELECT id, name, created_at FROM workspaces ORDER BY CASE WHEN id = 'default' THEN 0 ELSE 1 END, name COLLATE NOCASE, id"
            )
            defer { sqlite3_finalize(stmt) }
            var workspaces: [Workspace] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                workspaces.append(
                    Workspace(
                        id: columnString(stmt, index: 0),
                        name: columnString(stmt, index: 1),
                        createdAt: columnString(stmt, index: 2)
                    )
                )
            }
            return workspaces
        }
    }

    public func createWorkspace(name: String, today: String = WorkDateFormatting.localISODate()) throws -> Workspace {
        let normalized = WorkDateFormatting.collapseWhitespace(name)
        guard !normalized.isEmpty else {
            throw WorkQueueError.validation("Nama workspace harus diisi.")
        }
        guard normalized.count <= 60 else {
            throw WorkQueueError.validation("Nama workspace tidak boleh lebih dari 60 karakter.")
        }

        return try withConnection { connection in
            try inTransaction(connection) {
                let checkStmt = try prepare(
                    connection,
                    sql: "SELECT id, name, created_at FROM workspaces WHERE name = ? COLLATE NOCASE"
                )
                defer { sqlite3_finalize(checkStmt) }
                bindText(checkStmt, index: 1, value: normalized)
                if sqlite3_step(checkStmt) == SQLITE_ROW {
                    throw WorkQueueError.validation("Workspace dengan nama \"\(normalized)\" sudah ada.")
                }

                let newId = UUID().uuidString.lowercased()
                let insertStmt = try prepare(
                    connection,
                    sql: "INSERT INTO workspaces (id, name, created_at) VALUES (?, ?, ?)"
                )
                defer { sqlite3_finalize(insertStmt) }
                bindText(insertStmt, index: 1, value: newId)
                bindText(insertStmt, index: 2, value: normalized)
                bindText(insertStmt, index: 3, value: today)

                let rc = sqlite3_step(insertStmt)
                if rc == SQLITE_CONSTRAINT {
                    throw WorkQueueError.validation("Workspace dengan nama tersebut sudah ada.")
                }
                guard rc == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal membuat workspace baru.")
                }

                return Workspace(id: newId, name: normalized, createdAt: today)
            }
        }
    }

    public func deleteWorkspace(id: String) throws {
        guard id != "default" else {
            throw WorkQueueError.validation("Workspace Personal (utama) tidak dapat dihapus.")
        }
        try withConnection { connection in
            try inTransaction(connection) {
                let moveStmt = try prepare(
                    connection,
                    sql: "UPDATE tasks SET workspace_id = 'default' WHERE workspace_id = ?"
                )
                defer { sqlite3_finalize(moveStmt) }
                bindText(moveStmt, index: 1, value: id)
                guard sqlite3_step(moveStmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal memindahkan task ke workspace utama.")
                }

                let deleteStmt = try prepare(
                    connection,
                    sql: "DELETE FROM workspaces WHERE id = ?"
                )
                defer { sqlite3_finalize(deleteStmt) }
                bindText(deleteStmt, index: 1, value: id)
                guard sqlite3_step(deleteStmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal menghapus workspace.")
                }
            }
        }
    }

    public func listTasks() throws -> [WorkTask] {
        try withConnection { connection in
            let stmt = try prepare(
                connection,
                sql: "SELECT id FROM tasks ORDER BY updated_at DESC, id"
            )
            defer { sqlite3_finalize(stmt) }
            var taskIds: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                taskIds.append(columnString(stmt, index: 0))
            }
            return try taskIds.map { try fetchTaskById(connection, taskId: $0) }
        }
    }

    public func createTask(_ draft: TaskDraft, today: String = WorkDateFormatting.localISODate()) throws -> WorkTask {
        let validated = try validateDraft(draft)
        let rawId = (draft.id ?? UUID().uuidString.lowercased()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawId.isEmpty && rawId.count <= 80 else {
            throw WorkQueueError.validation("Task membutuhkan id yang valid.")
        }

        if let customEvents = draft.events {
            if customEvents.count > 100 {
                throw WorkQueueError.validation("Task memiliki terlalu banyak catatan.")
            }
            for event in customEvents {
                _ = try WorkDateFormatting.validateISODate(event.date, field: "Tanggal update")
                let trimmedNote = event.note.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedNote.isEmpty || trimmedNote.count > 240 {
                    throw WorkQueueError.validation("Setiap catatan update harus berisi maksimal 240 karakter.")
                }
            }
        }

        return try withConnection { connection in
            try inTransaction(connection) {
                let canonicalOwner = try ensurePerson(connection, name: validated.owner)
                let targetWorkspaceId = draft.workspaceId.isEmpty ? "default" : draft.workspaceId

                let insertStmt = try prepare(
                    connection,
                    sql: """
                    INSERT INTO tasks
                        (id, title, project, lane, owner, next_action, follow_up_at, updated_at, is_example, workspace_id, project_path)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """
                )
                defer { sqlite3_finalize(insertStmt) }
                bindText(insertStmt, index: 1, value: rawId)
                bindText(insertStmt, index: 2, value: validated.title)
                bindText(insertStmt, index: 3, value: validated.project)
                bindText(insertStmt, index: 4, value: validated.lane.rawValue)
                bindText(insertStmt, index: 5, value: canonicalOwner)
                bindText(insertStmt, index: 6, value: validated.nextAction)
                bindText(insertStmt, index: 7, value: validated.followUpAt)
                bindText(insertStmt, index: 8, value: today)
                sqlite3_bind_int(insertStmt, 9, draft.isExample ? 1 : 0)
                bindText(insertStmt, index: 10, value: targetWorkspaceId)
                bindText(insertStmt, index: 11, value: validated.projectPath)

                let rc = sqlite3_step(insertStmt)
                if rc == SQLITE_CONSTRAINT {
                    throw WorkQueueError.validation("Data bertabrakan dengan task yang sudah tersimpan.")
                }
                guard rc == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal menyimpan task baru.")
                }

                if let customEvents = draft.events {
                    for event in customEvents {
                        try addEventRow(
                            connection,
                            taskId: rawId,
                            date: event.date,
                            note: event.note.trimmingCharacters(in: .whitespacesAndNewlines),
                            eventId: event.id.isEmpty ? nil : event.id
                        )
                    }
                } else {
                    try addEventRow(connection, taskId: rawId, date: today, note: "Task dibuat.")
                }

                return try fetchTaskById(connection, taskId: rawId)
            }
        }
    }

    public func updateTask(
        id taskId: String,
        draft: TaskDraft,
        today: String = WorkDateFormatting.localISODate()
    ) throws -> WorkTask {
        let validated = try validateDraft(draft)

        return try withConnection { connection in
            try inTransaction(connection) {
                let currentStmt = try prepare(
                    connection,
                    sql: """
                    SELECT lane, owner, title, project, next_action, follow_up_at, workspace_id, project_path
                    FROM tasks
                    WHERE id = ?
                    """
                )
                defer { sqlite3_finalize(currentStmt) }
                bindText(currentStmt, index: 1, value: taskId)
                guard sqlite3_step(currentStmt) == SQLITE_ROW else {
                    throw WorkQueueError.notFound("Task tidak ditemukan.")
                }

                let currentLane = columnString(currentStmt, index: 0)
                let currentOwner = columnString(currentStmt, index: 1)
                let currentTitle = columnString(currentStmt, index: 2)
                let currentProject = columnString(currentStmt, index: 3)
                let currentNextAction = columnString(currentStmt, index: 4)
                let currentFollowUpAt = columnString(currentStmt, index: 5)
                let currentWorkspaceId = columnString(currentStmt, index: 6)
                let currentProjectPath = columnString(currentStmt, index: 7)

                let canonicalOwner = try ensurePerson(connection, name: validated.owner)
                let targetWorkspaceId = draft.workspaceId.isEmpty ? "default" : draft.workspaceId

                let updateStmt = try prepare(
                    connection,
                    sql: """
                    UPDATE tasks
                    SET title = ?, project = ?, lane = ?, owner = ?, next_action = ?,
                        follow_up_at = ?, updated_at = ?, is_example = 0, workspace_id = ?, project_path = ?
                    WHERE id = ?
                    """
                )
                defer { sqlite3_finalize(updateStmt) }
                bindText(updateStmt, index: 1, value: validated.title)
                bindText(updateStmt, index: 2, value: validated.project)
                bindText(updateStmt, index: 3, value: validated.lane.rawValue)
                bindText(updateStmt, index: 4, value: canonicalOwner)
                bindText(updateStmt, index: 5, value: validated.nextAction)
                bindText(updateStmt, index: 6, value: validated.followUpAt)
                bindText(updateStmt, index: 7, value: today)
                bindText(updateStmt, index: 8, value: targetWorkspaceId)
                bindText(updateStmt, index: 9, value: validated.projectPath)
                bindText(updateStmt, index: 10, value: taskId)

                guard sqlite3_step(updateStmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal memperbarui task.")
                }

                if currentLane != validated.lane.rawValue {
                    try addEventRow(
                        connection,
                        taskId: taskId,
                        date: today,
                        note: "Status diubah ke \(validated.lane.label)."
                    )
                }
                if currentOwner != canonicalOwner {
                    try addEventRow(
                        connection,
                        taskId: taskId,
                        date: today,
                        note: "Penanggung jawab diubah ke \(canonicalOwner)."
                    )
                }
                if currentTitle != validated.title {
                    try addEventRow(connection, taskId: taskId, date: today, note: "Nama task diperbarui.")
                }
                if currentProject != validated.project {
                    try addEventRow(connection, taskId: taskId, date: today, note: "Proyek task diperbarui.")
                }
                if currentNextAction != validated.nextAction {
                    try addEventRow(connection, taskId: taskId, date: today, note: "Langkah berikutnya diperbarui.")
                }
                if currentFollowUpAt != validated.followUpAt {
                    let note = validated.followUpAt.isEmpty
                        ? "Jadwal follow-up dihapus."
                        : "Jadwal follow-up diatur ke \(validated.followUpAt)."
                    try addEventRow(connection, taskId: taskId, date: today, note: note)
                }
                if currentWorkspaceId != targetWorkspaceId {
                    try addEventRow(connection, taskId: taskId, date: today, note: "Workspace task dipindahkan.")
                }
                if currentProjectPath != validated.projectPath {
                    let note = validated.projectPath.isEmpty
                        ? "Folder proyek dilepas."
                        : "Folder proyek dihubungkan: \(validated.projectPath)"
                    try addEventRow(connection, taskId: taskId, date: today, note: note)
                }

                return try fetchTaskById(connection, taskId: taskId)
            }
        }
    }

    public func updateTaskProjectPath(
        id taskId: String,
        projectPath: String,
        today: String = WorkDateFormatting.localISODate()
    ) throws -> WorkTask {
        let normalized = WorkDateFormatting.collapseWhitespace(projectPath)
        if normalized.count > 1000 {
            throw WorkQueueError.validation("Path folder proyek melebihi batas 1000 karakter.")
        }

        return try withConnection { connection in
            try inTransaction(connection) {
                let current = try fetchTaskById(connection, taskId: taskId)
                let updateStmt = try prepare(
                    connection,
                    sql: "UPDATE tasks SET project_path = ?, updated_at = ? WHERE id = ?"
                )
                defer { sqlite3_finalize(updateStmt) }
                bindText(updateStmt, index: 1, value: normalized)
                bindText(updateStmt, index: 2, value: today)
                bindText(updateStmt, index: 3, value: taskId)

                guard sqlite3_step(updateStmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal memperbarui folder proyek.")
                }

                if current.projectPath != normalized {
                    let note = normalized.isEmpty
                        ? "Folder proyek dilepas."
                        : "Folder proyek dihubungkan: \(normalized)"
                    try addEventRow(connection, taskId: taskId, date: today, note: note)
                }

                return try fetchTaskById(connection, taskId: taskId)
            }
        }
    }

    public func addEvent(
        taskId: String,
        date: String,
        note: String,
        today: String = WorkDateFormatting.localISODate()
    ) throws -> WorkTask {
        let validatedDate = try WorkDateFormatting.validateISODate(date, field: "Tanggal update")
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty && trimmedNote.count <= 240 else {
            throw WorkQueueError.validation("Catatan update harus berisi maksimal 240 karakter.")
        }

        return try withConnection { connection in
            try inTransaction(connection) {
                let updateStmt = try prepare(
                    connection,
                    sql: "UPDATE tasks SET updated_at = ?, is_example = 0 WHERE id = ?"
                )
                defer { sqlite3_finalize(updateStmt) }
                bindText(updateStmt, index: 1, value: today)
                bindText(updateStmt, index: 2, value: taskId)
                guard sqlite3_step(updateStmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal memperbarui waktu task.")
                }
                if sqlite3_changes(connection) == 0 {
                    throw WorkQueueError.notFound("Task tidak ditemukan.")
                }

                try addEventRow(connection, taskId: taskId, date: validatedDate, note: trimmedNote)
                return try fetchTaskById(connection, taskId: taskId)
            }
        }
    }

    public func deleteTask(id taskId: String) throws {
        try withConnection { connection in
            try inTransaction(connection) {
                let stmt = try prepare(connection, sql: "DELETE FROM tasks WHERE id = ?")
                defer { sqlite3_finalize(stmt) }
                bindText(stmt, index: 1, value: taskId)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal menghapus task.")
                }
                if sqlite3_changes(connection) == 0 {
                    throw WorkQueueError.notFound("Task tidak ditemukan.")
                }
            }
        }
    }

    public func createExampleTask() throws -> WorkTask {
        let draft = TaskDraft(
            title: "Integrasi WebBeds ke TourPlan",
            project: "WebBeds ke TourPlan",
            lane: .action,
            owner: "Saya",
            nextAction: "Follow up mapping process dan kebutuhan freelancer",
            followUpAt: "",
            isExample: true,
            events: [
                TaskEvent(date: "2026-10-12", note: "Email ke Jared sudah dikirim"),
                TaskEvent(date: "2026-10-13", note: "Jared sudah membalas")
            ]
        )
        return try createTask(draft)
    }

    public func listStickyNotes(workspaceId: String? = nil) throws -> [StickyNote] {
        try withConnection { connection in
            let sql: String
            if let workspaceId = workspaceId, !workspaceId.isEmpty {
                sql = "SELECT id, workspace_id, content, color, x, y, width, height, author, note_type, created_at, updated_at FROM sticky_notes WHERE workspace_id = ? ORDER BY created_at ASC"
            } else {
                sql = "SELECT id, workspace_id, content, color, x, y, width, height, author, note_type, created_at, updated_at FROM sticky_notes ORDER BY created_at ASC"
            }
            let stmt = try prepare(connection, sql: sql)
            defer { sqlite3_finalize(stmt) }
            if let workspaceId = workspaceId, !workspaceId.isEmpty {
                bindText(stmt, index: 1, value: workspaceId)
            }
            var notes: [StickyNote] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = columnString(stmt, index: 0)
                let wsId = columnString(stmt, index: 1)
                let content = columnString(stmt, index: 2)
                let colorRaw = columnString(stmt, index: 3)
                let color = StickyColor(rawValue: colorRaw) ?? .yellow
                let x = columnDouble(stmt, index: 4)
                let y = columnDouble(stmt, index: 5)
                let width = columnDouble(stmt, index: 6)
                let height = columnDouble(stmt, index: 7)
                let author = columnString(stmt, index: 8)
                let typeRaw = columnString(stmt, index: 9)
                let noteType = StickyType(rawValue: typeRaw) ?? .sticky
                let createdAt = columnString(stmt, index: 10)
                let updatedAt = columnString(stmt, index: 11)

                notes.append(StickyNote(
                    id: id,
                    workspaceId: wsId,
                    content: content,
                    color: color,
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    author: author,
                    noteType: noteType,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                ))
            }
            return notes
        }
    }

    public func createStickyNote(_ note: StickyNote) throws -> StickyNote {
        try withConnection { connection in
            try inTransaction(connection) {
                let stmt = try prepare(
                    connection,
                    sql: """
                    INSERT INTO sticky_notes (id, workspace_id, content, color, x, y, width, height, author, note_type, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """
                )
                defer { sqlite3_finalize(stmt) }
                bindText(stmt, index: 1, value: note.id)
                bindText(stmt, index: 2, value: note.workspaceId)
                bindText(stmt, index: 3, value: note.content)
                bindText(stmt, index: 4, value: note.color.rawValue)
                bindDouble(stmt, index: 5, value: note.x)
                bindDouble(stmt, index: 6, value: note.y)
                bindDouble(stmt, index: 7, value: note.width)
                bindDouble(stmt, index: 8, value: note.height)
                bindText(stmt, index: 9, value: note.author)
                bindText(stmt, index: 10, value: note.noteType.rawValue)
                bindText(stmt, index: 11, value: note.createdAt)
                bindText(stmt, index: 12, value: note.updatedAt)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal membuat sticky note.")
                }
                return note
            }
        }
    }

    public func updateStickyNote(_ note: StickyNote) throws -> StickyNote {
        try withConnection { connection in
            try inTransaction(connection) {
                let stmt = try prepare(
                    connection,
                    sql: """
                    UPDATE sticky_notes
                    SET content = ?, color = ?, x = ?, y = ?, width = ?, height = ?, author = ?, note_type = ?, updated_at = ?
                    WHERE id = ?
                    """
                )
                defer { sqlite3_finalize(stmt) }
                bindText(stmt, index: 1, value: note.content)
                bindText(stmt, index: 2, value: note.color.rawValue)
                bindDouble(stmt, index: 3, value: note.x)
                bindDouble(stmt, index: 4, value: note.y)
                bindDouble(stmt, index: 5, value: note.width)
                bindDouble(stmt, index: 6, value: note.height)
                bindText(stmt, index: 7, value: note.author)
                bindText(stmt, index: 8, value: note.noteType.rawValue)
                bindText(stmt, index: 9, value: note.updatedAt)
                bindText(stmt, index: 10, value: note.id)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal memperbarui sticky note.")
                }
                return note
            }
        }
    }

    public func deleteStickyNote(id: String) throws {
        try withConnection { connection in
            try inTransaction(connection) {
                let stmt = try prepare(connection, sql: "DELETE FROM sticky_notes WHERE id = ?")
                defer { sqlite3_finalize(stmt) }
                bindText(stmt, index: 1, value: id)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal menghapus sticky note.")
                }
            }
        }
    }

    public func seedExampleStickyNotes(workspaceId: String) throws -> [StickyNote] {
        let examples: [StickyNote] = [
            StickyNote(
                workspaceId: workspaceId,
                content: "Bagaimana cara tim tetap produktif dan selaras saat WFH?",
                color: .yellow,
                x: 260,
                y: 120,
                width: 340,
                height: 90,
                author: "Saya",
                noteType: .text
            ),
            StickyNote(
                workspaceId: workspaceId,
                content: "Daily standup singkat 15 menit via Huddle untuk update blocker.",
                color: .yellow,
                x: 100,
                y: 260,
                width: 190,
                height: 190,
                author: "Saya",
                noteType: .sticky
            ),
            StickyNote(
                workspaceId: workspaceId,
                content: "Integrasi API WebBeds x TourPlan: verifikasi mapping room type.",
                color: .blue,
                x: 320,
                y: 260,
                width: 190,
                height: 190,
                author: "Pak Adrian",
                noteType: .sticky
            ),
            StickyNote(
                workspaceId: workspaceId,
                content: "Pastikan SLA kontrak hotel sudah di-review legal sebelum rilis.",
                color: .purple,
                x: 540,
                y: 260,
                width: 190,
                height: 190,
                author: "Bu Andriyani",
                noteType: .sticky
            ),
            StickyNote(
                workspaceId: workspaceId,
                content: "Testing sandbox payment gateway dengan kartu uji coba.",
                color: .orange,
                x: 210,
                y: 480,
                width: 190,
                height: 190,
                author: "Edo",
                noteType: .sticky
            ),
            StickyNote(
                workspaceId: workspaceId,
                content: "Jadwalkan review arsitektur booking system hari Jumat.",
                color: .green,
                x: 430,
                y: 480,
                width: 190,
                height: 190,
                author: "Saya",
                noteType: .sticky
            )
        ]

        var created: [StickyNote] = []
        for note in examples {
            created.append(try createStickyNote(note))
        }

        let exampleLines: [BoardLine] = [
            BoardLine(
                workspaceId: workspaceId,
                startX: 420,
                startY: 210,
                endX: 415,
                endY: 260,
                color: "#64748B",
                style: .arrow,
                isCurved: true,
                controlX: 440,
                controlY: 235
            ),
            BoardLine(
                workspaceId: workspaceId,
                startX: 370,
                startY: 450,
                endX: 300,
                endY: 480,
                color: "#3B82F6",
                style: .arrow,
                isCurved: true,
                controlX: 350,
                controlY: 480,
                label: "Menghosting"
            )
        ]
        for line in exampleLines {
            _ = try? createBoardLine(line)
        }

        return created
    }

    // MARK: - Board Lines Management
    public func listBoardLines(workspaceId: String? = nil) throws -> [BoardLine] {
        try withConnection { connection in
            let sql: String
            if let workspaceId = workspaceId, !workspaceId.isEmpty {
                sql = "SELECT id, workspace_id, start_x, start_y, end_x, end_y, color, style, is_curved, control_x, control_y, control2_x, control2_y, label, created_at FROM board_lines WHERE workspace_id = ? ORDER BY created_at ASC"
            } else {
                sql = "SELECT id, workspace_id, start_x, start_y, end_x, end_y, color, style, is_curved, control_x, control_y, control2_x, control2_y, label, created_at FROM board_lines ORDER BY created_at ASC"
            }
            let stmt = try prepare(connection, sql: sql)
            defer { sqlite3_finalize(stmt) }
            if let workspaceId = workspaceId, !workspaceId.isEmpty {
                bindText(stmt, index: 1, value: workspaceId)
            }
            var lines: [BoardLine] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = columnString(stmt, index: 0)
                let wsId = columnString(stmt, index: 1)
                let sx = columnDouble(stmt, index: 2)
                let sy = columnDouble(stmt, index: 3)
                let ex = columnDouble(stmt, index: 4)
                let ey = columnDouble(stmt, index: 5)
                let color = columnString(stmt, index: 6)
                let styleRaw = columnString(stmt, index: 7)
                let style = LineCapStyle(rawValue: styleRaw) ?? .arrow
                let isCurved = columnBool(stmt, index: 8)
                let cx = columnOptionalDouble(stmt, index: 9)
                let cy = columnOptionalDouble(stmt, index: 10)
                let c2x = columnOptionalDouble(stmt, index: 11)
                let c2y = columnOptionalDouble(stmt, index: 12)
                let label = columnString(stmt, index: 13)
                let createdAt = columnString(stmt, index: 14)

                lines.append(BoardLine(
                    id: id,
                    workspaceId: wsId,
                    startX: sx,
                    startY: sy,
                    endX: ex,
                    endY: ey,
                    color: color,
                    style: style,
                    isCurved: isCurved,
                    controlX: cx,
                    controlY: cy,
                    control2X: c2x,
                    control2Y: c2y,
                    label: label,
                    createdAt: createdAt
                ))
            }
            return lines
        }
    }

    public func createBoardLine(_ line: BoardLine) throws -> BoardLine {
        try withConnection { connection in
            try inTransaction(connection) {
                let stmt = try prepare(
                    connection,
                    sql: """
                    INSERT INTO board_lines (id, workspace_id, start_x, start_y, end_x, end_y, color, style, is_curved, control_x, control_y, control2_x, control2_y, label, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """
                )
                defer { sqlite3_finalize(stmt) }
                bindText(stmt, index: 1, value: line.id)
                bindText(stmt, index: 2, value: line.workspaceId)
                bindDouble(stmt, index: 3, value: line.startX)
                bindDouble(stmt, index: 4, value: line.startY)
                bindDouble(stmt, index: 5, value: line.endX)
                bindDouble(stmt, index: 6, value: line.endY)
                bindText(stmt, index: 7, value: line.color)
                bindText(stmt, index: 8, value: line.style.rawValue)
                bindBool(stmt, index: 9, value: line.isCurved)
                bindOptionalDouble(stmt, index: 10, value: line.controlX)
                bindOptionalDouble(stmt, index: 11, value: line.controlY)
                bindOptionalDouble(stmt, index: 12, value: line.control2X)
                bindOptionalDouble(stmt, index: 13, value: line.control2Y)
                bindText(stmt, index: 14, value: line.label)
                bindText(stmt, index: 15, value: line.createdAt)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal membuat garis.")
                }
                return line
            }
        }
    }

    public func updateBoardLine(_ line: BoardLine) throws -> BoardLine {
        try withConnection { connection in
            try inTransaction(connection) {
                let stmt = try prepare(
                    connection,
                    sql: """
                    UPDATE board_lines
                    SET start_x = ?, start_y = ?, end_x = ?, end_y = ?, color = ?, style = ?, is_curved = ?, control_x = ?, control_y = ?, control2_x = ?, control2_y = ?, label = ?
                    WHERE id = ?
                    """
                )
                defer { sqlite3_finalize(stmt) }
                bindDouble(stmt, index: 1, value: line.startX)
                bindDouble(stmt, index: 2, value: line.startY)
                bindDouble(stmt, index: 3, value: line.endX)
                bindDouble(stmt, index: 4, value: line.endY)
                bindText(stmt, index: 5, value: line.color)
                bindText(stmt, index: 6, value: line.style.rawValue)
                bindBool(stmt, index: 7, value: line.isCurved)
                bindOptionalDouble(stmt, index: 8, value: line.controlX)
                bindOptionalDouble(stmt, index: 9, value: line.controlY)
                bindOptionalDouble(stmt, index: 10, value: line.control2X)
                bindOptionalDouble(stmt, index: 11, value: line.control2Y)
                bindText(stmt, index: 12, value: line.label)
                bindText(stmt, index: 13, value: line.id)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal memperbarui garis.")
                }
                return line
            }
        }
    }

    public func deleteBoardLine(id: String) throws {
        try withConnection { connection in
            try inTransaction(connection) {
                let stmt = try prepare(connection, sql: "DELETE FROM board_lines WHERE id = ?")
                defer { sqlite3_finalize(stmt) }
                bindText(stmt, index: 1, value: id)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw WorkQueueError.databaseFailure("Gagal menghapus garis.")
                }
            }
        }
    }
}
