import SwiftUI
import WhatsYourStatusCore

struct NewWorkspaceSheet: View {
    let viewModel: WorkQueueViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var workspaceName: String = ""
    @State private var errorMessage: String = ""

    private let suggestions = ["Panorama", "Aurora Cloud", "Internal", "Client Project"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerBar

            Divider().overlay(AppTheme.line)

            inputSection

            suggestionsSection

            if !errorMessage.isEmpty {
                errorBanner
            }

            Divider().overlay(AppTheme.line)

            footerActions
        }
        .padding(24)
        .frame(width: 440)
        .background(AppTheme.paper)
    }

    private var headerBar: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.blueSoft)
                    .frame(width: 36, height: 36)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Buat workspace baru")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text("Pisahkan kerjaan untuk klien, divisi, atau konteks proyek.")
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
            .accessibilityLabel("Tutup")
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nama workspace")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryInk)

            TextField("Misal: Panorama, Aurora Cloud", text: $workspaceName)
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
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Contoh nama:")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.muted)

            HStack(spacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        workspaceName = suggestion
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.canvas)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(AppTheme.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

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
        .padding(.horizontal, 10)
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

    private var footerActions: some View {
        HStack(spacing: 10) {
            Spacer()

            Button("Batal") {
                dismiss()
            }
            .buttonStyle(QuietButtonStyle())

            Button("Buat workspace") {
                submit()
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
    }

    private func submit() {
        errorMessage = ""
        let trimmed = workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Nama workspace harus diisi."
            return
        }

        viewModel.createWorkspace(name: trimmed)
        dismiss()
    }
}
