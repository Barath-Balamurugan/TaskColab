//
//  WhiteBoardView.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 16/08/25.
//

import SwiftUI
internal import OSCKitCore
import simd

struct StrokeLocal: Identifiable, Equatable{
    var id : UUID
    var width: CGFloat
    var points: [CGPoint]
    var color: Color = .black
}

struct WBColorN: Codable, Equatable {
    var r: Float; var g: Float; var b: Float; var a: Float
}

private extension SIMD4<Float> { var points_3d: SIMD3<Float> { .init(x, y, z) } }

/// Minimal local-only whiteboard.
/// Draw with a drag, Clear removes everything.
struct WhiteBoardView: View {
    @Environment(AppModel.self) private var appModel
    @State private var oscSender = OSCManager()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sharePlayManager: SharePlayManager
    
    @State private var strokes: [StrokeLocal] = []
    @State private var inProgress: [UUID: StrokeLocal] = [:]
    @State private var localStrokeID: UUID? = nil
    @State private var outgoingBuffer: [WBPointN] = []
    @State private var lastSentCount = 0
    
    @State private var currentStroke: StrokeLocal?
    @State private var lineWidth: CGFloat = 6
    @State private var canvasSize: CGSize = .zero
    
    @State private var boardWorldTransform: simd_float4x4 = matrix_identity_float4x4
    @State private var boardSizeMeters: CGSize = .init(width: 1.0, height: 0.6)
    
    @State private var currentColor: Color = .black
    @State private var currentColorRGBA: SIMD4<Float> = .init(0,0,0,1)
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background
                Image("SolarIllumination")
                    .resizable()
                    .scaledToFill()                // or .scaledToFit() if you don't want cropping
                    .overlay(Color.white.opacity(0.06)) // subtle wash for stroke contrast
                    .clipped()
                
                // Drawing canvas
                Canvas { ctx, _ in
                    for s in strokes { drawStroke(s, in: &ctx) }
//                    if let s = currentStroke { drawStroke(s, in: &ctx) }
                    for s in inProgress.values { drawStroke(s, in: &ctx)}
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { canvasSize = geo.size }
                            .onChange(of: geo.size) { canvasSize = $0 }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if localStrokeID == nil {
                                let id = UUID()
                                localStrokeID = id
                                inProgress[id] = StrokeLocal(id: id, width: lineWidth, points: [], color: currentColor)
                                // send begin
                                Task {
                                    await sharePlayManager.sendWhiteBoard(
                                        WBMessage(type: .begin,
                                                  id: id,
                                                  points: nil,
                                                  width: lineWidth,
                                                  color: WBColorN(r: currentColorRGBA.x,
                                                                  g: currentColorRGBA.y,
                                                                  b: currentColorRGBA.z,
                                                                  a: currentColorRGBA.w),
                                                  strokesSnapshot: nil)
                                    )
                                }
                                sendWBBegin(id: id, width: lineWidth, color: currentColorRGBA)
                                outgoingBuffer.removeAll(keepingCapacity: true)
                                lastSentCount = 0
                            }
                            
                            if let id = localStrokeID {
                                inProgress[id]?.points.append(value.location)
                                bufferAndMaybeSend(for: id, point: value.location)
//                                print(value.location)
                            }
                        }
                        .onEnded { value in
                            guard let id = localStrokeID, var s = inProgress[id] else { return }
                            s.points.append(value.location)
                            inProgress[id] = s

                            bufferAndMaybeSend(for: id, point: value.location, forceFlush: true)

                            // finalize
                            if let done = inProgress.removeValue(forKey: id) {
                                strokes.append(done)
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
                    guard let last = strokes.last else { return }
                    strokes.removeLast()
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
                    strokes.removeAll()
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
                            .onTapGesture { currentColor = c }
                    }
                    Divider().frame(height: 24)

                    // fine-grained picker
                    ColorPicker("", selection: $currentColor, supportsOpacity: true)
                        .labelsHidden()
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "scribble")
                    Slider(value: $lineWidth, in: 2...18)
                        .frame(width: 160)
                }
                
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear{
            updateRGBA(from: currentColor)
        }
        .onReceive(sharePlayManager.whiteboardEvents) { message in
            applyRemote(message)
        }
        // When SharePlay turns on (or a new participant joins), broadcast our state once
        .onChange(of: sharePlayManager.isSharing) { isOn in
            guard isOn else { return }
            Task { await broadcastSnapshotIfAny() }
        }
        .onChange(of: currentColor){
            updateRGBA(from: $0)
        }
        .task {
            if sharePlayManager.isSharing {
                await broadcastSnapshotIfAny()
            }
        }
    }
    
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
    
    // MARK: - Outgoing
    private func normalize(_ p: CGPoint) -> WBPointN {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return WBPointN(x: 0, y: 0) }
        return WBPointN(x: p.x / canvasSize.width, y: p.y / canvasSize.height)
    }

    private func bufferAndMaybeSend(for id: UUID, point: CGPoint, forceFlush: Bool = false) {
        outgoingBuffer.append(normalize(point))
        if outgoingBuffer.count - lastSentCount >= 1 || forceFlush {
            let chunk = Array(outgoingBuffer[lastSentCount...])
            lastSentCount = outgoingBuffer.count
            Task {
                await sharePlayManager.sendWhiteBoard(
                    WBMessage(type: .append, id: id, points: chunk, width: nil, strokesSnapshot: nil)
                )
            }
//            sendWBAppend(id: id, points: chunk)
            
            var worldBatch: [SIMD3<Float>] = []
            worldBatch.reserveCapacity(chunk.count)
            for np in chunk{
                let p = CGPoint(x: CGFloat(np.x) * canvasSize.width,
                                y: CGFloat(np.y) * canvasSize.height)
                if let w = worldPoint(from: p){
                    worldBatch.append(w)
                }
            }
            if !worldBatch.isEmpty{
                sendWBAppendWorld(id: id, worldPoints: worldBatch)
            }
            
            print(worldBatch)
        }
    }
    
    private func broadcastSnapshotIfAny() async {
        guard !strokes.isEmpty else { return }

        // Convert local strokes to normalized snapshot
        let snap: [WBStroke] = strokes.map { s in
            let c = UIColor(s.color)
            var r: CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0
            c.getRed(&r,green: &g,blue: &b,alpha: &a)
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
        print(color.xyz, color.y, color.z, color.w)
    }
    
    private func sendWBAppendWorld(id: UUID, worldPoints: [SIMD3<Float>]) {
        var args: [any OSCValue] = [id.uuidString]
        // Flatten as [x1, y1, z1, x2, y2, z2, ...]
        for p in worldPoints {
            args.append(p.x)
            args.append(p.y)
            args.append(p.z)
        }
        oscSend("/wb/append_world", args)
    }
    
    private func sendWBEnd(id: UUID) {
        oscSend("/wb/end", [id.uuidString])
    }
    
    private func sendWBClear() {
        oscSend("/wb/clear")
    }
    
    private func sendWBRemove(id: UUID) {
        oscSend("/wb/remove", [id.uuidString])
    }
    
    // MARK: - Incoming
    private func denormalize(_ p: WBPointN) -> CGPoint {
        CGPoint(x: p.x * canvasSize.width, y: p.y * canvasSize.height)
    }

    private func applyRemote(_ msg: WBMessage) {
        switch msg.type {
            case .begin:
                guard let id = msg.id, let w = msg.width else { return }
                if inProgress[id] == nil && !strokes.contains(where: { $0.id == id }) {
                    let col: Color = {
                        if let c = msg.color { return Color(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: Double(c.a)) }
                        return .black
                    }()
                    inProgress[id] = StrokeLocal(id: id, width: w, points: [], color: col)
                }

            case .append:
                guard let id = msg.id, let pts = msg.points else { return }
                if var s = inProgress[id] {
                    s.points.append(contentsOf: pts.map(denormalize))
                    inProgress[id] = s
                } else if let idx = strokes.firstIndex(where: { $0.id == id }) {
                    var s = strokes[idx]
                    s.points.append(contentsOf: pts.map(denormalize))
                    strokes[idx] = s
                } else {
                    // late start: create an in-progress placeholder
                    let col: Color = {
                        if let c = msg.color { return Color(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: Double(c.a)) }
                        return .black
                    }()
                    inProgress[id] = StrokeLocal(id: id, width: msg.width ?? lineWidth, points: pts.map(denormalize), color: col)
                }

            case .end:
                guard let id = msg.id else { return }
                if let done = inProgress.removeValue(forKey: id) {
                    strokes.append(done)
                }

            case .remove:
                guard let id = msg.id else { return }
                if inProgress.removeValue(forKey: id) == nil {
                    if let idx = strokes.firstIndex(where: { $0.id == id }) { strokes.remove(at: idx) }
                }

            case .clear:
                inProgress.removeAll()
                strokes.removeAll()

            case .snapshot:
                guard let remote = msg.strokesSnapshot else { return }
                inProgress.removeAll()
                strokes = remote.map { r in
                    let col: Color = {
                        if let c = r.color { return Color(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: Double(c.a)) }
                        return .black
                    }()
                    return StrokeLocal(id: r.id, width: r.width, points: r.points.map(denormalize), color: col)
                }
        }
    }
    
    private func localPointOnBoard(from canvasPoint: CGPoint) -> SIMD3<Float>? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let u = Float(canvasPoint.x / canvasSize.width)   // 0..1
        let v = Float(canvasPoint.y / canvasSize.height)  // 0..1

        let halfW = Float(boardSizeMeters.width)  * 0.5
        let halfH = Float(boardSizeMeters.height) * 0.5

        // Map (u,v) to local meters on the plane (centered, Y up)
        let xLocal = (u - 0.5) * (2 * halfW)
        let yLocal = (0.5 - v) * (2 * halfH)   // flip because canvas y grows downward
        return SIMD3<Float>(xLocal, yLocal, 0)
    }
    
    private func worldPoint(from canvasPoint: CGPoint) -> SIMD3<Float>? {
        guard let local = localPointOnBoard(from: canvasPoint) else { return nil }
        let local4 = SIMD4<Float>(local.x, local.y, local.z, 1)
        let world4 = boardWorldTransform * local4
        return world4.xyz
    }
    
    private func updateRGBA(from color: Color){
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        currentColorRGBA = .init(Float(r), Float(g), Float(b), Float(a))
    }
}
