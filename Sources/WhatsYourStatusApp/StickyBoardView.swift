import SwiftUI
import WhatsYourStatusCore

struct StickyColorTheme {
    let background: Color
    let text: Color
    let border: Color
    let chip: Color
}

extension StickyColor {
    var theme: StickyColorTheme {
        switch self {
        case .yellow:
            return StickyColorTheme(
                background: Color(red: 1.0, green: 0.94, blue: 0.40),
                text: Color(red: 0.20, green: 0.17, blue: 0.02),
                border: Color(red: 0.90, green: 0.83, blue: 0.28),
                chip: Color(red: 0.98, green: 0.88, blue: 0.20)
            )
        case .blue:
            return StickyColorTheme(
                background: Color(red: 0.62, green: 0.88, blue: 0.99),
                text: Color(red: 0.05, green: 0.22, blue: 0.35),
                border: Color(red: 0.48, green: 0.79, blue: 0.94),
                chip: Color(red: 0.40, green: 0.75, blue: 0.95)
            )
        case .purple:
            return StickyColorTheme(
                background: Color(red: 0.82, green: 0.73, blue: 1.0),
                text: Color(red: 0.18, green: 0.08, blue: 0.38),
                border: Color(red: 0.73, green: 0.60, blue: 0.96),
                chip: Color(red: 0.72, green: 0.58, blue: 0.98)
            )
        case .pink:
            return StickyColorTheme(
                background: Color(red: 1.0, green: 0.77, blue: 0.88),
                text: Color(red: 0.38, green: 0.06, blue: 0.21),
                border: Color(red: 0.93, green: 0.64, blue: 0.78),
                chip: Color(red: 0.98, green: 0.60, blue: 0.78)
            )
        case .orange:
            return StickyColorTheme(
                background: Color(red: 1.0, green: 0.82, blue: 0.64),
                text: Color(red: 0.38, green: 0.18, blue: 0.02),
                border: Color(red: 0.93, green: 0.67, blue: 0.44),
                chip: Color(red: 0.98, green: 0.65, blue: 0.35)
            )
        case .green:
            return StickyColorTheme(
                background: Color(red: 0.82, green: 0.97, blue: 0.67),
                text: Color(red: 0.12, green: 0.30, blue: 0.02),
                border: Color(red: 0.69, green: 0.90, blue: 0.49),
                chip: Color(red: 0.65, green: 0.88, blue: 0.45)
            )
        case .gray:
            return StickyColorTheme(
                background: Color(red: 0.91, green: 0.93, blue: 0.95),
                text: Color(red: 0.15, green: 0.20, blue: 0.25),
                border: Color(red: 0.80, green: 0.83, blue: 0.87),
                chip: Color(red: 0.78, green: 0.81, blue: 0.85)
            )
        }
    }
}

enum BoardToolMode {
    case select
    case pan
}

struct StickyBoardView: View {
    let viewModel: WorkQueueViewModel

    @State private var panOffset: CGSize = CGSize(width: 80, height: 40)
    @State private var dragStartPan: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    @State private var currentTool: BoardToolMode = .select
    @State private var selectedNoteId: String? = nil
    @State private var selectedLineId: String? = nil
    @State private var isShowingStickyColorPicker: Bool = false
    @State private var isShowingLinePicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            topNavBar
            Divider().overlay(AppTheme.line)

            ZStack {
                // Interactive canvas
                canvasBackground
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if currentTool == .pan {
                                    panOffset = CGSize(
                                        width: dragStartPan.width + value.translation.width,
                                        height: dragStartPan.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                if currentTool == .pan {
                                    dragStartPan = panOffset
                                }
                            }
                    )

                // Connector lines layer
                boardLinesLayer

                // Sticky notes layer
                stickyNotesLayer

                // Floating Left Toolbar (Miro style)
                VStack {
                    Spacer().frame(height: 24)
                    HStack {
                        leftToolbar
                            .padding(.leading, 20)
                        Spacer()
                    }
                    Spacer()
                }

                // Floating Bottom Right Zoom Controls (Miro style)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        bottomZoomBar
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
            }
            .clipped()
        }
        .background(AppTheme.canvas)
        .onAppear {
            dragStartPan = panOffset
        }
    }

    // MARK: - Top Navigation Bar
    private var topNavBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.square")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.blue)

                Text("Sticky Board")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text("Miro Style")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.blueInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppTheme.blueSoft))
            }

            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 10))
                Text(viewModel.currentWorkspaceName)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(AppTheme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppTheme.surfaceMuted))

            Spacer()

            Text("\(viewModel.currentStickyNotes.count) catatan • \(viewModel.currentBoardLines.count) garis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.muted)

            Button {
                viewModel.addStickyNote(color: .yellow, noteType: .sticky)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Catatan Baru")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.paper)
    }

    // MARK: - Canvas Background with Dot Matrix
    private var canvasBackground: some View {
        Canvas { context, size in
            let dotSpacing: CGFloat = 28 * zoomScale
            guard dotSpacing > 6 else { return }

            let startX = (panOffset.width).truncatingRemainder(dividingBy: dotSpacing)
            let startY = (panOffset.height).truncatingRemainder(dividingBy: dotSpacing)

            var x = startX - dotSpacing
            while x < size.width + dotSpacing {
                var y = startY - dotSpacing
                while y < size.height + dotSpacing {
                    let dotRect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                    context.fill(Path(ellipseIn: dotRect), with: .color(AppTheme.ink.opacity(0.14)))
                    y += dotSpacing
                }
                x += dotSpacing
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedNoteId = nil
            selectedLineId = nil
        }
    }

    // MARK: - Sticky Notes Layer
    private var stickyNotesLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(viewModel.currentStickyNotes) { note in
                StickyNoteItemView(
                    note: note,
                    zoomScale: zoomScale,
                    isSelected: selectedNoteId == note.id,
                    onSelect: {
                        selectedNoteId = note.id
                        selectedLineId = nil
                    },
                    onUpdate: { updated in
                        viewModel.updateStickyNote(updated)
                    },
                    onDelete: {
                        viewModel.deleteStickyNote(note)
                    },
                    onDuplicate: {
                        viewModel.duplicateStickyNote(note)
                    },
                    onConvertToTask: {
                        viewModel.convertStickyNoteToTask(note)
                    }
                )
                .offset(
                    x: CGFloat(note.x) * zoomScale + panOffset.width,
                    y: CGFloat(note.y) * zoomScale + panOffset.height
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Left Floating Toolbar (Miro Signature)
    private var leftToolbar: some View {
        VStack(spacing: 6) {
            toolbarIconButton(
                icon: "arrow.up.left",
                title: "Pilih & Geser",
                isActive: currentTool == .select
            ) {
                currentTool = .select
            }

            toolbarIconButton(
                icon: "hand.raised",
                title: "Geser Kanvas (Pan)",
                isActive: currentTool == .pan
            ) {
                currentTool = .pan
            }

            Divider().frame(width: 24).overlay(AppTheme.line)

            // Add sticky note with clean popover (no down arrow)
            toolbarIconButton(
                icon: "note.text",
                title: "Tambah Sticky Note",
                isActive: isShowingStickyColorPicker
            ) {
                isShowingStickyColorPicker.toggle()
            }
            .popover(isPresented: $isShowingStickyColorPicker, arrowEdge: .trailing) {
                stickyColorPickerPopover
            }

            // Add line or line with arrow tip
            toolbarIconButton(
                icon: "arrow.right",
                title: "Tambah Garis / Panah",
                isActive: isShowingLinePicker
            ) {
                isShowingLinePicker.toggle()
            }
            .popover(isPresented: $isShowingLinePicker, arrowEdge: .trailing) {
                linePickerPopover
            }

            toolbarIconButton(
                icon: "character.textbox",
                title: "Tambah Judul / Teks Bebas",
                isActive: false
            ) {
                viewModel.addStickyNote(
                    content: "",
                    color: .yellow,
                    noteType: .text
                )
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.paper)
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private func toolbarIconButton(
        icon: String,
        title: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: isActive ? .bold : .regular))
                .foregroundStyle(isActive ? AppTheme.blue : AppTheme.secondaryInk)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? AppTheme.blueSoft : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(title)
    }

    // MARK: - Bottom Right Zoom Controls
    private var bottomZoomBar: some View {
        HStack(spacing: 4) {
            Button {
                zoomScale = max(0.4, zoomScale - 0.15)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Perkecil (Zoom Out)")

            Button {
                zoomScale = 1.0
                panOffset = CGSize(width: 80, height: 40)
                dragStartPan = panOffset
            } label: {
                Text("\(Int(zoomScale * 100))%")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .frame(width: 48, height: 28)
            }
            .buttonStyle(.plain)
            .help("Reset Zoom ke 100%")

            Button {
                zoomScale = min(2.2, zoomScale + 0.15)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Perbesar (Zoom In)")

            Divider().frame(height: 18).overlay(AppTheme.line)

            Button {
                panOffset = CGSize(width: 80, height: 40)
                dragStartPan = panOffset
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Tengahkan Kanvas")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.paper)
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    // MARK: - Board Connector Lines Layer
    private var boardLinesLayer: some View {
        ZStack {
            ForEach(viewModel.currentBoardLines) { line in
                BoardLineItemView(
                    line: line,
                    zoomScale: zoomScale,
                    panOffset: panOffset,
                    isSelected: selectedLineId == line.id,
                    onSelect: {
                        selectedLineId = line.id
                        selectedNoteId = nil
                    },
                    onUpdate: { updated in
                        viewModel.updateBoardLine(updated)
                    },
                    onDelete: {
                        if selectedLineId == line.id {
                            selectedLineId = nil
                        }
                        viewModel.deleteBoardLine(line)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Popovers for Left Toolbar
    private var stickyColorPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PILIH WARNA STICKY NOTE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.muted)

            LazyVGrid(columns: [GridItem(.fixed(34)), GridItem(.fixed(34)), GridItem(.fixed(34)), GridItem(.fixed(34))], spacing: 8) {
                ForEach(StickyColor.allCases) { color in
                    Button {
                        viewModel.addStickyNote(color: color, noteType: .sticky)
                        isShowingStickyColorPicker = false
                    } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color.theme.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(color.theme.border, lineWidth: 1.5)
                            )
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .help(color.label)
                }
            }
        }
        .padding(12)
        .background(AppTheme.paper)
    }

    private var linePickerPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TAMBAH GARIS / PANAH")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.muted)
                .padding(.horizontal, 4)

            Button {
                viewModel.addBoardLine(style: .arrow, isCurved: true)
                isShowingLinePicker = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.blueSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Panah Lengkung (Bebas)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Bisa ditarik dan dilengkungkan bebas")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.addBoardLine(style: .arrow, isCurved: false)
                isShowingLinePicker = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Panah Lurus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Hubungkan alur lurus langsung")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.addBoardLine(style: .plain, isCurved: true)
                isShowingLinePicker = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "scribble")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Garis Lengkung (Bebas)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Garis kurva meliuk tanpa ujung panah")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.addBoardLine(style: .plain, isCurved: false)
                isShowingLinePicker = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Garis Lurus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Garis pembatas atau relasi sederhana")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.addBoardLine(style: .doubleArrow, isCurved: true)
                isShowingLinePicker = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Panah Dua Arah (Lengkung)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Relasi timbal balik melengkung")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 260)
        .background(AppTheme.paper)
    }
}

// MARK: - Sticky Note Item View
struct StickyNoteItemView: View {
    let note: StickyNote
    let zoomScale: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onUpdate: (StickyNote) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onConvertToTask: () -> Void

    @State private var dragPosition: CGSize = .zero
    @State private var liveContent: String = ""
    @State private var isHovered: Bool = false
    @State private var isEditingAuthor: Bool = false
    @State private var customAuthor: String = ""

    var body: some View {
        if note.noteType == .text {
            freeformTextView
        } else {
            stickyCardView
        }
    }

    // MARK: - Sticky Card (Miro Benchmark Look)
    private var stickyCardView: some View {
        let theme = note.color.theme

        return VStack(alignment: .leading, spacing: 0) {
            cardHeaderView(theme: theme)
            cardContentView(theme: theme)
            if isHovered || isSelected {
                cardQuickActionsView(theme: theme)
            }
        }
        .frame(width: CGFloat(note.width), height: CGFloat(note.height))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.background)
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.22 : 0.12),
                    radius: isSelected ? 12 : 6,
                    x: 0,
                    y: isSelected ? 6 : 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? AppTheme.blue : theme.border, lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(zoomScale)
        .offset(dragPosition)
        .onHover { h in
            isHovered = h
        }
        .onTapGesture {
            onSelect()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragPosition = value.translation
                }
                .onEnded { value in
                    var updated = note
                    updated.x += Double(value.translation.width / zoomScale)
                    updated.y += Double(value.translation.height / zoomScale)
                    dragPosition = .zero
                    onUpdate(updated)
                }
        )
        .onAppear {
            liveContent = note.content
        }
        .onChange(of: note.content) { _, newContent in
            if liveContent != newContent {
                liveContent = newContent
            }
        }
    }

    private func cardHeaderView(theme: StickyColorTheme) -> some View {
        let displayAuthor: String = note.author.isEmpty ? "Saya" : note.author

        return HStack(spacing: 6) {
            Menu {
                Section("PENULIS CATATAN") {
                    Button("Saya") {
                        var u = note
                        u.author = "Saya"
                        onUpdate(u)
                    }
                    Button("Allison") {
                        var u = note
                        u.author = "Allison"
                        onUpdate(u)
                    }
                    Button("Alexander") {
                        var u = note
                        u.author = "Alexander"
                        onUpdate(u)
                    }
                    Button("Tobias") {
                        var u = note
                        u.author = "Tobias"
                        onUpdate(u)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 8))
                    Text(displayAuthor)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(theme.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.7)))
            }
            .menuStyle(.borderlessButton)

            Spacer()

            Menu {
                Section("UBAH WARNA") {
                    ForEach(StickyColor.allCases) { c in
                        Button {
                            var updated = note
                            updated.color = c
                            onUpdate(updated)
                        } label: {
                            HStack {
                                Circle().fill(c.theme.chip).frame(width: 10, height: 10)
                                Text(c.label)
                            }
                        }
                    }
                }
                Divider()
                Button("Gandakan (Duplicate)") {
                    onDuplicate()
                }
                Button("Jadikan Task Status...") {
                    onConvertToTask()
                }
                Divider()
                Button("Hapus Catatan", role: .destructive) {
                    onDelete()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.text.opacity(0.6))
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func cardContentView(theme: StickyColorTheme) -> some View {
        TextEditor(text: Binding(
            get: { liveContent },
            set: { val in
                liveContent = val
                var updated = note
                updated.content = val
                onUpdate(updated)
            }
        ))
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(theme.text)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .overlay(alignment: .topLeading) {
            if liveContent.isEmpty {
                Text("Tulis ide atau catatan di sini...")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.opacity(0.45))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private func cardQuickActionsView(theme: StickyColorTheme) -> some View {
        HStack(spacing: 6) {
            Button {
                onConvertToTask()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 9))
                    Text("Jadikan Task")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(theme.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.85))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Konversi catatan tempel ini menjadi Task Status di antrean")

            Spacer()

            Button {
                onDuplicate()
            } label: {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text.opacity(0.75))
            }
            .buttonStyle(.plain)
            .help("Gandakan")

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Hapus")
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Freeform Text View (For Titles & Big Prompts like Miro)
    private var freeformTextView: some View {
        VStack(alignment: .center, spacing: 4) {
            // Floating Action Pill when hovered or selected
            if isHovered || isSelected {
                HStack(spacing: 6) {
                    // Drag Handle: user can drag from this handle without interfering with text selection
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 8, weight: .bold))
                        Text("Geser")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.secondaryInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.paper))
                    .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragPosition = value.translation
                            }
                            .onEnded { value in
                                var updated = note
                                updated.x += Double(value.translation.width / zoomScale)
                                updated.y += Double(value.translation.height / zoomScale)
                                dragPosition = .zero
                                onUpdate(updated)
                            }
                    )
                    .help("Tahan & geser untuk memindahkan teks")

                    Spacer()

                    // Clear text button (Solves "cannot clear text" immediately)
                    if !liveContent.isEmpty {
                        Button {
                            liveContent = ""
                            var updated = note
                            updated.content = ""
                            onUpdate(updated)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 9))
                                Text("Kosongkan")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.secondaryInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppTheme.paper))
                            .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Bersihkan / Kosongkan teks")
                    }

                    // Delete Note button
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.red)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(AppTheme.paper))
                            .overlay(Circle().stroke(AppTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Hapus teks ini")
                }
                .frame(width: max(CGFloat(note.width), 220))
            }

            // Text Field Container
            ZStack(alignment: .trailing) {
                ZStack(alignment: .center) {
                    if liveContent.isEmpty {
                        Text("Ketik judul / pertanyaan...")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.muted.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: Binding(
                        get: { liveContent },
                        set: { val in
                            liveContent = val
                            var updated = note
                            updated.content = val
                            onUpdate(updated)
                        }
                    ), axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
                .frame(width: max(CGFloat(note.width), 220))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AppTheme.paper.opacity(0.95) : (isHovered ? AppTheme.paper.opacity(0.55) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? AppTheme.blue : (isHovered ? AppTheme.line : Color.clear), lineWidth: 1.5)
                )

                // Inline quick clear button on the right edge
                if !liveContent.isEmpty && isSelected {
                    Button {
                        liveContent = ""
                        var updated = note
                        updated.content = ""
                        onUpdate(updated)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                    .help("Kosongkan teks")
                }
            }

        }
        .scaleEffect(zoomScale)
        .offset(dragPosition)
        .onHover { h in isHovered = h }
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            liveContent = note.content
        }
        .onChange(of: note.content) { _, newContent in
            if liveContent != newContent {
                liveContent = newContent
            }
        }
    }
}

// MARK: - Board Line Item View (Miro Style)
struct BoardLineItemView: View {
    let line: BoardLine
    let zoomScale: CGFloat
    let panOffset: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let onUpdate: (BoardLine) -> Void
    let onDelete: () -> Void

    @State private var dragLineOffset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero
    @State private var dragEndOffset: CGSize = .zero
    @State private var dragControlOffset: CGSize = .zero
    @State private var isHovered: Bool = false
    @State private var isEditingLabel: Bool = false
    @State private var liveLabel: String = ""

    private var currentStartX: Double {
        line.startX + Double(dragLineOffset.width + dragStartOffset.width) / Double(zoomScale)
    }

    private var currentStartY: Double {
        line.startY + Double(dragLineOffset.height + dragStartOffset.height) / Double(zoomScale)
    }

    private var currentEndX: Double {
        line.endX + Double(dragLineOffset.width + dragEndOffset.width) / Double(zoomScale)
    }

    private var currentEndY: Double {
        line.endY + Double(dragLineOffset.height + dragEndOffset.height) / Double(zoomScale)
    }

    // Default curve control point if not set
    private var defaultControlX: Double {
        let mx = (currentStartX + currentEndX) / 2
        let dy = currentEndY - currentStartY
        return mx - dy * 0.25
    }

    private var defaultControlY: Double {
        let my = (currentStartY + currentEndY) / 2
        let dx = currentEndX - currentStartX
        return my + dx * 0.25
    }

    private var currentControlX: Double {
        let base = line.controlX ?? defaultControlX
        return base + Double(dragLineOffset.width + dragControlOffset.width) / Double(zoomScale)
    }

    private var currentControlY: Double {
        let base = line.controlY ?? defaultControlY
        return base + Double(dragLineOffset.height + dragControlOffset.height) / Double(zoomScale)
    }

    private var p1: CGPoint {
        CGPoint(
            x: CGFloat(currentStartX) * zoomScale + panOffset.width,
            y: CGFloat(currentStartY) * zoomScale + panOffset.height
        )
    }

    private var p2: CGPoint {
        CGPoint(
            x: CGFloat(currentEndX) * zoomScale + panOffset.width,
            y: CGFloat(currentEndY) * zoomScale + panOffset.height
        )
    }

    private var pControl: CGPoint {
        CGPoint(
            x: CGFloat(currentControlX) * zoomScale + panOffset.width,
            y: CGFloat(currentControlY) * zoomScale + panOffset.height
        )
    }

    private var midPoint: CGPoint {
        if line.isCurved {
            // Apex of quadratic Bezier curve at t = 0.5
            let mx = 0.25 * p1.x + 0.5 * pControl.x + 0.25 * p2.x
            let my = 0.25 * p1.y + 0.5 * pControl.y + 0.25 * p2.y
            return CGPoint(x: mx, y: my)
        } else {
            return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        }
    }

    private var endArrowAngle: CGFloat {
        if line.isCurved {
            return atan2(p2.y - pControl.y, p2.x - pControl.x)
        } else {
            return atan2(p2.y - p1.y, p2.x - p1.x)
        }
    }

    private var startArrowAngle: CGFloat {
        if line.isCurved {
            return atan2(p1.y - pControl.y, p1.x - pControl.x)
        } else {
            return atan2(p1.y - p2.y, p1.x - p2.x)
        }
    }

    private var lineColor: Color {
        Color(hex: line.color)
    }

    private func lineCurvePath() -> Path {
        var path = Path()
        path.move(to: p1)
        if line.isCurved {
            path.addQuadCurve(to: p2, control: pControl)
        } else {
            path.addLine(to: p2)
        }
        return path
    }

    var body: some View {
        ZStack {
            // Invisible wider hit-test area
            lineCurvePath()
                .stroke(Color.white.opacity(0.001), lineWidth: 24 * zoomScale)
                .contentShape(
                    lineCurvePath().strokedPath(StrokeStyle(lineWidth: 24 * zoomScale, lineCap: .round))
                )
                .onHover { h in isHovered = h }
                .onTapGesture {
                    onSelect()
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onSelect()
                            dragLineOffset = value.translation
                        }
                        .onEnded { value in
                            let dx = Double(value.translation.width) / Double(zoomScale)
                            let dy = Double(value.translation.height) / Double(zoomScale)
                            var updated = line
                            updated.startX += dx
                            updated.startY += dy
                            updated.endX += dx
                            updated.endY += dy
                            if let cx = updated.controlX, let cy = updated.controlY {
                                updated.controlX = cx + dx
                                updated.controlY = cy + dy
                            }
                            dragLineOffset = .zero
                            onUpdate(updated)
                        }
                )

            // Visible line (curved or straight)
            lineCurvePath()
                .stroke(
                    lineColor,
                    style: StrokeStyle(
                        lineWidth: (isSelected ? 3.0 : 2.5) * max(0.8, min(1.4, zoomScale)),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            // Arrow head at P2 (end of line)
            if line.style == .arrow || line.style == .doubleArrow {
                arrowHeadPath(at: p2, angle: endArrowAngle)
                    .fill(lineColor)
            }

            // Arrow head at P1 (start of line for double arrow)
            if line.style == .doubleArrow {
                arrowHeadPath(at: p1, angle: startArrowAngle)
                    .fill(lineColor)
            }

            // Label badge on midpoint of curve
            if !line.label.isEmpty || isEditingLabel {
                lineLabelView
                    .position(x: midPoint.x, y: midPoint.y)
            }

            // Interactive Endpoint Handles, Curve Bend Handle & Floating Controls (when selected)
            if isSelected {
                // If curved, draw faint dashed guide line to control point
                if line.isCurved {
                    Path { p in
                        p.move(to: p1)
                        p.addLine(to: pControl)
                        p.addLine(to: p2)
                    }
                    .stroke(lineColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Draggable curve bend handle
                    curveHandleView
                        .position(pControl)
                }

                startHandleView
                    .position(p1)

                endHandleView
                    .position(p2)

                floatingControlsView
                    .position(x: midPoint.x, y: max(32, midPoint.y - 36))
            }
        }
        .onAppear {
            liveLabel = line.label
        }
    }

    private func arrowHeadPath(at tip: CGPoint, angle: CGFloat) -> Path {
        var path = Path()
        let length: CGFloat = 13 * max(0.8, min(1.4, zoomScale))
        let spread: CGFloat = .pi / 6

        let pA = CGPoint(
            x: tip.x - length * cos(angle - spread),
            y: tip.y - length * sin(angle - spread)
        )
        let pB = CGPoint(
            x: tip.x - length * cos(angle + spread),
            y: tip.y - length * sin(angle + spread)
        )

        path.move(to: tip)
        path.addLine(to: pA)
        path.addLine(to: pB)
        path.closeSubpath()
        return path
    }

    private var curveHandleView: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(AppTheme.blue, lineWidth: 2.5))
            .overlay(
                Circle()
                    .fill(AppTheme.blue)
                    .frame(width: 6, height: 6)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 3)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragControlOffset = value.translation
                    }
                    .onEnded { value in
                        let dx = Double(value.translation.width) / Double(zoomScale)
                        let dy = Double(value.translation.height) / Double(zoomScale)
                        var updated = line
                        updated.isCurved = true
                        let base = line.controlX ?? defaultControlX
                        let basey = line.controlY ?? defaultControlY
                        updated.controlX = base + dx
                        updated.controlY = basey + dy
                        dragControlOffset = .zero
                        onUpdate(updated)
                    }
            )
            .help("Tarik titik ini untuk melengkungkan garis secara bebas (Curve freely)")
    }

    private var startHandleView: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(lineColor, lineWidth: 2.5))
            .shadow(color: Color.black.opacity(0.18), radius: 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragStartOffset = value.translation
                    }
                    .onEnded { value in
                        let dx = Double(value.translation.width) / Double(zoomScale)
                        let dy = Double(value.translation.height) / Double(zoomScale)
                        var updated = line
                        updated.startX += dx
                        updated.startY += dy
                        dragStartOffset = .zero
                        onUpdate(updated)
                    }
            )
            .help("Geser titik awal garis")
    }

    private var endHandleView: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(lineColor, lineWidth: 2.5))
            .shadow(color: Color.black.opacity(0.18), radius: 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragEndOffset = value.translation
                    }
                    .onEnded { value in
                        let dx = Double(value.translation.width) / Double(zoomScale)
                        let dy = Double(value.translation.height) / Double(zoomScale)
                        var updated = line
                        updated.endX += dx
                        updated.endY += dy
                        dragEndOffset = .zero
                        onUpdate(updated)
                    }
            )
            .help("Geser titik ujung garis")
    }

    private var lineLabelView: some View {
        Group {
            if isEditingLabel {
                HStack(spacing: 4) {
                    TextField("Label garis...", text: $liveLabel)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                        .frame(minWidth: 70, maxWidth: 140)
                        .onSubmit {
                            var updated = line
                            updated.label = liveLabel.trimmingCharacters(in: .whitespaces)
                            onUpdate(updated)
                            isEditingLabel = false
                        }
                    Button {
                        var updated = line
                        updated.label = liveLabel.trimmingCharacters(in: .whitespaces)
                        onUpdate(updated)
                        isEditingLabel = false
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppTheme.paper)
                        .shadow(color: Color.black.opacity(0.15), radius: 4)
                )
            } else {
                Text(line.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(lineColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.paper)
                            .shadow(color: Color.black.opacity(0.12), radius: 3)
                    )
                    .overlay(
                        Capsule()
                            .stroke(lineColor.opacity(0.35), lineWidth: 1)
                    )
                    .onTapGesture {
                        liveLabel = line.label
                        isEditingLabel = true
                    }
            }
        }
    }

    private var floatingControlsView: some View {
        HStack(spacing: 6) {
            // Curve vs Straight switcher
            HStack(spacing: 2) {
                Button {
                    var updated = line
                    updated.isCurved = false
                    onUpdate(updated)
                } label: {
                    Image(systemName: "line.diagonal")
                        .font(.system(size: 10, weight: !line.isCurved ? .bold : .regular))
                        .foregroundStyle(!line.isCurved ? AppTheme.blue : AppTheme.secondaryInk)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(!line.isCurved ? AppTheme.blueSoft : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Garis Lurus")

                Button {
                    var updated = line
                    updated.isCurved = true
                    if updated.controlX == nil {
                        updated.controlX = defaultControlX
                        updated.controlY = defaultControlY
                    }
                    onUpdate(updated)
                } label: {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 10, weight: line.isCurved ? .bold : .regular))
                        .foregroundStyle(line.isCurved ? AppTheme.blue : AppTheme.secondaryInk)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(line.isCurved ? AppTheme.blueSoft : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Lengkungkan Garis Bebas (Curve freely)")
            }

            Divider().frame(height: 14).overlay(AppTheme.line)

            // Style switcher (Arrowhead caps)
            HStack(spacing: 2) {
                styleButton(style: .plain, icon: "minus", help: "Tanpa Panah")
                styleButton(style: .arrow, icon: "arrow.right", help: "Panah Satu Arah")
                styleButton(style: .doubleArrow, icon: "arrow.left.and.right", help: "Panah Dua Arah")
            }

            Divider().frame(height: 14).overlay(AppTheme.line)

            // Color dots
            HStack(spacing: 4) {
                ForEach(["#475569", "#3B82F6", "#8B5CF6", "#10B981", "#F59E0B", "#EF4444"], id: \.self) { hex in
                    Button {
                        var updated = line
                        updated.color = hex
                        onUpdate(updated)
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: line.color.uppercased() == hex.uppercased() ? 2 : 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 14).overlay(AppTheme.line)

            // Add/Edit Label button
            Button {
                liveLabel = line.label
                isEditingLabel.toggle()
            } label: {
                Image(systemName: "character.textbox")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Tambah / Ubah Label Garis")

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Hapus Garis")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AppTheme.paper)
                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 2)
        )
        .overlay(
            Capsule()
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private func styleButton(style: LineCapStyle, icon: String, help: String) -> some View {
        Button {
            var updated = line
            updated.style = style
            onUpdate(updated)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: line.style == style ? .bold : .regular))
                .foregroundStyle(line.style == style ? AppTheme.blue : AppTheme.secondaryInk)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(line.style == style ? AppTheme.blueSoft : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 71, 85, 105)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
