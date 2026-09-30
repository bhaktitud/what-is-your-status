import Foundation
import SQLite3
import XCTest
@testable import WhatsYourStatusCore

final class WorkQueueDatabaseTests: XCTestCase {
    private var tempDirectory: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whats-your-status-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        databaseURL = tempDirectory.appendingPathComponent("work-queue.sqlite3")
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    private func sampleDraft(
        id: String = "task-1",
        title: String = "Integrasi WebBeds ke TourPlan",
        project: String = "Integrasi",
        lane: TaskLane = .action,
        owner: String = "Saya",
        nextAction: String = "Follow up mapping process",
        followUpAt: String = "",
        isExample: Bool = false,
        workspaceId: String = "default",
        projectPath: String = "",
        events: [TaskEvent]? = nil
    ) -> TaskDraft {
        TaskDraft(
            id: id,
            title: title,
            project: project,
            lane: lane,
            owner: owner,
            nextAction: nextAction,
            followUpAt: followUpAt,
            isExample: isExample,
            workspaceId: workspaceId,
            projectPath: projectPath,
            events: events
        )
    }

    func testTaskAndTimelinePersistAcrossDatabaseReopen() throws {
        let db1 = try WorkQueueDatabase(databaseURL: databaseURL)
        let created = try db1.createTask(
            sampleDraft(
                isExample: true,
                events: [
                    TaskEvent(date: "2026-10-12", note: "Email ke Jared sudah dikirim"),
                    TaskEvent(date: "2026-10-13", note: "Jared sudah membalas")
                ]
            ),
            today: "2026-09-30"
        )
        XCTAssertEqual(created.events.map(\.date), ["2026-10-12", "2026-10-13"])

        let db2 = try WorkQueueDatabase(databaseURL: databaseURL)
        let tasks = try db2.listTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].title, "Integrasi WebBeds ke TourPlan")
        XCTAssertEqual(tasks[0].events[1].note, "Jared sudah membalas")
    }

    func testEditingOwnerAndStatusRecordsHistory() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        _ = try db.createTask(sampleDraft(), today: "2026-09-30")

        let updated = try db.updateTask(
            id: "task-1",
            draft: sampleDraft(lane: .external, owner: "Jared", followUpAt: "2026-10-20"),
            today: "2026-09-30"
        )
        XCTAssertEqual(updated.lane, .external)
        XCTAssertEqual(updated.owner, "Jared")
        XCTAssertEqual(updated.followUpAt, "2026-10-20")

        let notes = updated.events.map(\.note)
        XCTAssertTrue(notes.contains("Status diubah ke Nunggu pihak luar."))
        XCTAssertTrue(notes.contains("Penanggung jawab diubah ke Jared."))
        XCTAssertTrue(notes.contains("Jadwal follow-up diatur ke 2026-10-20."))
    }

    func testEditingNextActionIsRecordedInTimeline() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        _ = try db.createTask(sampleDraft(), today: "2026-09-30")

        let updated = try db.updateTask(
            id: "task-1",
            draft: sampleDraft(nextAction: "Tunggu balasan dari Jared"),
            today: "2026-09-30"
        )
        XCTAssertEqual(updated.nextAction, "Tunggu balasan dari Jared")
        XCTAssertTrue(updated.events.map(\.note).contains("Langkah berikutnya diperbarui."))
    }

    func testPeopleCanBeAddedAndNormalized() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        let added = try db.addPerson(name: "  Jared   Smith  ")
        XCTAssertEqual(added.name, "Jared Smith")

        XCTAssertThrowsError(try db.addPerson(name: "jared smith")) { error in
            XCTAssertEqual(error as? WorkQueueError, .duplicatePerson("Nama orang ini sudah ada."))
        }

        let people = try db.listPeople()
        XCTAssertEqual(people.map(\.name), ["Jared Smith", "Saya"])
    }

    func testTaskOwnersAreAddedToPeopleList() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        let created = try db.createTask(sampleDraft(owner: "  Someone   New  "), today: "2026-09-30")
        XCTAssertEqual(created.owner, "Someone New")

        let people = try db.listPeople()
        XCTAssertTrue(people.map(\.name).contains("Someone New"))
    }

    func testVersionOneDatabaseMigratesExistingOwnersWithoutLosingHistory() throws {
        let legacyURL = tempDirectory.appendingPathComponent("version-one.sqlite3")
        var rawDB: OpaquePointer?
        XCTAssertEqual(sqlite3_open(legacyURL.path, &rawDB), SQLITE_OK)
        let sql = """
        CREATE TABLE tasks (
            id TEXT PRIMARY KEY, title TEXT NOT NULL, project TEXT NOT NULL DEFAULT '',
            lane TEXT NOT NULL, owner TEXT NOT NULL, next_action TEXT NOT NULL,
            follow_up_at TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL, is_example INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE events (
            sequence INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE,
            task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, date TEXT NOT NULL, note TEXT NOT NULL
        );
        INSERT INTO tasks VALUES ('legacy-task', 'Task lama', '', 'external', '  Jared   Smith  ', 'Tunggu balasan', '', '2026-09-30', 0);
        INSERT INTO events (id, task_id, date, note) VALUES ('legacy-event', 'legacy-task', '2026-09-30', 'Sudah email');
        PRAGMA user_version = 1;
        """
        XCTAssertEqual(sqlite3_exec(rawDB, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(rawDB)

        let migrated = try WorkQueueDatabase(databaseURL: legacyURL)
        let people = try migrated.listPeople()
        XCTAssertEqual(people.map(\.name), ["Jared Smith", "Saya"])

        let tasks = try migrated.listTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].owner, "Jared Smith")
        XCTAssertEqual(tasks[0].events.first?.note, "Sudah email")
    }

    func testAddingUpdateAndCompletingTaskPersist() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        _ = try db.createTask(sampleDraft(), today: "2026-09-30")

        let withEvent = try db.addEvent(
            taskId: "task-1",
            date: "2026-10-14",
            note: "Jared meminta rincian mapping.",
            today: "2026-09-30"
        )
        XCTAssertEqual(withEvent.events.last?.note, "Jared meminta rincian mapping.")

        let completed = try db.updateTask(
            id: "task-1",
            draft: sampleDraft(lane: .done),
            today: "2026-09-30"
        )
        XCTAssertEqual(completed.lane, .done)
        XCTAssertTrue(completed.events.map(\.note).contains("Status diubah ke Selesai."))
    }

    func testInvalidDataIsRejectedWithoutSaving() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        XCTAssertThrowsError(try db.createTask(sampleDraft(followUpAt: "2026-02-30")))
        XCTAssertThrowsError(try db.createTask(sampleDraft(nextAction: "   ")))
        XCTAssertEqual(try db.listTasks(), [])
    }

    func testDeleteRemovesTaskAndTimeline() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        _ = try db.createTask(sampleDraft(), today: "2026-09-30")
        _ = try db.addEvent(taskId: "task-1", date: "2026-10-14", note: "Update", today: "2026-09-30")

        try db.deleteTask(id: "task-1")
        XCTAssertEqual(try db.listTasks(), [])
        XCTAssertThrowsError(try db.deleteTask(id: "task-1"))
    }

    func testDatabaseInitializationRejectsUnknownFutureVersion() throws {
        let futureURL = tempDirectory.appendingPathComponent("future.sqlite3")
        var rawDB: OpaquePointer?
        XCTAssertEqual(sqlite3_open(futureURL.path, &rawDB), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(rawDB, "PRAGMA user_version = 6;", nil, nil, nil), SQLITE_OK)
        sqlite3_close(rawDB)

        XCTAssertThrowsError(try WorkQueueDatabase(databaseURL: futureURL)) { error in
            XCTAssertEqual(error as? WorkQueueError, .unsupportedDatabaseVersion(6))
        }
    }

    func testWorkspaceCreationAndTaskScoping() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        let initialWorkspaces = try db.listWorkspaces()
        XCTAssertEqual(initialWorkspaces.count, 1)
        XCTAssertEqual(initialWorkspaces.first?.name, "Personal")

        let panorama = try db.createWorkspace(name: "Panorama")
        let aurora = try db.createWorkspace(name: "Aurora Cloud")
        XCTAssertEqual(panorama.name, "Panorama")
        XCTAssertEqual(aurora.name, "Aurora Cloud")

        let allWorkspaces = try db.listWorkspaces()
        XCTAssertEqual(allWorkspaces.count, 3)

        // Duplicate name rejection
        XCTAssertThrowsError(try db.createWorkspace(name: "panorama"))

        // Create tasks in different workspaces
        let taskPanorama = try db.createTask(
            sampleDraft(id: "task-pano", title: "Project Panorama", workspaceId: panorama.id),
            today: "2026-09-30"
        )
        let taskAurora = try db.createTask(
            sampleDraft(id: "task-aurora", title: "Cloud Migration", workspaceId: aurora.id),
            today: "2026-09-30"
        )

        XCTAssertEqual(taskPanorama.workspaceId, panorama.id)
        XCTAssertEqual(taskAurora.workspaceId, aurora.id)

        let allTasks = try db.listTasks()
        let panoramaTasks = allTasks.filter { WorkQueueLogic.matchesWorkspace($0, workspaceId: panorama.id) }
        let auroraTasks = allTasks.filter { WorkQueueLogic.matchesWorkspace($0, workspaceId: aurora.id) }
        XCTAssertEqual(panoramaTasks.count, 1)
        XCTAssertEqual(panoramaTasks.first?.title, "Project Panorama")
        XCTAssertEqual(auroraTasks.count, 1)
        XCTAssertEqual(auroraTasks.first?.title, "Cloud Migration")
    }

    func testExampleScenarioAndQueueLogic() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        let example = try db.createExampleTask()
        XCTAssertTrue(example.isExample)
        XCTAssertEqual(example.title, "Integrasi WebBeds ke TourPlan")
        XCTAssertEqual(example.events.count, 2)

        let waitingTask = try db.createTask(
            sampleDraft(
                id: "task-2",
                title: "Konfirmasi kontrak hotel",
                project: "Kontrak",
                lane: .external,
                owner: "Jared",
                nextAction: "Kirim draf revisi",
                followUpAt: "2026-09-25"
            ),
            today: "2026-09-30"
        )

        let allTasks = try db.listTasks()
        let counts = WorkQueueLogic.counts(for: allTasks)
        XCTAssertEqual(counts.all, 2)
        XCTAssertEqual(counts.action, 1)
        XCTAssertEqual(counts.waiting, 1)
        XCTAssertEqual(counts.noFollowUp, 1)
        XCTAssertEqual(counts.blocked, 0)

        XCTAssertTrue(WorkQueueLogic.matchesFilter(example, filter: .action))
        XCTAssertTrue(WorkQueueLogic.matchesFilter(example, filter: .noFollowUp))
        XCTAssertTrue(WorkQueueLogic.matchesFilter(waitingTask, filter: .waiting))
        XCTAssertTrue(WorkQueueLogic.matchesQuery(example, query: "jared"))
        XCTAssertFalse(WorkQueueLogic.matchesQuery(example, query: "tidak-ada"))

        let sorted = WorkQueueLogic.sortTasks(allTasks)
        XCTAssertEqual(sorted.map(\.id), ["task-2", example.id])

        XCTAssertEqual(
            WorkDateFormatting.followUpStatus(for: waitingTask, today: "2026-09-30"),
            .overdue(formattedDate: WorkDateFormatting.formatShortDate("2026-09-25"))
        )
        XCTAssertEqual(
            WorkDateFormatting.followUpStatus(for: example, today: "2026-09-30"),
            .unset
        )
    }

    func testStickyNotesCRUD() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        let note = try db.createStickyNote(StickyNote(
            workspaceId: "default",
            content: "Catatan penting ide baru",
            color: .yellow,
            x: 150,
            y: 200,
            author: "Saya"
        ))
        XCTAssertEqual(note.content, "Catatan penting ide baru")

        let notes = try db.listStickyNotes(workspaceId: "default")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.color, .yellow)

        var toUpdate = note
        toUpdate.content = "Catatan revisi"
        toUpdate.color = .purple
        let updated = try db.updateStickyNote(toUpdate)
        XCTAssertEqual(updated.content, "Catatan revisi")
        XCTAssertEqual(updated.color, .purple)

        try db.deleteStickyNote(id: note.id)
        XCTAssertEqual(try db.listStickyNotes(workspaceId: "default").count, 0)
    }

    func testBoardLinesCRUD() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        let line = try db.createBoardLine(BoardLine(
            workspaceId: "default",
            startX: 100,
            startY: 150,
            endX: 300,
            endY: 150,
            color: "#3B82F6",
            style: .arrow,
            isCurved: true,
            controlX: 200,
            controlY: 80,
            label: "Alur Kerja"
        ))
        XCTAssertEqual(line.label, "Alur Kerja")
        XCTAssertEqual(line.style, .arrow)
        XCTAssertTrue(line.isCurved)
        XCTAssertEqual(line.controlX, 200)
        XCTAssertEqual(line.controlY, 80)

        let lines = try db.listBoardLines(workspaceId: "default")
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.color, "#3B82F6")
        XCTAssertTrue(lines.first?.isCurved ?? false)

        var toUpdate = line
        toUpdate.style = .doubleArrow
        toUpdate.color = "#10B981"
        toUpdate.label = "Dua Arah"
        toUpdate.controlY = 120
        let updated = try db.updateBoardLine(toUpdate)
        XCTAssertEqual(updated.style, .doubleArrow)
        XCTAssertEqual(updated.color, "#10B981")
        XCTAssertEqual(updated.label, "Dua Arah")
        XCTAssertEqual(updated.controlY, 120)

        try db.deleteBoardLine(id: line.id)
        XCTAssertEqual(try db.listBoardLines(workspaceId: "default").count, 0)
    }

    func testTaskProjectPathPersistenceAndUpdates() throws {
        let db = try WorkQueueDatabase(databaseURL: databaseURL)
        let created = try db.createTask(
            sampleDraft(
                id: "project-task-1",
                title: "Development Task",
                projectPath: "/Users/bhakti/Projects/sample-app"
            )
        )
        XCTAssertEqual(created.projectPath, "/Users/bhakti/Projects/sample-app")

        let reopened = try WorkQueueDatabase(databaseURL: databaseURL)
        let tasks = try reopened.listTasks()
        let found = tasks.first { $0.id == "project-task-1" }
        XCTAssertEqual(found?.projectPath, "/Users/bhakti/Projects/sample-app")

        let updated = try reopened.updateTaskProjectPath(
            id: "project-task-1",
            projectPath: "/Users/bhakti/Projects/sample-app-v2"
        )
        XCTAssertEqual(updated.projectPath, "/Users/bhakti/Projects/sample-app-v2")
        XCTAssertTrue(updated.events.contains { $0.note.contains("Folder proyek dihubungkan") })

        let cleared = try reopened.updateTaskProjectPath(
            id: "project-task-1",
            projectPath: ""
        )
        XCTAssertEqual(cleared.projectPath, "")
        XCTAssertTrue(cleared.events.contains { $0.note == "Folder proyek dilepas." })
    }
}

