import SwiftUI
import WhatsYourStatusCore

struct ContentView: View {
    @Bindable var viewModel: WorkQueueViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                sidebarView
                Divider().overlay(AppTheme.line)

                if viewModel.activeSection == .stickyBoard {
                    StickyBoardView(viewModel: viewModel)
                } else {
                    GeometryReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                topbarView
                                pageIntroView
                                snapshotBarView
                                queueAreaView(availableWidth: proxy.size.width)
                            }
                            .padding(.horizontal, horizontalPadding(for: proxy.size.width))
                            .padding(.bottom, 64)
                            .frame(maxWidth: 1040, alignment: .leading)
                        }
                    }
                    .background(AppTheme.canvas)

                    if let selectedTask = viewModel.selectedTask {
                        Divider().overlay(AppTheme.line)
                        TaskDetailView(task: selectedTask, viewModel: viewModel)
                            .frame(width: 450)
                            .transition(.move(edge: .trailing))
                    }
                }
            }

            if let toast = viewModel.toast {
                toastView(toast)
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
            }
        }
        .background(AppTheme.canvas)
        .preferredColorScheme(viewModel.colorScheme)
        .onChange(of: viewModel.searchFocusTrigger) { _, _ in
            isSearchFocused = true
        }
        .sheet(isPresented: $viewModel.isShowingTaskSheet) {
            TaskFormSheet(viewModel: viewModel, existingTask: viewModel.editingTask)
        }
        .sheet(isPresented: $viewModel.isShowingPeopleSheet) {
            PeopleSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingNewWorkspaceSheet) {
            NewWorkspaceSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingSettingsSheet) {
            SettingsSheet(viewModel: viewModel)
        }
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        if width < 640 { return 20 }
        if width < 960 { return 32 }
        return 44
    }

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "checklist")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Text("What's Your Status?")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)

            workspaceSelectorView

            Text("NAVIGASI")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.subtleMuted)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            VStack(spacing: 3) {
                Button {
                    viewModel.activeSection = .queue
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 12))
                            .foregroundStyle(viewModel.activeSection == .queue ? AppTheme.blue : AppTheme.muted)
                            .frame(width: 18)

                        Text("Antrean Status")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(viewModel.activeSection == .queue ? AppTheme.blueInk : AppTheme.secondaryInk)

                        Spacer()

                        Text("\(viewModel.counts.all)")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(viewModel.activeSection == .queue ? AppTheme.blueInk : AppTheme.muted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(viewModel.activeSection == .queue ? AppTheme.blueSoft : AppTheme.surfaceMuted)
                            )
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .fill(viewModel.activeSection == .queue ? AppTheme.blueSoft.opacity(0.6) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.activeSection = .stickyBoard
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "square.grid.3x3.square")
                            .font(.system(size: 12))
                            .foregroundStyle(viewModel.activeSection == .stickyBoard ? AppTheme.blue : AppTheme.muted)
                            .frame(width: 18)

                        Text("Sticky Board")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(viewModel.activeSection == .stickyBoard ? AppTheme.blueInk : AppTheme.secondaryInk)

                        Spacer()

                        Text("\(viewModel.currentStickyNotes.count)")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(viewModel.activeSection == .stickyBoard ? AppTheme.blueInk : AppTheme.muted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(viewModel.activeSection == .stickyBoard ? AppTheme.blueSoft : AppTheme.surfaceMuted)
                            )
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                            .fill(viewModel.activeSection == .stickyBoard ? AppTheme.blueSoft.opacity(0.6) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            if viewModel.activeSection == .queue {
                Text("STATUS ANTREAN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.subtleMuted)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)

                VStack(spacing: 3) {
                    ForEach(QueueFilter.allCases) { filter in
                        SidebarFilterRow(
                            filter: filter,
                            count: viewModel.counts.count(for: filter),
                            isActive: viewModel.currentFilter == filter
                        ) {
                            viewModel.selectFilter(filter)
                        }
                    }
                }
            }

            Divider()
                .overlay(AppTheme.line)
                .padding(.vertical, 14)

            Button {
                viewModel.isShowingPeopleSheet = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "person.2")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 18)

                    Text("Daftar orang")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryInk)

                    Spacer()

                    Text("\(viewModel.people.count)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(AppTheme.surfaceMuted)
                        )
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 38)
            }
            .buttonStyle(SidebarPlainRowStyle())

            Button {
                viewModel.isShowingSettingsSheet = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 18)

                    Text("Pengaturan")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryInk)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 38)
            }
            .buttonStyle(SidebarPlainRowStyle())

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(storageDotColor)
                    .frame(width: 7, height: 7)

                Text(viewModel.storageLabelText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.surfaceMuted.opacity(0.6))
            )
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
        .padding(.horizontal, 14)
        .frame(width: 232)
        .background(AppTheme.paper)
    }

    private var workspaceSelectorView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORKSPACE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.subtleMuted)
                .padding(.horizontal, 10)

            Menu {
                Section("PILIH WORKSPACE") {
                    Button {
                        viewModel.selectWorkspace(nil)
                    } label: {
                        HStack {
                            Text("Semua Workspace")
                            if viewModel.selectedWorkspaceId == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    ForEach(viewModel.workspaces) { ws in
                        Button {
                            viewModel.selectWorkspace(ws.id)
                        } label: {
                            HStack {
                                Text(ws.name)
                                if viewModel.selectedWorkspaceId == ws.id {
                                    Image(systemName: "checkmark")
                                }
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.blue.opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.blue)
                    }

                    Text(viewModel.currentWorkspaceName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.surfaceMuted.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 8)
        }
        .padding(.bottom, 16)
    }

    private var storageDotColor: Color {
        switch viewModel.storageState {
        case .loading:
            return AppTheme.slate
        case .saved:
            return AppTheme.green
        case .error:
            return AppTheme.red
        }
    }

    private var topbarView: some View {
        HStack(spacing: 16) {
            Text(WorkDateFormatting.formatHeaderDate())
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.muted)

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)

                    TextField("Cari task atau orang", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ink)
                        .focused($isSearchFocused)

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("⌘F")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(AppTheme.surfaceMuted)
                            )
                    }
                }
                .padding(.horizontal, 12)
                .frame(width: 260, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .fill(AppTheme.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )

                Button {
                    viewModel.openNewTaskForm()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Task baru")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Divider().overlay(AppTheme.line.opacity(0.8))
        }
    }

    private var pageIntroView: some View {
        HStack(alignment: .lastTextBaseline, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Kerjaan yang perlu bergerak")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.ink)

                    HStack(spacing: 5) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 10))
                        Text(viewModel.currentWorkspaceName)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.blueInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.blueSoft))
                }

                Text("Pantau siapa yang memegang giliran dan apa aksi konkret berikutnya.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            Spacer()

            Text(viewModel.saveStatusText)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var snapshotBarView: some View {
        HStack(spacing: 8) {
            SnapshotChipButton(
                count: viewModel.counts.action,
                label: "Perlu saya gerakkan",
                color: AppTheme.red,
                isActive: viewModel.currentFilter == .action
            ) {
                viewModel.selectFilter(.action)
            }

            SnapshotChipButton(
                count: viewModel.counts.waiting,
                label: "Nunggu orang lain",
                color: AppTheme.externalInk,
                isActive: viewModel.currentFilter == .waiting
            ) {
                viewModel.selectFilter(.waiting)
            }

            SnapshotChipButton(
                count: viewModel.counts.noFollowUp,
                label: "Follow-up belum diatur",
                color: AppTheme.amber,
                isActive: viewModel.currentFilter == .noFollowUp
            ) {
                viewModel.selectFilter(.noFollowUp)
            }

            Spacer()
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func queueAreaView(availableWidth: CGFloat) -> some View {
        switch viewModel.storageState {
        case .loading:
            loadingStateView
        case .error(let detail):
            errorStateView(detail: detail)
        case .saved:
            let visible = viewModel.visibleTasks
            if visible.isEmpty {
                emptyStateView
            } else if viewModel.currentFilter != .all {
                filteredStackView(visible: visible)
            } else {
                allTasksGridView(visible: visible, availableWidth: availableWidth)
            }
        }
    }

    private var loadingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Memuat task dari SQLite...")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private func errorStateView(detail: String) -> some View {
        VStack(spacing: 12) {
            Text("Database SQLite belum bisa diakses.")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.red)

            Text("\(detail) Periksa izin folder Application Support Anda.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button("Coba hubungkan lagi") {
                viewModel.loadFromDatabase()
            }
            .buttonStyle(QuietButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.redSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(AppTheme.dangerBorder)
        )
    }

    private var emptyStateView: some View {
        let isSearching = !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(spacing: 12) {
            Image(systemName: isSearching ? "magnifyingglass" : "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(AppTheme.muted)
                .padding(14)
                .background(Circle().fill(AppTheme.surfaceMuted))

            if isSearching || viewModel.currentFilter != .all {
                Text(isSearching ? "Tidak ada hasil yang cocok" : emptyFilterTitle(for: viewModel.currentFilter))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(isSearching ? "Coba kata kunci lain atau bersihkan pencarian." : "Pilih filter lain untuk melihat kerjaan yang berbeda.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                if isSearching {
                    Button("Bersihkan pencarian") {
                        viewModel.clearSearch()
                    }
                    .buttonStyle(QuietButtonStyle())
                    .padding(.top, 6)
                }
            } else {
                Text("Belum ada kerjaan yang dicatat")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)

                Text("Tambahkan task aktif agar jelas siapa yang menangani dan apa langkah berikutnya.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                HStack(spacing: 10) {
                    Button("Tambah task pertama") {
                        viewModel.openNewTaskForm()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Coba contoh dari skenario kamu") {
                        viewModel.loadExampleScenario()
                    }
                    .buttonStyle(QuietButtonStyle())
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(AppTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private func emptyFilterTitle(for filter: QueueFilter) -> String {
        switch filter {
        case .action:
            return "Tidak ada task yang perlu saya gerakkan."
        case .waiting:
            return "Tidak ada task yang sedang menunggu orang lain."
        case .noFollowUp:
            return "Semua task aktif sudah punya jadwal follow-up."
        case .blocked:
            return "Tidak ada task yang sedang terhambat."
        case .all:
            return "Belum ada task di sini."
        }
    }

    private func filteredStackView(visible: [WorkTask]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.currentFilter.label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("\(visible.count) task")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
            }

            VStack(spacing: 10) {
                ForEach(WorkQueueLogic.sortTasks(visible)) { task in
                    TaskCardView(
                        task: task,
                        workspaceName: viewModel.workspaceName(for: task.workspaceId),
                        isSelected: viewModel.selectedTaskId == task.id
                    ) {
                        viewModel.selectedTaskId = task.id
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func allTasksGridView(visible: [WorkTask], availableWidth: CGFloat) -> some View {
        let actionTasks = visible.filter { $0.lane == .action }
        let waitingTasks = visible.filter { $0.lane == .external || $0.lane == .internal }
        let blockedTasks = visible.filter { $0.lane == .blocked }
        let doneTasks = visible.filter { $0.lane == .done }

        let sections: [(title: String, subtitle: String, tasks: [WorkTask])] = [
            ("Perlu saya gerakkan", "Aksi berikutnya ada di saya", actionTasks),
            ("Nunggu orang lain", "Menunggu tindak lanjut dari orang lain", waitingTasks),
            ("Terhambat", "Perlu dibuka sebelum bisa lanjut", blockedTasks),
            ("Selesai", "Riwayat kerja yang sudah ditutup", doneTasks)
        ].filter { !$0.tasks.isEmpty }

        VStack(alignment: .leading, spacing: 28) {
            ForEach(Array(sections.enumerated()), id: \.element.title) { index, section in
                VStack(alignment: .leading, spacing: 28) {
                    queueSectionView(title: section.title, subtitle: section.subtitle, tasks: section.tasks)
                    if index < sections.count - 1 {
                        Divider().overlay(AppTheme.line.opacity(0.85))
                    }
                }
            }
        }
    }

    private func queueSectionView(title: String, subtitle: String, tasks: [WorkTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
            }

            VStack(spacing: 10) {
                ForEach(WorkQueueLogic.sortTasks(tasks)) { task in
                    TaskCardView(
                        task: task,
                        workspaceName: viewModel.workspaceName(for: task.workspaceId),
                        isSelected: viewModel.selectedTaskId == task.id
                    ) {
                        viewModel.selectedTaskId = task.id
                    }
                }
            }
        }
    }

    private func toastView(_ toast: ToastBanner) -> some View {
        Text(toast.message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(toast.isError ? AppTheme.red : AppTheme.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(toast.isError ? AppTheme.redSoft : AppTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(toast.isError ? AppTheme.dangerBorder : AppTheme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
    }
}

private struct SidebarFilterRow: View {
    let filter: QueueFilter
    let count: Int
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var filterIcon: String {
        switch filter {
        case .all:
            return "tray"
        case .action:
            return "bolt.fill"
        case .waiting:
            return "person.2.fill"
        case .noFollowUp:
            return "clock.badge.exclamationmark"
        case .blocked:
            return "exclamationmark.octagon.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: filterIcon)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? AppTheme.blue : AppTheme.muted)
                    .frame(width: 18)

                Text(filter.label)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? AppTheme.blueInk : AppTheme.secondaryInk)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 11, weight: isActive ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(isActive ? AppTheme.blueInk : AppTheme.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(isActive ? AppTheme.blue.opacity(0.12) : AppTheme.surfaceMuted)
                    )
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? AppTheme.blueSoft : (isHovered ? AppTheme.hoverSurface : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct SidebarPlainRowStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed || isHovered ? AppTheme.hoverSurface : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

private struct SnapshotChipButton: View {
    let count: Int
    let label: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(color.opacity(0.12))
                    )

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(.horizontal, 11)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(isActive || isHovered ? AppTheme.paper : AppTheme.surfaceMuted.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(isActive ? color : AppTheme.line, lineWidth: isActive ? 1.5 : 1)
            )
            .shadow(color: isActive ? Color.black.opacity(0.04) : Color.clear, radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct TaskCardView: View {
    let task: WorkTask
    let workspaceName: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // Top header row: Workspace tag, Project tag & Status Pill
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(workspaceName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.blueInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.blueSoft))

                        Text(task.project.isEmpty ? "Tanpa nama proyek" : task.project)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    StatusBadge(lane: task.lane)
                }

                // Task title
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Next action callout box (airy and clean, no hard dividing lines)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Langkah berikutnya")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.muted)

                        Text(task.nextAction.isEmpty ? "Tambahkan langkah berikutnya" : task.nextAction)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.focusSurface)
                )

                // Bottom row: Owner badge & Follow-up chip
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.blue.opacity(0.12))
                                .frame(width: 20, height: 20)
                            Text(avatarInitial(for: task.owner))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.blue)
                        }

                        Text(task.owner.isEmpty ? "Belum ditentukan" : task.owner)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    followUpChip

                    Spacer()

                    if task.isExample {
                        Text("Contoh")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.surfaceMuted))
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                    .fill(isHovered ? AppTheme.cardHoverSurface : AppTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                    .stroke(isSelected ? AppTheme.blue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.05 : 0.02), radius: isHovered ? 8 : 4, y: isHovered ? 3 : 1.5)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Buka task \(task.title)")
    }

    private func avatarInitial(for owner: String) -> String {
        guard let first = owner.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "?"
        }
        return String(first).uppercased()
    }

    @ViewBuilder
    private var followUpChip: some View {
        switch WorkDateFormatting.followUpStatus(for: task) {
        case .unset:
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                Text("Belum diatur")
                    .font(.system(size: 11))
            }
            .foregroundStyle(AppTheme.muted)
        case .overdue(let formatted):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                Text("Terlambat, \(formatted)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(AppTheme.red)
        case .dueToday:
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                Text("Hari ini")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(AppTheme.amber)
        case .scheduled(let formatted):
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                Text(formatted)
                    .font(.system(size: 11))
            }
            .foregroundStyle(AppTheme.muted)
        }
    }
}
