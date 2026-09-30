import SwiftUI
import WhatsYourStatusCore

struct TaskFormSheet: View {
    let viewModel: WorkQueueViewModel
    let existingTask: WorkTask?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var project: String = ""
    @State private var lane: TaskLane = .action
    @State private var owner: String = "Saya"
    @State private var workspaceId: String = "default"
    @State private var nextAction: String = ""
    @State private var hasFollowUpDate: Bool = false
    @State private var followUpDate: Date = Date()
    @State private var projectPath: String = ""
    @State private var errorMessage: String = ""
    @State private var isShowingAddPersonSheet: Bool = false

    init(viewModel: WorkQueueViewModel, existingTask: WorkTask?) {
        self.viewModel = viewModel
        self.existingTask = existingTask
        _title = State(initialValue: existingTask?.title ?? "")
        _project = State(initialValue: existingTask?.project ?? "")
        _lane = State(initialValue: existingTask?.lane ?? .action)
        _owner = State(initialValue: existingTask?.owner ?? "Saya")
        let defaultWs = viewModel.selectedWorkspaceId ?? "default"
        _workspaceId = State(initialValue: existingTask?.workspaceId ?? defaultWs)
        _nextAction = State(initialValue: existingTask?.nextAction ?? "")
        _projectPath = State(initialValue: existingTask?.projectPath ?? "")
        if let followUp = existingTask?.followUpAt,
           !followUp.isEmpty,
           let parsed = WorkDateFormatting.parseISODate(followUp) {
            _hasFollowUpDate = State(initialValue: true)
            _followUpDate = State(initialValue: parsed)
        } else {
            _hasFollowUpDate = State(initialValue: false)
            _followUpDate = State(initialValue: Date())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerBar

            Divider().overlay(AppTheme.line)

            taskInfoFields

            statusAndOwnerSection

            nextActionSection

            followUpSection

            if !errorMessage.isEmpty {
                errorBanner
            }

            Divider().overlay(AppTheme.line)

            footerActions
        }
        .padding(24)
        .frame(width: 540)
        .background(AppTheme.paper)
        .sheet(isPresented: $isShowingAddPersonSheet) {
            PeopleSheet(viewModel: viewModel) { addedPerson in
                owner = addedPerson.name
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(existingTask == nil ? "Tambah task" : "Edit task")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text(existingTask == nil
                     ? "Catat detail pekerjaan, penanggung jawab, dan aksi berikutnya."
                     : "Perbarui status, penanggung jawab, atau langkah tindak lanjut.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(IconCloseButtonStyle())
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Tutup form")
        }
    }

    // MARK: - Task Info (Title, Workspace, Project, Folder)
    private var taskInfoFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Nama task")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                    Spacer()
                    Text("Wajib")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }

                TextField("Contoh: Integrasi WebBeds ke TourPlan", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(AppTheme.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .stroke(AppTheme.line, lineWidth: 1)
                    )
            }

            // Workspace & Proyek (2 Columns Side-by-Side)
            HStack(alignment: .top, spacing: 12) {
                // Workspace
                VStack(alignment: .leading, spacing: 5) {
                    Text("Workspace")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)

                    Menu {
                        ForEach(viewModel.workspaces) { ws in
                            Button {
                                workspaceId = ws.id
                            } label: {
                                HStack {
                                    Text(ws.name)
                                    if workspaceId == ws.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        Button {
                            viewModel.isShowingNewWorkspaceSheet = true
                        } label: {
                            Label("Buat workspace baru...", systemImage: "plus.square")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.blue)

                            Text(viewModel.workspaceName(for: workspaceId))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(AppTheme.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                .stroke(AppTheme.line, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Proyek
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text("Proyek")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                        Text("(opsional)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.muted)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.leading, 12)

                        TextField("Nama proyek / area", text: $project)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.trailing, 12)
                    }
                    .frame(height: 38)
                    .background(AppTheme.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .stroke(AppTheme.line, lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Folder Proyek
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text("Folder Proyek (Code Editor)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                    Text("(opsional)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.muted)
                }

                HStack(spacing: 8) {
                    Image(systemName: "curlybraces.square")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(projectPath.isEmpty ? AppTheme.muted : AppTheme.blue)
                        .padding(.leading, 12)

                    Text(projectPath.isEmpty ? "Pilih folder project development (mis. AntiGravity / VS Code)" : displayPath(projectPath))
                        .font(.system(size: 12))
                        .foregroundStyle(projectPath.isEmpty ? AppTheme.muted : AppTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !projectPath.isEmpty {
                        Button {
                            projectPath = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Hapus path folder")
                    }

                    Button("Pilih Folder...") {
                        let panel = NSOpenPanel()
                        panel.title = "Pilih Folder Proyek"
                        panel.prompt = "Pilih"
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.canCreateDirectories = false
                        if !projectPath.isEmpty, let url = ProjectLauncher.resolveURL(path: projectPath) {
                            panel.directoryURL = url
                        }
                        if panel.runModal() == .OK, let url = panel.url {
                            projectPath = url.path
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .stroke(AppTheme.lineStrong.opacity(0.6), lineWidth: 1)
                    )
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                }
                .frame(height: 38)
                .background(AppTheme.canvas)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Status & Owner Section
    private var statusAndOwnerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Status Picker
                VStack(alignment: .leading, spacing: 5) {
                    Text("Status kerjaan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)

                    Menu {
                        ForEach(TaskLane.allCases) { item in
                            Button {
                                lane = item
                                adjustOwnerForLane(item)
                            } label: {
                                Text(item.label)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppTheme.laneColors(for: lane).foreground)
                                .frame(width: 8, height: 8)

                            Text(lane.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                .stroke(AppTheme.line, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Owner Picker
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Giliran ada pada")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        Menu {
                            ForEach(viewModel.people) { person in
                                Button {
                                    owner = person.name
                                } label: {
                                    HStack {
                                        Text(person.name)
                                        if owner == person.name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }

                            Divider()

                            Button {
                                isShowingAddPersonSheet = true
                            } label: {
                                Label("Tambah orang baru...", systemImage: "person.badge.plus")
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: owner == "Saya" ? "person.crop.circle.fill" : "person.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(owner == "Saya" ? AppTheme.blue : AppTheme.muted)

                                Text(owner.isEmpty ? "Pilih orang..." : owner)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(owner.isEmpty ? AppTheme.muted : AppTheme.ink)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(AppTheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                    .stroke(AppTheme.line, lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)

                        Button {
                            isShowingAddPersonSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(IconCloseButtonStyle())
                        .help("Tambah orang baru")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.canvas)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private func adjustOwnerForLane(_ newLane: TaskLane) {
        guard existingTask == nil else { return }
        if newLane == .action && owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            owner = "Saya"
        } else if newLane != .action && owner.trimmingCharacters(in: .whitespacesAndNewlines) == "Saya" {
            owner = ""
        }
    }

    // MARK: - Next Action Section
    private var nextActionSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.blue)

                Text("Langkah berikutnya")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryInk)

                Spacer()

                Text("Wajib")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
            }

            TextEditor(text: $nextAction)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 70, maxHeight: 95)
                .background(AppTheme.canvas)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if nextAction.isEmpty {
                        Text("Aksi konkret berikutnya, dan siapa yang perlu dihubungi...")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Follow-up Section
    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Toggle(isOn: $hasFollowUpDate.animation(.spring(duration: 0.25))) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                            .foregroundStyle(hasFollowUpDate ? AppTheme.blue : AppTheme.muted)

                        Text("Jadwalkan tanggal follow-up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryInk)

                        Text("(opsional)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .toggleStyle(.checkbox)

                Spacer()

                if hasFollowUpDate {
                    DatePicker(
                        "Jadwalkan follow-up",
                        selection: $followUpDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
            }

            if hasFollowUpDate {
                HStack(spacing: 6) {
                    Text("Pilihan cepat:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.muted)

                    quickDateButton(title: "Hari ini", daysToAdd: 0)
                    quickDateButton(title: "Besok", daysToAdd: 1)
                    quickDateButton(title: "3 hari", daysToAdd: 3)
                    quickDateButton(title: "1 minggu", daysToAdd: 7)

                    Spacer()
                }
                .padding(.leading, 22)
            }
        }
        .padding(.vertical, 2)
    }

    private func quickDateButton(title: String, daysToAdd: Int) -> some View {
        Button {
            if let targetDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date()) {
                followUpDate = targetDate
            }
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.canvas)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(AppTheme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error Banner
    private var errorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.red)

            Text(errorMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.red)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .fill(AppTheme.redSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .stroke(AppTheme.dangerBorder.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Footer Actions
    private var footerActions: some View {
        HStack(spacing: 10) {
            Spacer()

            Button("Batal") {
                dismiss()
            }
            .buttonStyle(QuietButtonStyle())

            Button("Simpan task") {
                submitTask()
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Submission
    private func submitTask() {
        errorMessage = ""
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNextAction = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty || trimmedOwner.isEmpty || trimmedNextAction.isEmpty {
            errorMessage = "Nama task, penanggung jawab, dan langkah berikutnya perlu diisi."
            return
        }

        let followUpString = hasFollowUpDate ? WorkDateFormatting.localISODate(from: followUpDate) : ""
        let draft = TaskDraft(
            id: existingTask?.id,
            title: trimmedTitle,
            project: project.trimmingCharacters(in: .whitespacesAndNewlines),
            lane: lane,
            owner: trimmedOwner,
            nextAction: trimmedNextAction,
            followUpAt: followUpString,
            workspaceId: workspaceId,
            projectPath: projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            try viewModel.saveTask(draft: draft)
            dismiss()
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription ?? "Database SQLite tidak bisa diakses."
            errorMessage = "Task belum tersimpan. \(detail)"
        }
    }

    private func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

