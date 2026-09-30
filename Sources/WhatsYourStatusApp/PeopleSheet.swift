import SwiftUI
import WhatsYourStatusCore

struct PeopleSheet: View {
    let viewModel: WorkQueueViewModel
    var onPersonAdded: ((Person) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("Daftar orang")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(IconCloseButtonStyle())
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Tutup")
            }
            .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text("Nama orang baru")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryInk)

                HStack(spacing: 8) {
                    TextField("Contoh: Jared Smith", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                .fill(AppTheme.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                .stroke(AppTheme.line, lineWidth: 1)
                        )
                        .onSubmit {
                            submitPerson()
                        }

                    Button("Tambah") {
                        submitPerson()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.red)
            }

            Divider().overlay(AppTheme.line)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Orang tersimpan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                    Spacer()
                    Text("\(viewModel.people.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }

                if viewModel.people.isEmpty {
                    Text("Belum ada orang tersimpan.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                                .fill(AppTheme.surfaceMuted)
                        )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.people) { person in
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(AppTheme.blue.opacity(0.12))
                                            .frame(width: 22, height: 22)
                                        Text(String(person.name.first ?? "?").uppercased())
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(AppTheme.blue)
                                    }

                                    Text(person.name)
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.secondaryInk)

                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(AppTheme.surfaceMuted.opacity(0.5))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }

            HStack {
                Spacer()
                Button("Selesai") {
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 440)
        .background(AppTheme.paper)
    }

    private func submitPerson() {
        errorMessage = ""
        let normalized = WorkDateFormatting.collapseWhitespace(name)
        guard !normalized.isEmpty else {
            errorMessage = "Nama orang harus diisi."
            return
        }
        do {
            let person = try viewModel.addPerson(name: normalized)
            onPersonAdded?(person)
            name = ""
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Orang belum tersimpan."
        }
    }
}
