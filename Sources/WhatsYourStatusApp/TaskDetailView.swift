import SwiftUI
import WhatsYourStatusCore

struct TaskDetailView: View {
    let task: WorkTask
    let viewModel: WorkQueueViewModel

    @State private var updateNote: String = ""
    @State private var updateDate: Date = Date()
    @State private var isConfirmingDelete: Bool = false
    @State private var isShowingRoadmapSheet: Bool = false

    private var sortedEvents: [TaskEvent] {
        task.events.sorted { a, b in
            if a.date != b.date {
                return a.date > b.date
            }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().overlay(AppTheme.line)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nextActionSection
                    metadataGridSection
                    projectFolderSection
                    activityHistorySection
                    addUpdateFormSection
                    actionButtonsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.paper)
        .onChange(of: task.id) { _, _ in
            updateNote = ""
            updateDate = Date()
        }
        .confirmationDialog(
            "Hapus \"\(task.title)\" beserta riwayat update-nya?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Hapus task", role: .destructive) {
                viewModel.deleteTask(task)
            }
            Button("Batal", role: .cancel) {}
        }
        .sheet(isPresented: $isShowingRoadmapSheet) {
            TaskRoadmapSheet(task: task, viewModel: viewModel)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.project.isEmpty ? "Tanpa nama proyek" : task.project)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.muted)

                Text(task.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if task.isExample {
                    Text("Contoh dari skenario kamu")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
            }
            Spacer(minLength: 8)
            Button {
                viewModel.selectedTaskId = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconCloseButtonStyle())
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Tutup detail task")
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var nextActionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Text("Langkah berikutnya")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.muted)
            }

            Text(task.nextAction.isEmpty ? "Belum ditentukan" : task.nextAction)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.focusSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private var metadataGridSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                metadataCard(title: "Status") {
                    StatusBadge(lane: task.lane)
                }
                metadataCard(title: "Giliran ada pada") {
                    Text(task.owner.isEmpty ? "Belum ditentukan" : task.owner)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                metadataCard(title: "Jadwal follow-up") {
                    Text(task.followUpAt.isEmpty ? "Belum diatur" : WorkDateFormatting.formatShortDate(task.followUpAt))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                }
                metadataCard(title: "Workspace") {
                    Text(viewModel.workspaceName(for: task.workspaceId))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.blueInk)
                        .lineLimit(1)
                }
            }
        }
    }

    private func metadataCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.muted)
            content()
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .fill(AppTheme.surfaceMuted.opacity(0.6))
        )
    }

    private var projectFolderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Folder Proyek")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.muted)

            if task.projectPath.isEmpty {
                Button {
                    viewModel.pickFolderForTask(task: task)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hubungkan Folder Proyek")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.ink)

                            Text("Buka langsung di AntiGravity, VS Code, Cursor, atau Xcode")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.muted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .fill(AppTheme.surfaceMuted.opacity(0.45))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .strokeBorder(AppTheme.lineStrong.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.blue)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.blueSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(URL(fileURLWithPath: task.projectPath).lastPathComponent)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(displayPath(task.projectPath))
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider().overlay(AppTheme.line.opacity(0.6))

                    HStack(spacing: 8) {
                        Button {
                            viewModel.openTaskProject(task: task)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.preferredCodeEditor.systemIcon)
                                    .font(.system(size: 11, weight: .bold))
                                Text("Buka di \(viewModel.preferredCodeEditor.displayName)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(AppTheme.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Section("Buka Dengan") {
                                ForEach(CodeEditorApp.allCases) { editor in
                                    Button {
                                        viewModel.openTaskProject(task: task, editor: editor)
                                    } label: {
                                        Label(editor.displayName, systemImage: editor.systemIcon)
                                    }
                                }
                            }

                            Divider()

                            Section("Editor Default") {
                                ForEach(CodeEditorApp.allCases) { editor in
                                    Button {
                                        viewModel.preferredCodeEditor = editor
                                    } label: {
                                        HStack {
                                            Text(editor.displayName)
                                            if viewModel.preferredCodeEditor == editor {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }

                            Divider()

                            Button {
                                viewModel.pickFolderForTask(task: task)
                            } label: {
                                Label("Ubah Folder...", systemImage: "folder")
                            }

                            Button(role: .destructive) {
                                viewModel.removeTaskProjectPath(task: task)
                            } label: {
                                Label("Lepas Folder", systemImage: "link.badge.plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.secondaryInk)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.paper)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(AppTheme.lineStrong.opacity(0.6), lineWidth: 1)
                                )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .fill(AppTheme.surfaceMuted.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )
            }
        }
    }

    private func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private var activityHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Riwayat update")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Button {
                    isShowingRoadmapSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "point.topleft.filled.down.to.point.bottomright.curvepath")
                            .font(.system(size: 10, weight: .bold))
                        Text("Lihat Roadmap")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.blueInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.blueSoft))
                }
                .buttonStyle(.plain)
                .help("Buka tampilan roadmap horizontal untuk task ini")

                Text("\(sortedEvents.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(AppTheme.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppTheme.surfaceMuted))
            }

            if sortedEvents.isEmpty {
                Text("Belum ada update. Catat perubahan terakhir supaya alurnya tetap jelas.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                    .padding(.vertical, 4)
            } else {
                let displayedEvents = Array(sortedEvents.prefix(3))
                let remainingCount = sortedEvents.count - displayedEvents.count

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(displayedEvents.enumerated()), id: \.element.id) { index, event in
                        let isLast = index == displayedEvents.count - 1
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(AppTheme.blue.opacity(0.8))
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 4)

                                if !isLast || remainingCount > 0 {
                                    Rectangle()
                                        .fill(AppTheme.line)
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 8)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(WorkDateFormatting.formatShortDate(event.date))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.muted)

                                Text(event.note)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, (isLast && remainingCount == 0) ? 4 : 14)
                        }
                    }
                }
                .padding(.leading, 2)

                Button {
                    isShowingRoadmapSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "point.topleft.filled.down.to.point.bottomright.curvepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text(remainingCount > 0 ? "Lihat \(remainingCount) update lainnya di Roadmap" : "Buka Roadmap & Riwayat Lengkap")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.blueInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .fill(AppTheme.blueSoft.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .stroke(AppTheme.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private var addUpdateFormSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider().overlay(AppTheme.line)
                .padding(.bottom, 2)

            Text("Catat update")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryInk)

            TextEditor(text: $updateNote)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ink)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 64, maxHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .fill(AppTheme.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if updateNote.isEmpty {
                        Text("Apa yang berubah, dan siapa yang perlu bergerak?")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tanggal update")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)

                    DatePicker(
                        "Tanggal update",
                        selection: $updateDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }

                Spacer()

                Button("Simpan update") {
                    submitUpdate()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(updateNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
    }

    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(AppTheme.line)
                .padding(.top, 6)
                .padding(.bottom, 2)

            Text("Task actions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.muted)

            HStack(spacing: 8) {
                Button("Edit task") {
                    viewModel.openEditTaskForm(task)
                }
                .buttonStyle(CompactActionButtonStyle())
                .fixedSize(horizontal: true, vertical: false)

                Button {
                    isShowingRoadmapSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "map")
                            .font(.system(size: 11))
                        Text("Roadmap")
                    }
                }
                .buttonStyle(CompactActionButtonStyle())
                .fixedSize(horizontal: true, vertical: false)

                if task.lane != .done {
                    Button("Tandai selesai") {
                        viewModel.completeTask(task)
                    }
                    .buttonStyle(CompactActionButtonStyle())
                    .fixedSize(horizontal: true, vertical: false)
                }

                Spacer(minLength: 8)

                Button("Hapus") {
                    isConfirmingDelete = true
                }
                .buttonStyle(CompactDangerButtonStyle())
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func submitUpdate() {
        let trimmed = updateNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed.count > 240 {
            viewModel.showToast("Catatan update harus berisi maksimal 240 karakter.", isError: true)
            return
        }
        let isoDate = WorkDateFormatting.localISODate(from: updateDate)
        viewModel.addUpdate(taskId: task.id, date: isoDate, note: trimmed)
        updateNote = ""
        updateDate = Date()
    }
}

private struct CompactActionButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.secondaryInk)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(configuration.isPressed || isHovered ? AppTheme.hoverSurface : AppTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(AppTheme.lineStrong.opacity(0.6), lineWidth: 1)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

private struct CompactDangerButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.red)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(configuration.isPressed || isHovered ? AppTheme.redSoft : AppTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(AppTheme.dangerBorder, lineWidth: 1)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

private struct CompactHighlightActionButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.blue)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(configuration.isPressed || isHovered ? AppTheme.blueSoft : AppTheme.blueSoft.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(AppTheme.blue.opacity(0.35), lineWidth: 1)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

