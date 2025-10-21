//
//  WhiteBoardView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 16/08/25.
//

import SwiftUI
internal import OSCKitCore
import simd
import Photos
import UniformTypeIdentifiers
import ImageIO
import Combine

// MARK: - Models & Store

struct StrokeLocal: Identifiable, Equatable {
    var id: UUID
    var width: CGFloat
    var points: [CGPoint]
    var color: Color = .black
}

struct WBColorN: Codable, Equatable {
    var r: Float; var g: Float; var b: Float; var a: Float
}

// Minimal store used by the view. If you already have one, keep yours.

private extension SIMD4<Float> { var points_3d: SIMD3<Float> { .init(x, y, z) } }

// MARK: - WhiteBoardView

struct WhiteBoardView: View {
    @EnvironmentObject private var wbStore: WhiteboardStore
    @Environment(AppModel.self) private var appModel
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @State private var oscSender = OSCManager()

    // Local drawing state
    @State private var localStrokeID: UUID? = nil
    @State private var currentStroke: StrokeLocal?
    @State private var canvasSize: CGSize = .zero

    // World mapping
    @State private var boardWorldTransform: simd_float4x4 = matrix_identity_float4x4
    @State private var boardSizeMeters: CGSize = .init(width: 1.0, height: 0.6)

    // Colors
    @State private var currentColorRGBA: SIMD4<Float> = .init(0,0,0,1)
    @State private var styleCache: [UUID: (width: CGFloat, color: Color)] = [:]

    // Outgoing batching (normalized + world)
    @State private var outgoingBuffer: [WBPointN] = []
    @State private var lastSentCount = 0

    // Incoming buffering when canvas size is unknown
    @State private var pendingNormalized: [UUID: [WBPointN]] = [:]

    // Saving / feedback
    @State private var stagedPNGURL: URL? = nil
    @State private var showFileMover = false
    @State private var showSavedBanner = false
    @State private var savedBannerText = "Saved"
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background image
                Image("SolarIllumination")
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.white.opacity(0.06))
                    .clipped()

                // Drawing canvas
                Canvas { ctx, _ in
                    for s in wbStore.strokes { drawStroke(s, in: &ctx) }
                    for s in wbStore.inProgress.values { drawStroke(s, in: &ctx) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { canvasSize = geo.size }
                            .onChange(of: geo.size) { newSize in
                                let wasZero = (canvasSize == .zero)
                                canvasSize = newSize
                                if wasZero, newSize != .zero {
                                    // Rehydrate any pending normalized points once size is known
                                    for (id, pts) in pendingNormalized {
                                        if var s = wbStore.inProgress[id] {
                                            s.points.append(contentsOf: pts.map(denormalize))
                                            wbStore.inProgress[id] = s
                                        } else if let idx = wbStore.strokes.firstIndex(where: { $0.id == id }) {
                                            var s = wbStore.strokes[idx]
                                            s.points.append(contentsOf: pts.map(denormalize))
                                            wbStore.strokes[idx] = s
                                        } else {
                                            let style = styleCache[id] ?? (wbStore.lineWidth, .black)
                                            wbStore.inProgress[id] = StrokeLocal(
                                                id: id,
                                                width: style.width,
                                                points: pts.map(denormalize),
                                                color: style.color
                                            )
                                        }
                                    }
                                    pendingNormalized.removeAll()

                                    // If we’re sharing, rebroadcast a snapshot once layout is stable
                                    if sharePlayManager.isSharing {
                                        Task { await broadcastSnapshotIfAny() }
                                    }
                                }
                            }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if localStrokeID == nil {
                                let id = UUID()
                                localStrokeID = id
                                let stroke = StrokeLocal(id: id, width: wbStore.lineWidth, points: [], color: wbStore.currentColor)
                                wbStore.inProgress[id] = stroke

                                // cache style so remote can recreate if they miss .begin
                                styleCache[id] = (wbStore.lineWidth, wbStore.currentColor)

                                Task {
                                    await sharePlayManager.sendWhiteBoard(
                                        WBMessage(type: .begin,
                                                  id: id,
                                                  points: nil,
                                                  width: wbStore.lineWidth,
                                                  color: WBColorN(r: currentColorRGBA.x,
                                                                  g: currentColorRGBA.y,
                                                                  b: currentColorRGBA.z,
                                                                  a: currentColorRGBA.w),
                                                  strokesSnapshot: nil)
                                    )
                                }
                                sendWBBegin(id: id, width: wbStore.lineWidth, color: currentColorRGBA)
                                outgoingBuffer.removeAll(keepingCapacity: true)
                                lastSentCount = 0
                            }

                            if let id = localStrokeID {
                                wbStore.inProgress[id]?.points.append(value.location)
                                bufferAndMaybeSend(for: id, point: value.location)
                            }
                        }
                        .onEnded { value in
                            guard let id = localStrokeID, var s = wbStore.inProgress[id] else { return }
                            s.points.append(value.location)
                            wbStore.inProgress[id] = s

                            bufferAndMaybeSend(for: id, point: value.location, forceFlush: true)

                            if let done = wbStore.inProgress.removeValue(forKey: id) {
                                wbStore.strokes.append(done)
                            }
                            localStrokeID = nil

                            Task {
                                await sharePlayManager.sendWhiteBoard(
                                    WBMessage(type: .end, id: id, points: nil, width: nil, strokesSnapshot: nil)
                                )
                            }
                            sendWBEnd(id: s.id)
                        }
                )
            }
            .frame(minHeight: 750)

            // Controls
            HStack(spacing: 12) {
                Button {
                    guard let last = wbStore.strokes.last else { return }
                    wbStore.strokes.removeLast()
                    Task {
                        await sharePlayManager.sendWhiteBoard(
                            WBMessage(type: .remove, id: last.id, points: nil, width: nil, strokesSnapshot: nil)
                        )
                    }
                    sendWBRemove(id: last.id)
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }

                Button(role: .destructive) {
                    wbStore.strokes.removeAll()
                    currentStroke = nil
                    Task {
                        await sharePlayManager.sendWhiteBoard(
                            WBMessage(type: .clear, id: nil, points: nil, width: nil, strokesSnapshot: nil)
                        )
                    }
                    sendWBClear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }

                Spacer()

                HStack(spacing: 12) {
                    ForEach([Color.black, .red, .blue, .green, .white], id: \.self) { c in
                        Circle()
                            .fill(c)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                            .onTapGesture { wbStore.currentColor = c }
                    }
                    Divider().frame(height: 24)
                    ColorPicker("", selection: $wbStore.currentColor, supportsOpacity: true)
                        .labelsHidden()
                }

                HStack(spacing: 8) {
                    Image(systemName: "scribble")
                    Slider(value: $wbStore.lineWidth, in: 2...18)
                        .frame(width: 160)
                }

                Button {
                    saveToPhotosLibrary()
                } label: {
                    Label("Save", systemImage: "photo")
                }

                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            updateRGBA(from: wbStore.currentColor)
        }
        // Ensure UI mutations are on main thread
        .onReceive(sharePlayManager.whiteboardEvents.receive(on: RunLoop.main)) { message in
            applyRemote(message)
        }
        // Broadcast snapshot when sharing begins
        .onChange(of: sharePlayManager.isSharing) { isOn in
            guard isOn else { return }
            Task { await broadcastSnapshotIfAny() }
        }
        .onChange(of: wbStore.currentColor) { updateRGBA(from: $0) }
        .task {
            if sharePlayManager.isSharing {
                await broadcastSnapshotIfAny()
            }
        }
        .fileMover(
            isPresented: $showFileMover,
            file: stagedPNGURL,
            onCompletion: { result in
                switch result {
                case .success(let newURL):
                    showSavedToast("Saved: \(newURL.lastPathComponent)")
                case .failure(let error):
                    fail("Save failed\(error.localizedDescription.isEmpty ? "" : ": \(error.localizedDescription)")")
                }
                if let staged = stagedPNGURL {
                    try? FileManager.default.removeItem(at: staged)
                }
                stagedPNGURL = nil
            }
        )
        .overlay(alignment: .top) {
            if showSavedBanner {
                SaveBanner(text: savedBannerText)
                    .padding(.top, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("Couldn’t Save", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Drawing

    private func drawStroke(_ stroke: StrokeLocal, in ctx: inout GraphicsContext) {
        guard stroke.points.count > 1 else { return }
        var path = Path()
        path.addLines(stroke.points)
        ctx.stroke(
            path,
            with: .color(stroke.color),
            style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Snapshot Rendering

    private func renderCurrentCGImage() -> CGImage? {
        guard canvasSize != .zero else { return nil }
        let content = WhiteboardSnapshotView(
            backgroundName: "SolarIllumination",
            size: canvasSize,
            strokes: wbStore.strokes,
            inProgress: wbStore.inProgress
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        return renderer.cgImage
    }

    private func pngData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private func stagePNGToTemporary() -> URL? {
        guard let cg = renderCurrentCGImage(),
              let data = pngData(from: cg) else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Whiteboard-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to write PNG:", error)
            return nil
        }
    }

    private func saveToPhotosLibrary() {
        guard let cg = renderCurrentCGImage(),
              let png = pngData(from: cg),
              let dataProvider = CGDataProvider(data: png as CFData),
              let _ = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            print("Could not rebuild PNG CGImage for Photos")
            return
        }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                print("Photos access not granted")
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let creation = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = UTType.png.identifier
                creation.addResource(with: .photo, data: png, options: options)
            } completionHandler: { success, err in
                DispatchQueue.main.async {
                    if success {
                        showSavedToast("Saved to Photos")
                    } else {
                        fail("Save to Photos failed\(err.map { ": \($0.localizedDescription)" } ?? "")")
                    }
                }
            }
        }
    }

    // MARK: - Toast / Errors

    private func showSavedToast(_ text: String) {
        savedBannerText = text
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showSavedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.25)) { showSavedBanner = false }
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    // MARK: - Normalize / Denormalize

    private func normalize(_ p: CGPoint) -> WBPointN {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return WBPointN(x: 0, y: 0) }
        return WBPointN(x: p.x / canvasSize.width, y: p.y / canvasSize.height)
    }

    private func denormalize(_ p: WBPointN) -> CGPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return .zero }
        return CGPoint(x: CGFloat(p.x) * canvasSize.width,
                       y: CGFloat(p.y) * canvasSize.height)
    }

    // MARK: - Outgoing share/OSC

    private func bufferAndMaybeSend(for id: UUID, point: CGPoint, forceFlush: Bool = false) {
        outgoingBuffer.append(normalize(point))
        if outgoingBuffer.count - lastSentCount >= 1 || forceFlush {
            let chunk = Array(outgoingBuffer[lastSentCount...])
            lastSentCount = outgoingBuffer.count

            Task {
                await sharePlayManager.sendWhiteBoard(
                    WBMessage(type: .append, id: id, points: chunk, width: wbStore.lineWidth, strokesSnapshot: nil)
                )
            }

            var worldBatch: [SIMD3<Float>] = []
            worldBatch.reserveCapacity(chunk.count)
            for np in chunk {
                let p = CGPoint(x: CGFloat(np.x) * canvasSize.width,
                                y: CGFloat(np.y) * canvasSize.height)
                if let w = worldPoint(from: p) {
                    worldBatch.append(w)
                }
            }
            if !worldBatch.isEmpty {
                sendWBAppendWorld(id: id, worldPoints: worldBatch)
            }
        }
    }

    private func broadcastSnapshotIfAny() async {
        guard !wbStore.strokes.isEmpty else { return }
        let snap: [WBStroke] = wbStore.strokes.map { s in
            let c = UIColor(s.color)
            var r: CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            return WBStroke(
                id: s.id,
                width: s.width,
                points: s.points.map(normalize),
                color: WBColorN(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
            )
        }
        await sharePlayManager.sendWhiteBoard(
            WBMessage(type: .snapshot, id: nil, points: nil, width: nil, strokesSnapshot: snap)
        )
    }

    // MARK: - OSC

    private func oscSend(_ address: String, _ values: [any OSCValue] = []) {
        oscSender.send(
            .message(address, values: values),
            to: appModel.ipAddress,
            port: appModel.portNumber
        )
    }

    private func sendWBBegin(id: UUID, width: CGFloat, color: SIMD4<Float>) {
        oscSend("/wb/begin", [id.uuidString, Float(width), color.x, color.y, color.z, color.w])
    }

    private func sendWBAppendWorld(id: UUID, worldPoints: [SIMD3<Float>]) {
        var args: [any OSCValue] = [id.uuidString]
        for p in worldPoints { args.append(p.x); args.append(p.y); args.append(p.z) }
        oscSend("/wb/append_world", args)
    }

    private func sendWBEnd(id: UUID) { oscSend("/wb/end", [id.uuidString]) }
    private func sendWBClear() { oscSend("/wb/clear") }
    private func sendWBRemove(id: UUID) { oscSend("/wb/remove", [id.uuidString]) }

    // MARK: - Incoming (MAIN ACTOR)

    @MainActor
    private func applyRemote(_ msg: WBMessage) {
        switch msg.type {
        case .begin:
            guard let id = msg.id, let w = msg.width else { return }
            let col: Color = {
                if let c = msg.color {
                    return Color(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: Double(c.a))
                }
                return .black
            }()
            styleCache[id] = (w, col)

            if wbStore.inProgress[id] == nil && !wbStore.strokes.contains(where: { $0.id == id }) {
                wbStore.inProgress[id] = StrokeLocal(id: id, width: w, points: [], color: col)
            }

        case .append:
            guard let id = msg.id, let pts = msg.points else { return }

            // If size unknown, stash and bail
            if canvasSize == .zero {
                pendingNormalized[id, default: []].append(contentsOf: pts)
                return
            }

            if var s = wbStore.inProgress[id] {
                s.points.append(contentsOf: pts.map(denormalize))
                wbStore.inProgress[id] = s
            } else if let idx = wbStore.strokes.firstIndex(where: { $0.id == id }) {
                var s = wbStore.strokes[idx]
                s.points.append(contentsOf: pts.map(denormalize))
                wbStore.strokes[idx] = s
            } else {
                // Late start placeholder
                let style = styleCache[id] ?? (msg.width ?? wbStore.lineWidth,
                                               msg.color.map { Color(.sRGB, red: Double($0.r), green: Double($0.g), blue: Double($0.b), opacity: Double($0.a)) } ?? .black)
                wbStore.inProgress[id] = StrokeLocal(id: id, width: style.0, points: pts.map(denormalize), color: style.1)
            }

        case .end:
            guard let id = msg.id else { return }
            if let done = wbStore.inProgress.removeValue(forKey: id) {
                wbStore.strokes.append(done)
            }

        case .remove:
            guard let id = msg.id else { return }
            if wbStore.inProgress.removeValue(forKey: id) == nil {
                if let idx = wbStore.strokes.firstIndex(where: { $0.id == id }) { wbStore.strokes.remove(at: idx) }
            }

        case .clear:
            wbStore.inProgress.removeAll()
            wbStore.strokes.removeAll()

        case .snapshot:
            guard let remote = msg.strokesSnapshot else { return }

            let isRemoteEmpty = remote.isEmpty
            let isLocallyDrawing = !wbStore.inProgress.isEmpty
            let isLocalEmpty = wbStore.strokes.isEmpty && wbStore.inProgress.isEmpty

            // 1) Never clobber an active draw with a snapshot; defer/ignore.
            if isLocallyDrawing { return }

            // 2) Ignore empty snapshots if our board isn't empty. (Only a `.clear` may wipe us.)
            if isRemoteEmpty && !isLocalEmpty { return }

            // If canvas size isn't ready yet, stash normalized points + styles, but DON'T clear locals
            if canvasSize == .zero {
                // Only proceed to buffer if remote has content; otherwise nothing to do
                guard !isRemoteEmpty else { return }
                for r in remote {
                    pendingNormalized[r.id, default: []].append(contentsOf: r.points)
                    if let c = r.color {
                        styleCache[r.id] = (r.width, Color(.sRGB,
                                                           red: Double(c.r), green: Double(c.g),
                                                           blue: Double(c.b), opacity: Double(c.a)))
                    } else {
                        styleCache[r.id] = (r.width, .black)
                    }
                }
                return
            }

            // Safe to apply snapshot (either both empty, or remote has content)
            wbStore.inProgress.removeAll()
            wbStore.strokes = remote.map { r in
                let col: Color = {
                    if let c = r.color { return Color(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: Double(c.a)) }
                    return .black
                }()
                styleCache[r.id] = (r.width, col)
                return StrokeLocal(id: r.id, width: r.width, points: r.points.map(denormalize), color: col)
            }
        }
    }

    // MARK: - Board mapping

    private func localPointOnBoard(from canvasPoint: CGPoint) -> SIMD3<Float>? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let u = Float(canvasPoint.x / canvasSize.width)   // 0..1
        let v = Float(canvasPoint.y / canvasSize.height)  // 0..1

        let halfW = Float(boardSizeMeters.width)  * 0.5
        let halfH = Float(boardSizeMeters.height) * 0.5

        // Map (u,v) to local meters on the plane (centered, Y up)
        let xLocal = (u - 0.5) * (2 * halfW)
        let yLocal = (0.5 - v) * (2 * halfH) // canvas y grows downward
        return SIMD3<Float>(xLocal, yLocal, 0)
    }

    private func worldPoint(from canvasPoint: CGPoint) -> SIMD3<Float>? {
        guard let local = localPointOnBoard(from: canvasPoint) else { return nil }
        let local4 = SIMD4<Float>(local.x, local.y, local.z, 1)
        let world4 = boardWorldTransform * local4
        return world4.xyz
    }

    private func updateRGBA(from color: Color) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        currentColorRGBA = .init(Float(r), Float(g), Float(b), Float(a))
    }
}
