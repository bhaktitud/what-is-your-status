import AppKit
import SwiftUI
import WhatsYourStatusCore

struct SettingsSheet: View {
    @Bindable var viewModel: WorkQueueViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: SettingsTab = .general
    @State private var launchAtLoginError: String? = nil
    @State private var isTestingEditor: Bool = false

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "Umum"
        case appearance = "Tampilan"
        case editor = "Editor Kode"
        case storage = "Database"
        case about = "Tentang"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintpalette"
            case .editor: return "chevron.left.forwardslash.chevron.right"
            case .storage: return "cylinder.split.1x2"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pengaturan")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("Sesuaikan preferensi tampilan, startup, dan editor kode.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(IconCloseButtonStyle())
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().overlay(AppTheme.line)

            // Content Area with Sidebar/Tabs
            HStack(spacing: 0) {
                // Tab selector sidebar
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        let isSelected = selectedTab == tab
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? AppTheme.blue : AppTheme.muted)
                                    .frame(width: 18)

                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? AppTheme.blueInk : AppTheme.secondaryInk)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                    .fill(isSelected ? AppTheme.blueSoft.opacity(0.7) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .frame(width: 160)
                .background(AppTheme.paper)

                Divider().overlay(AppTheme.line)

                // Tab details
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .general:
                            generalSettingsView
                        case .appearance:
                            appearanceSettingsView
                        case .editor:
                            editorSettingsView
                        case .storage:
                            storageSettingsView
                        case .about:
                            aboutSettingsView
                        }
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvas)
            }

            Divider().overlay(AppTheme.line)

            // Footer
            HStack {
                Spacer()
                Button("Tutup") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.paper)
        }
        .frame(width: 680, height: 500)
        .background(AppTheme.paper)
        .preferredColorScheme(viewModel.colorScheme)
    }

    // MARK: - General (Startup & System)
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Startup & Latar Belakang")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            VStack(alignment: .leading, spacing: 14) {
                // Launch on Startup Toggle
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "macwindow.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: Binding(
                            get: { viewModel.isLaunchAtLoginEnabled },
                            set: { newValue in
                                viewModel.isLaunchAtLoginEnabled = newValue
                                if !viewModel.isLaunchAtLoginEnabled && newValue {
                                    launchAtLoginError = "Izin login item dibatasi oleh sistem macOS."
                                } else {
                                    launchAtLoginError = nil
                                }
                            }
                        )) {
                            Text("Jalankan otomatis saat startup (Login Item)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.ink)
                        }
                        .toggleStyle(.switch)

                        Text("Aplikasi What's Your Status? akan otomatis aktif di latar belakang saat Mac Anda dinyalakan atau login.")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        if let error = launchAtLoginError {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.red)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding(14)
                .background(AppTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )

                // Menu Bar Extra Info
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Menu Bar Ekstra")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)

                        Text("Ikon status di menu bar atas macOS selalu standby untuk melihat ringkasan task yang butuh aksi tanpa perlu membuka jendela utama.")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(AppTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Appearance (Light, Dark, System)
    private var appearanceSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tema Aplikasi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text("Pilih mode tampilan sesuai preferensi Anda.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
            }

            HStack(spacing: 14) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    let isSelected = viewModel.appearanceMode == mode
                    Button {
                        viewModel.appearanceMode = mode
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(appearanceCardBackground(for: mode))
                                    .frame(height: 72)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(isSelected ? AppTheme.blue : AppTheme.line, lineWidth: isSelected ? 2 : 1)
                                    )

                                Image(systemName: mode.icon)
                                    .font(.system(size: 26))
                                    .foregroundStyle(appearanceIconColor(for: mode))
                            }

                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(isSelected ? AppTheme.blue : AppTheme.muted)

                                Text(mode.label)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.secondaryInk)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                                .stroke(isSelected ? AppTheme.blue : AppTheme.line, lineWidth: isSelected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Pilihan tema akan langsung diterapkan ke seluruh ruang kerja antrean, board, detail task, dan menu bar.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.muted)
                .padding(.top, 4)
        }
    }

    private func appearanceCardBackground(for mode: AppAppearanceMode) -> Color {
        switch mode {
        case .system:
            return AppTheme.surfaceMuted
        case .light:
            return Color.white
        case .dark:
            return Color(red: 0x12 / 255.0, green: 0x14 / 255.0, blue: 0x1A / 255.0)
        }
    }

    private func appearanceIconColor(for mode: AppAppearanceMode) -> Color {
        switch mode {
        case .system:
            return AppTheme.blue
        case .light:
            return Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x06 / 255.0)
        case .dark:
            return Color(red: 0x81 / 255.0, green: 0x8C / 255.0, blue: 0xF8 / 255.0)
        }
    }

    // MARK: - Code Editor
    private var editorSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Editor Kode Default")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text("Aplikasi ini akan digunakan saat membuka folder project dari detail task atau baris antrean.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
            }

            VStack(spacing: 8) {
                ForEach(CodeEditorApp.allCases) { editor in
                    let isSelected = viewModel.preferredCodeEditor == editor
                    let isInstalled = ProjectLauncher.isEditorInstalled(editor)

                    Button {
                        viewModel.preferredCodeEditor = editor
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: editor.systemIcon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(isSelected ? AppTheme.blue : AppTheme.secondaryInk)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(editor.displayName)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                    .foregroundStyle(AppTheme.ink)

                                Text(editorSubtext(for: editor))
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.muted)
                            }

                            Spacer()

                            if isInstalled {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Terpasang")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(AppTheme.green)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppTheme.greenSoft))
                            } else {
                                Text("Tidak terdeteksi")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.muted)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(AppTheme.surfaceMuted))
                            }

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(isSelected ? AppTheme.blue : AppTheme.muted)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isSelected ? AppTheme.blueSoft.opacity(0.4) : AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                .stroke(isSelected ? AppTheme.blue : AppTheme.line, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func editorSubtext(for editor: CodeEditorApp) -> String {
        switch editor {
        case .antiGravity: return "Google Antigravity IDE"
        case .vscode: return "Visual Studio Code"
        case .cursor: return "Cursor AI Code Editor"
        case .xcode: return "Apple Xcode IDE"
        case .windsurf: return "Codeium Windsurf"
        case .zed: return "Zed High-Performance Editor"
        case .terminal: return "macOS Terminal (cd ke folder)"
        case .finder: return "Buka lokasi direktori di Finder"
        }
    }

    // MARK: - Storage Settings
    private var storageSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Penyimpanan Database SQLite")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text("Data task, riwayat event, sticky notes, dan garis tersimpan secara lokal dan aman di Mac Anda.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(AppTheme.green)
                        .frame(width: 8, height: 8)

                    Text("Status Koneksi: Terhubung (SQLite 3)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Lokasi Database:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryInk)

                    Text(viewModel.currentDatabasePath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.ink)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(AppTheme.line, lineWidth: 1)
                        )
                }

                HStack(spacing: 10) {
                    Button {
                        let url = URL(fileURLWithPath: viewModel.currentDatabasePath)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label("Tampilkan di Finder", systemImage: "folder")
                    }
                    .buttonStyle(QuietButtonStyle())

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.currentDatabasePath, forType: .string)
                    } label: {
                        Label("Salin Path", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(QuietButtonStyle())

                    Button {
                        viewModel.loadFromDatabase()
                    } label: {
                        Label("Muat Ulang", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(QuietButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
        }
    }

    // MARK: - About
    private var aboutSettingsView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            ZStack {
                Circle()
                    .fill(AppTheme.blueSoft)
                    .frame(width: 72, height: 72)

                Image(systemName: "checklist")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
            }

            VStack(spacing: 4) {
                Text("What's Your Status?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text("Versi 1.0 (Build 2026.1)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
            }

            Text("Aplikasi manajemen antrean kerja, status proyek, dan sticky note board kolaboratif yang terintegrasi dengan code editor favorit Anda.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Divider().overlay(AppTheme.line)
                .padding(.vertical, 8)

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("PLATFORM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.subtleMuted)
                    Text("macOS 14+ (Sonoma / Sequoia)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                }

                VStack(spacing: 2) {
                    Text("TEKNOLOGI")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.subtleMuted)
                    Text("Swift 6 + Native SwiftUI")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
