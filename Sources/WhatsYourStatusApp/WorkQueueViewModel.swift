import Foundation
import Observation
import AppKit
import SwiftUI
import WhatsYourStatusCore

enum StorageConnectionState: Equatable {
    case loading
    case saved
    case error(String)
}

struct ToastBanner: Equatable {
    let message: String
    let isError: Bool
}

enum AppNavigationSection: String, CaseIterable, Identifiable {
    case queue = "Antrean Status"
    case stickyBoard = "Sticky Board"

    var id: String { rawValue }
}

@MainActor
@Observable
final class WorkQueueViewModel {
    var activeSection: AppNavigationSection = .queue
    var tasks: [WorkTask] = []
    var people: [Person] = []
    var workspaces: [Workspace] = []
    var stickyNotes: [StickyNote] = []
    var boardLines: [BoardLine] = []
    var selectedWorkspaceId: String? = nil
    var currentFilter: QueueFilter = .all
    var searchQuery: String = ""
    var storageState: StorageConnectionState = .loading
    var saveStatusText: String = "Menghubungkan ke SQLite..."
    var storageLabelText: String = "Memuat SQLite..."

    var preferredCodeEditor: CodeEditorApp {
        get {
            if let raw = UserDefaults.standard.string(forKey: "preferredCodeEditor"),
               let editor = CodeEditorApp(rawValue: raw) {
                return editor
            }
            return .antiGravity
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "preferredCodeEditor")
        }
    }

    var appearanceMode: AppAppearanceMode = {
        if let raw = UserDefaults.standard.string(forKey: "appAppearanceMode"),
           let mode = AppAppearanceMode(rawValue: raw) {
            return mode
        }
        return .system
    }() {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appAppearanceMode")
            applyAppearance()
        }
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func applyAppearance() {
        #if canImport(AppKit)
        let mode = self.appearanceMode
        DispatchQueue.main.async {
            switch mode {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
        #endif
    }

    var isLaunchAtLoginEnabled: Bool {
        get {
            #if canImport(AppKit)
            return LaunchAtLoginHelper.isEnabled
            #else
            return false
            #endif
        }
        set {
            #if canImport(AppKit)
            let result = LaunchAtLoginHelper.setEnabled(newValue)
            switch result {
            case .success:
                UserDefaults.standard.set(newValue, forKey: "launchAtLoginPreference")
            case .failure(let error):
                showToast("Gagal mengatur startup: \(error.localizedDescription)", isError: true)
            }
            #endif
        }
    }

    var selectedTaskId: String?
    var editingTask: WorkTask?
    var isShowingTaskSheet: Bool = false
    var isShowingPeopleSheet: Bool = false
    var isShowingNewWorkspaceSheet: Bool = false
    var isShowingSettingsSheet: Bool = false
    var searchFocusTrigger: Int = 0
    var toast: ToastBanner?

    private var database: WorkQueueDatabase?
    private let databaseURL: URL
    private var toastDismissTask: Task<Void, Never>?

    var currentDatabasePath: String {
        databaseURL.path
    }

    init(databaseURL: URL = WorkQueueDatabase.defaultDatabaseURL) {
        self.databaseURL = databaseURL
        applyAppearance()
        loadFromDatabase()
    }

    var currentWorkspaceName: String {
        if let selectedWorkspaceId, let ws = workspaces.first(where: { $0.id == selectedWorkspaceId }) {
            return ws.name
        }
        return "Semua Workspace"
    }

    var counts: QueueCounts {
        let scoped = tasks.filter { WorkQueueLogic.matchesWorkspace($0, workspaceId: selectedWorkspaceId) }
        return WorkQueueLogic.counts(for: scoped)
    }

    var visibleTasks: [WorkTask] {
        tasks.filter { task in
            WorkQueueLogic.matchesWorkspace(task, workspaceId: selectedWorkspaceId)
                && WorkQueueLogic.matchesFilter(task, filter: currentFilter)
                && WorkQueueLogic.matchesQuery(task, query: searchQuery)
        }
    }

    var selectedTask: WorkTask? {
        guard let selectedTaskId else { return nil }
        return tasks.first { $0.id == selectedTaskId }
    }

    func selectWorkspace(_ workspaceId: String?) {
        selectedWorkspaceId = workspaceId
    }

    func workspaceName(for id: String) -> String {
        workspaces.first(where: { $0.id == id })?.name ?? "Personal"
    }

    func createWorkspace(name: String) {
        guard let database else {
            showToast("Database SQLite tidak bisa diakses.", isError: true)
            return
        }
        do {
            let created = try database.createWorkspace(name: name)
            workspaces = try database.listWorkspaces()
            selectedWorkspaceId = created.id
            isShowingNewWorkspaceSheet = false
            markStorageReady()
            showToast("Workspace \"\(created.name)\" dibuat.")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showToast(message, isError: true)
        }
    }

    func loadFromDatabase() {
        storageState = .loading
        saveStatusText = "Menghubungkan ke SQLite..."
        storageLabelText = "Menghubungkan ke database..."
        do {
            let db = try WorkQueueDatabase(databaseURL: databaseURL)
            self.database = db
            self.tasks = try db.listTasks()
            self.people = try db.listPeople()
            self.workspaces = try db.listWorkspaces()
            if selectedWorkspaceId == nil, let pano = workspaces.first(where: { $0.name.lowercased() == "panorama" }) {
                selectedWorkspaceId = pano.id
            }
            self.stickyNotes = try db.listStickyNotes()
            self.boardLines = (try? db.listBoardLines()) ?? []
            markStorageReady("Database SQLite aktif")
        } catch {
            markStorageFailure(error)
        }
    }

    private func markStorageReady(_ statusText: String = "Perubahan tersimpan") {
        storageState = .saved
        saveStatusText = statusText
        storageLabelText = "Database SQLite aktif"
    }

    private func markStorageFailure(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        storageState = .error(message)
        saveStatusText = "Database bermasalah"
        storageLabelText = "Database bermasalah"
    }

    func showToast(_ message: String, isError: Bool = false) {
        toastDismissTask?.cancel()
        toast = ToastBanner(message: message, isError: isError)
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.4))
            if !Task.isCancelled {
                self.toast = nil
            }
        }
    }

    func openNewTaskForm() {
        editingTask = nil
        isShowingTaskSheet = true
    }

    func openEditTaskForm(_ task: WorkTask) {
        editingTask = task
        isShowingTaskSheet = true
    }

    func selectFilter(_ filter: QueueFilter) {
        currentFilter = filter
    }

    func clearSearch() {
        searchQuery = ""
    }

    func saveTask(draft: TaskDraft) throws {
        guard let database else {
            throw WorkQueueError.databaseFailure("Database SQLite tidak bisa diakses.")
        }
        do {
            if let existingId = draft.id, !existingId.isEmpty {
                let updated = try database.updateTask(id: existingId, draft: draft)
                tasks = tasks.map { $0.id == existingId ? updated : $0 }
                people = try database.listPeople()
                markStorageReady()
                showToast("Task diperbarui.")
            } else {
                let created = try database.createTask(draft)
                tasks = [created] + tasks
                people = try database.listPeople()
                markStorageReady()
                showToast("Task ditambahkan.")
            }
            isShowingTaskSheet = false
        } catch let error as WorkQueueError {
            if case .databaseFailure = error {
                markStorageFailure(error)
            }
            throw error
        } catch {
            markStorageFailure(error)
            throw error
        }
    }

    func addPerson(name: String) throws -> Person {
        guard let database else {
            throw WorkQueueError.databaseFailure("Database SQLite tidak bisa diakses.")
        }
        do {
            let person = try database.addPerson(name: name)
            people = try database.listPeople()
            markStorageReady()
            showToast("\(person.name) ditambahkan ke daftar orang.")
            return person
        } catch let error as WorkQueueError {
            if case .databaseFailure = error {
                markStorageFailure(error)
            }
            throw error
        } catch {
            markStorageFailure(error)
            throw error
        }
    }

    func addUpdate(taskId: String, date: String, note: String) {
        guard let database else {
            showToast("Database SQLite tidak bisa diakses.", isError: true)
            return
        }
        do {
            let updated = try database.addEvent(taskId: taskId, date: date, note: note)
            tasks = tasks.map { $0.id == taskId ? updated : $0 }
            markStorageReady()
            showToast("Update dicatat.")
        } catch {
            markStorageFailure(error)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showToast("Update belum tersimpan. \(message)", isError: true)
        }
    }

    func completeTask(_ task: WorkTask) {
        guard let database else {
            showToast("Database SQLite tidak bisa diakses.", isError: true)
            return
        }
        let draft = TaskDraft(
            id: task.id,
            title: task.title,
            project: task.project,
            lane: .done,
            owner: task.owner,
            nextAction: task.nextAction,
            followUpAt: task.followUpAt,
            workspaceId: task.workspaceId,
            projectPath: task.projectPath
        )
        do {
            let updated = try database.updateTask(id: task.id, draft: draft)
            tasks = tasks.map { $0.id == task.id ? updated : $0 }
            markStorageReady()
            showToast("Task ditandai selesai.")
        } catch {
            markStorageFailure(error)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showToast("Status belum tersimpan. \(message)", isError: true)
        }
    }

    func openTaskProject(task: WorkTask, editor: CodeEditorApp? = nil) {
        guard !task.projectPath.isEmpty else {
            showToast("Task ini belum memiliki folder proyek.", isError: true)
            return
        }
        let targetEditor = editor ?? preferredCodeEditor
        let result = ProjectLauncher.open(path: task.projectPath, with: targetEditor)
        showToast(result.message, isError: !result.success)
    }

    func pickFolderForTask(task: WorkTask) {
        let panel = NSOpenPanel()
        panel.title = "Pilih Folder Proyek"
        panel.prompt = "Pilih Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if !task.projectPath.isEmpty, let url = ProjectLauncher.resolveURL(path: task.projectPath) {
            panel.directoryURL = url
        }

        if panel.runModal() == .OK, let selectedURL = panel.url {
            setTaskProjectPath(task: task, path: selectedURL.path)
        }
    }

    func setTaskProjectPath(task: WorkTask, path: String) {
        guard let database else {
            showToast("Database SQLite tidak bisa diakses.", isError: true)
            return
        }
        do {
            let updated = try database.updateTaskProjectPath(id: task.id, projectPath: path)
            tasks = tasks.map { $0.id == task.id ? updated : $0 }
            markStorageReady()
            let folderName = URL(fileURLWithPath: path).lastPathComponent
            let msg = path.isEmpty ? "Folder proyek dilepas." : "Folder \"\(folderName)\" berhasil dihubungkan."
            showToast(msg)
        } catch {
            markStorageFailure(error)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showToast("Gagal menyimpan folder proyek: \(message)", isError: true)
        }
    }

    func removeTaskProjectPath(task: WorkTask) {
        setTaskProjectPath(task: task, path: "")
    }

    func deleteTask(_ task: WorkTask) {
        guard let database else {
            showToast("Database SQLite tidak bisa diakses.", isError: true)
            return
        }
        do {
            try database.deleteTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
            if selectedTaskId == task.id {
                selectedTaskId = nil
            }
            markStorageReady()
            showToast("Task dihapus.")
        } catch {
            markStorageFailure(error)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showToast("Task belum dihapus. \(message)", isError: true)
        }
    }

    func loadExampleScenario() {
        guard let database else {
            showToast("Contoh gagal disimpan. Database SQLite tidak bisa diakses.", isError: true)
            return
        }
        do {
            let created = try database.createExampleTask()
            tasks = [created] + tasks
            people = try database.listPeople()
            currentFilter = .all
            searchQuery = ""
            markStorageReady()
            showToast("Contoh dimuat. Edit atau hapus kapan saja.")
        } catch {
            markStorageFailure(error)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showToast("Contoh gagal disimpan. \(message)", isError: true)
        }
    }

    // MARK: - Sticky Notes Board Management
    var currentStickyNotes: [StickyNote] {
        if let selectedWorkspaceId {
            return stickyNotes.filter { $0.workspaceId == selectedWorkspaceId }
        }
        return stickyNotes
    }

    var currentBoardLines: [BoardLine] {
        let targetWs = selectedWorkspaceId ?? "default"
        return boardLines.filter { $0.workspaceId == targetWs || ($0.workspaceId.isEmpty && targetWs == "default") }
    }

    func addStickyNote(
        content: String = "",
        color: StickyColor = .yellow,
        x: Double? = nil,
        y: Double? = nil,
        noteType: StickyType = .sticky,
        author: String = "Saya"
    ) {
        guard let database else {
            showToast("Database SQLite tidak bisa diakses.", isError: true)
            return
        }
        let targetWs = selectedWorkspaceId ?? "default"
        let currentCount = currentStickyNotes.count
        let defaultX = x ?? Double(120 + (currentCount % 4) * 220)
        let defaultY = y ?? Double(140 + (currentCount / 4) * 220)

        let newNote = StickyNote(
            workspaceId: targetWs,
            content: content,
            color: color,
            x: defaultX,
            y: defaultY,
            width: noteType == .text ? 320 : 190,
            height: noteType == .text ? 90 : 190,
            author: author,
            noteType: noteType
        )
        do {
            let created = try database.createStickyNote(newNote)
            stickyNotes.append(created)
            markStorageReady("Catatan ditambahkan")
        } catch {
            markStorageFailure(error)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showToast("Gagal menyimpan catatan: \(message)", isError: true)
        }
    }

    func updateStickyNote(_ note: StickyNote) {
        guard let database else { return }
        var updated = note
        updated.updatedAt = WorkDateFormatting.localISODate()
        do {
            let saved = try database.updateStickyNote(updated)
            if let index = stickyNotes.firstIndex(where: { $0.id == saved.id }) {
                stickyNotes[index] = saved
            }
            markStorageReady()
        } catch {
            markStorageFailure(error)
        }
    }

    func deleteStickyNote(_ note: StickyNote) {
        guard let database else { return }
        do {
            try database.deleteStickyNote(id: note.id)
            stickyNotes.removeAll { $0.id == note.id }
            markStorageReady("Catatan dihapus")
            showToast("Catatan dihapus.")
        } catch {
            markStorageFailure(error)
            showToast("Gagal menghapus catatan.", isError: true)
        }
    }

    func duplicateStickyNote(_ note: StickyNote) {
        guard let database else { return }
        let duplicate = StickyNote(
            workspaceId: note.workspaceId,
            content: note.content,
            color: note.color,
            x: note.x + 30,
            y: note.y + 30,
            width: note.width,
            height: note.height,
            author: note.author,
            noteType: note.noteType
        )
        do {
            let created = try database.createStickyNote(duplicate)
            stickyNotes.append(created)
            markStorageReady("Catatan digandakan")
            showToast("Catatan digandakan.")
        } catch {
            markStorageFailure(error)
            showToast("Gagal menggandakan catatan.", isError: true)
        }
    }

    func convertStickyNoteToTask(_ note: StickyNote) {
        guard let database else { return }
        let cleanTitle = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleanTitle.isEmpty ? "Tugas dari Sticky Note" : cleanTitle
        let draft = TaskDraft(
            title: title,
            project: currentWorkspaceName,
            lane: .action,
            owner: note.author.isEmpty ? "Saya" : note.author,
            nextAction: "Tindak lanjuti catatan board",
            workspaceId: note.workspaceId
        )
        do {
            let created = try database.createTask(draft)
            tasks = [created] + tasks
            markStorageReady()
            showToast("Sticky note berhasil diubah menjadi Task Status!")
            activeSection = .queue
            selectedTaskId = created.id
        } catch {
            markStorageFailure(error)
            showToast("Gagal mengubah menjadi task.", isError: true)
        }
    }

    func addBoardLine(style: LineCapStyle = .arrow, isCurved: Bool = false) {
        guard let database else { return }
        let targetWs = selectedWorkspaceId ?? "default"
        let count = currentBoardLines.count
        let offset = Double((count % 4) * 30)
        let sx = 160.0 + offset
        let sy = 220.0 + offset
        let ex = 360.0 + offset
        let ey = isCurved ? (280.0 + offset) : (220.0 + offset)
        let cx = (sx + ex) / 2
        let cy = isCurved ? (sy - 50) : sy

        let newLine = BoardLine(
            workspaceId: targetWs,
            startX: sx,
            startY: sy,
            endX: ex,
            endY: ey,
            color: "#475569",
            style: style,
            isCurved: isCurved,
            controlX: isCurved ? cx : nil,
            controlY: isCurved ? cy : nil
        )
        do {
            let created = try database.createBoardLine(newLine)
            boardLines.append(created)
            markStorageReady("Garis ditambahkan")
            let typeLabel = isCurved ? "lengkung" : "lurus"
            showToast("Garis \(typeLabel) (\(style.label.lowercased())) ditambahkan.")
        } catch {
            markStorageFailure(error)
            showToast("Gagal menambah garis.", isError: true)
        }
    }

    func updateBoardLine(_ line: BoardLine) {
        guard let database else { return }
        do {
            let saved = try database.updateBoardLine(line)
            if let index = boardLines.firstIndex(where: { $0.id == saved.id }) {
                boardLines[index] = saved
            }
            markStorageReady()
        } catch {
            markStorageFailure(error)
        }
    }

    func deleteBoardLine(_ line: BoardLine) {
        guard let database else { return }
        do {
            try database.deleteBoardLine(id: line.id)
            boardLines.removeAll { $0.id == line.id }
            markStorageReady("Garis dihapus")
            showToast("Garis dihapus.")
        } catch {
            markStorageFailure(error)
            showToast("Gagal menghapus garis.", isError: true)
        }
    }
}

