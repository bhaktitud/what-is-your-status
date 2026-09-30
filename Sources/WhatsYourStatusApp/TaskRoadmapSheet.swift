import SwiftUI
import WhatsYourStatusCore

struct TaskRoadmapSheet: View {
    let task: WorkTask
    let viewModel: WorkQueueViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var newNote: String = ""
    @State private var newDate: Date = Date()
    @State private var isShowingAddBar: Bool = false

    // Chronological order: from oldest (inception) to newest
    private var chronologicalEvents: [TaskEvent] {
        task.events.sorted { a, b in
            if a.date != b.date {
                return a.date < b.date
            }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider().overlay(AppTheme.line)

            roadmapCanvasArea

            Divider().overlay(AppTheme.line)

            footerActionBar
        }
        .frame(minWidth: 880, minHeight: 580)
        .background(AppTheme.canvas)
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.project.isEmpty ? "Tanpa nama proyek" : task.project)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)

                    StatusBadge(lane: task.lane)

                    if !task.owner.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.muted)
                            Text(task.owner)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppTheme.surfaceMuted))
                    }
                }

                Text(task.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        isShowingAddBar.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isShowingAddBar ? "chevron.down" : "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(isShowingAddBar ? "Sembunyikan form" : "Tambah update")
                    }
                }
                .buttonStyle(QuietButtonStyle())

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(IconCloseButtonStyle())
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Tutup roadmap")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppTheme.paper)
    }

    // MARK: - Canvas Area
    private var roadmapCanvasArea: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(spacing: 0) {
                if chronologicalEvents.isEmpty {
                    emptyRoadmapView
                } else {
                    HorizontalRoadmapDiagram(events: chronologicalEvents)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 32)
                }
            }
            .frame(minWidth: 840, minHeight: 460)
        }
    }

    // MARK: - Empty State
    private var emptyRoadmapView: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.topleft.filled.down.to.point.bottomright.curvepath")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.blue.opacity(0.8))
                .padding(16)
                .background(Circle().fill(AppTheme.blueSoft))

            Text("Belum ada catatan riwayat untuk task ini")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.ink)

            Text("Tambahkan catatan pertama di bawah untuk mulai membangun roadmap perjalanan task.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Catat milestone awal") {
                withAnimation {
                    isShowingAddBar = true
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)
        }
        .padding(40)
    }

    // MARK: - Footer Add Bar
    private var footerActionBar: some View {
        VStack(spacing: 0) {
            if isShowingAddBar {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Catatan update baru")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)

                        TextField("Apa milestone atau update terbaru untuk task ini?", text: $newNote)
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
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Tanggal")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)

                        DatePicker(
                            "Tanggal update",
                            selection: $newDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .frame(height: 38)
                    }

                    VStack(spacing: 0) {
                        Spacer().frame(height: 19)
                        Button("Simpan milestone") {
                            submitNewUpdate()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(AppTheme.paper)
                .overlay(alignment: .top) {
                    Divider().overlay(AppTheme.line)
                }
            }

            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.blue)
                        .frame(width: 6, height: 6)
                    Text("Total \(chronologicalEvents.count) milestone tercatat secara kronologis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Button("Tutup") {
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.canvas)
        }
    }

    private func submitNewUpdate() {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed.count > 240 {
            viewModel.showToast("Catatan update maksimal 240 karakter.", isError: true)
            return
        }
        let isoDate = WorkDateFormatting.localISODate(from: newDate)
        viewModel.addUpdate(taskId: task.id, date: isoDate, note: trimmed)
        newNote = ""
        newDate = Date()
    }
}

// MARK: - Horizontal Roadmap Diagram
private struct HorizontalRoadmapDiagram: View {
    let events: [TaskEvent]

    private let nodeSpacing: CGFloat = 260
    private let horizontalPadding: CGFloat = 100
    private let centerY: CGFloat = 220
    private let totalHeight: CGFloat = 440

    // Palette matching the user's reference illustration
    private let milestonePalette: [(color: Color, icon: String)] = [
        (Color(red: 0xF5 / 255.0, green: 0x9E / 255.0, blue: 0x0B / 255.0), "sparkles"),           // 01: Warm Gold / Hot Air Balloon
        (Color(red: 0xF9 / 255.0, green: 0x73 / 255.0, blue: 0x16 / 255.0), "airplane"),           // 02: Vibrant Coral / Helicopter
        (Color(red: 0x10 / 255.0, green: 0xB9 / 255.0, blue: 0x81 / 255.0), "paperplane.fill"),     // 03: Green / Plane
        (Color(red: 0x0E / 255.0, green: 0xA5 / 255.0, blue: 0xE9 / 255.0), "bolt.fill"),           // 04: Sky Blue / Rocket
        (Color(red: 0x8B / 255.0, green: 0x5C / 255.0, blue: 0xF6 / 255.0), "atom"),                // 05: Rich Purple / Atom
        (Color(red: 0xEC / 255.0, green: 0x48 / 255.0, blue: 0x99 / 255.0), "star.fill"),           // 06: Rose
        (Color(red: 0x14 / 255.0, green: 0xB8 / 255.0, blue: 0xA6 / 255.0), "checkmark.seal.fill")  // 07: Teal
    ]

    private var calculatedWidth: CGFloat {
        max(860, horizontalPadding * 2 + CGFloat(max(events.count - 1, 0)) * nodeSpacing)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main horizontal baseline axis
            Path { path in
                path.move(to: CGPoint(x: 20, y: centerY))
                path.addLine(to: CGPoint(x: calculatedWidth - 20, y: centerY))
            }
            .stroke(
                AppTheme.ink.opacity(0.85),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )

            // Milestone nodes with alternating branches
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                let posX = horizontalPadding + CGFloat(index) * nodeSpacing
                let isTop = index % 2 == 0
                let style = milestonePalette[index % milestonePalette.count]
                let formattedNumber = String(format: "%02d", index + 1)

                RoadmapMilestoneNode(
                    indexNumber: formattedNumber,
                    event: event,
                    isTop: isTop,
                    centerX: posX,
                    centerY: centerY,
                    accentColor: style.color,
                    iconName: style.icon
                )
            }
        }
        .frame(width: calculatedWidth, height: totalHeight)
    }
}

// MARK: - Milestone Node & Branch
private struct RoadmapMilestoneNode: View {
    let indexNumber: String
    let event: TaskEvent
    let isTop: Bool
    let centerX: CGFloat
    let centerY: CGFloat
    let accentColor: Color
    let iconName: String

    private let circleSize: CGFloat = 54
    private let branchLength: CGFloat = 110
    private let dotSize: CGFloat = 9

    var body: some View {
        let branchEndY = isTop ? (centerY - branchLength) : (centerY + branchLength)

        ZStack(alignment: .topLeading) {
            // Vertical connector line from circle to endpoint dot
            Path { path in
                path.move(to: CGPoint(x: centerX, y: centerY))
                path.addLine(to: CGPoint(x: centerX, y: branchEndY))
            }
            .stroke(
                AppTheme.ink.opacity(0.85),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )

            // Endpoint dot at the end of the vertical line
            Circle()
                .fill(AppTheme.ink)
                .frame(width: dotSize, height: dotSize)
                .position(x: centerX, y: branchEndY)

            // Center circular milestone badge on the main horizontal line
            Circle()
                .fill(accentColor)
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white)
                )
                .shadow(color: accentColor.opacity(0.35), radius: 6, y: 2)
                .position(x: centerX, y: centerY)

            // Callout Card: Number + Date + Note
            calloutContent
                .position(
                    x: centerX + (isTop ? 62 : 62),
                    y: isTop ? (branchEndY - 34) : (branchEndY + 34)
                )
        }
    }

    private var calloutContent: some View {
        HStack(alignment: .top, spacing: 10) {
            // Prominent index number like in reference (01, 02, 03...)
            Text(indexNumber)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            VStack(alignment: .leading, spacing: 4) {
                Text(WorkDateFormatting.formatShortDate(event.date))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryInk)

                Text(event.note)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 170, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .fill(AppTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }
}
