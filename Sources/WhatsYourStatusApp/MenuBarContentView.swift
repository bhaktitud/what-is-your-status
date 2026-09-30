import AppKit
import SwiftUI
import WhatsYourStatusCore

struct MenuBarContentView: View {
    @Bindable var viewModel: WorkQueueViewModel
    @Environment(\.openWindow) private var openWindow

    @State private var selectedTab: MenuBarTab = .action

    enum MenuBarTab: String, CaseIterable, Identifiable {
        case action = "Perlu Aksi"
        case all = "Semua Aktif"

        var id: String { rawValue }
    }

    private var displayedTasks: [WorkTask] {
        let active = viewModel.tasks.filter { $0.lane != .done }
        switch selectedTab {
        case .action:
            return active.filter { $0.lane == .action }
        case .all:
            return active
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().overlay(AppTheme.line)
            tabBar
            Divider().overlay(AppTheme.line.opacity(0.8))
            taskListArea
            Divider().overlay(AppTheme.line)
            footerBar
        }
        .frame(width: 360, height: 460)
        .background(AppTheme.canvas)
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.blue)

            Text("What's Your Status?")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Spacer()

            if viewModel.counts.action > 0 {
                Text("\(viewModel.counts.action) aksi")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppTheme.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppTheme.redSoft))
            } else {
                Text("Semua aman")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppTheme.greenSoft))
            }

            Button {
                openMainWindow()
                viewModel.openNewTaskForm()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(IconCloseButtonStyle())
            .help("Tambah task baru")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppTheme.paper)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(MenuBarTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 5) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? AppTheme.blueInk : AppTheme.secondaryInk)

                        let count = tab == .action
                            ? viewModel.counts.action
                            : (viewModel.counts.all - (viewModel.tasks.filter { $0.lane == .done }.count))
                        Text("\(count)")
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium).monospacedDigit())
                            .foregroundStyle(isSelected ? AppTheme.blueInk : AppTheme.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(isSelected ? AppTheme.blue.opacity(0.12) : AppTheme.surfaceMuted)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? AppTheme.blueSoft : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.paper)
    }

    @ViewBuilder
    private var taskListArea: some View {
        let tasks = WorkQueueLogic.sortTasks(displayedTasks)
        if tasks.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: selectedTab == .action ? "checkmark.circle" : "tray")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.muted)

                Text(selectedTab == .action ? "Tidak ada task yang perlu aksi." : "Belum ada task aktif.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryInk)

                Text("Tekan tombol di bawah untuk melihat seluruh ruang kerja.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        MenuBarTaskRow(task: task) {
                            openMainWindow(focusingTask: task.id)
                        } onComplete: {
                            viewModel.completeTask(task)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
    }

    private var footerBar: some View {
        HStack(spacing: 8) {
            Button {
                openMainWindow()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                    Text("Buka aplikasi utama")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                openMainWindow()
                viewModel.isShowingSettingsSheet = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(IconCloseButtonStyle())
            .help("Pengaturan aplikasi")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(IconCloseButtonStyle())
            .help("Keluar dari aplikasi")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.paper)
    }

    private func openMainWindow(focusingTask taskId: String? = nil) {
        openWindow(id: "main-window")
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let taskId {
            viewModel.selectedTaskId = taskId
        }
    }
}

private struct MenuBarTaskRow: View {
    let task: WorkTask
    let onOpen: () -> Void
    let onComplete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Text(task.project.isEmpty ? "Tanpa nama proyek" : task.project)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)

                    Spacer()

                    StatusBadge(lane: task.lane)
                }

                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.top, 1)

                    Text(task.nextAction.isEmpty ? "Tambahkan langkah berikutnya" : task.nextAction)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.focusSurface)
                )

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.muted)
                        Text(task.owner.isEmpty ? "Belum ditentukan" : task.owner)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    followUpIndicator

                    Spacer()

                    if isHovered && task.lane != .done {
                        Button {
                            onComplete()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Selesai")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.greenSoft))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(isHovered ? AppTheme.cardHoverSurface : AppTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.04 : 0.015), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var followUpIndicator: some View {
        switch WorkDateFormatting.followUpStatus(for: task) {
        case .unset:
            EmptyView()
        case .overdue(let formatted):
            Text("Terlambat, \(formatted)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.red)
        case .dueToday:
            Text("Hari ini")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.amber)
        case .scheduled(let formatted):
            Text(formatted)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.muted)
        }
    }
}
