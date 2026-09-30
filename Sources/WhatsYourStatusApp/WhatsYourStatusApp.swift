import AppKit
import SwiftUI
import WhatsYourStatusCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let iconUrl = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconUrl) {
            NSApplication.shared.applicationIconImage = iconImage
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct WhatsYourStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = WorkQueueViewModel()

    var body: some Scene {
        WindowGroup("What's Your Status?", id: "main-window") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 860, minHeight: 580)
                .preferredColorScheme(viewModel.colorScheme)
        }
        .defaultSize(width: 1240, height: 800)

        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
                .preferredColorScheme(viewModel.colorScheme)
        } label: {
            let actionCount = viewModel.counts.action
            HStack(spacing: 4) {
                Image(systemName: actionCount > 0 ? "checklist.checked" : "checklist")
                if actionCount > 0 {
                    Text("\(actionCount)")
                }
            }
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Pengaturan...") {
                    viewModel.isShowingSettingsSheet = true
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandMenu("Work Queue") {
                Button("Task baru") {
                    viewModel.openNewTaskForm()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Cari kerjaan") {
                    viewModel.searchFocusTrigger += 1
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("Daftar orang") {
                    viewModel.isShowingPeopleSheet = true
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Workspace baru") {
                    viewModel.isShowingNewWorkspaceSheet = true
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])

                Divider()

                Button("Buka Antrean Status") {
                    viewModel.activeSection = .queue
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("Buka Sticky Board") {
                    viewModel.activeSection = .stickyBoard
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Divider()

                Button("Semua kerjaan") {
                    viewModel.selectFilter(.all)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Perlu saya gerakkan") {
                    viewModel.selectFilter(.action)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Nunggu orang lain") {
                    viewModel.selectFilter(.waiting)
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Belum ada follow-up") {
                    viewModel.selectFilter(.noFollowUp)
                }
                .keyboardShortcut("4", modifiers: [.command])

                Button("Terhambat") {
                    viewModel.selectFilter(.blocked)
                }
                .keyboardShortcut("5", modifiers: [.command])

                Divider()

                Button("Muat ulang database") {
                    viewModel.loadFromDatabase()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
