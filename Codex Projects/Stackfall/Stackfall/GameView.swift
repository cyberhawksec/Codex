import SwiftUI

private let ink = Color(red: 0.89, green: 0.94, blue: 0.97)
private let muted = Color(red: 0.53, green: 0.63, blue: 0.70)
private let aqua = Color(red: 0.42, green: 0.91, blue: 0.83)

struct GameView: View {
    @StateObject private var game = GameModel()
    @StateObject private var gameCenter = GameCenterManager.shared
    @Environment(\.scenePhase) private var scenePhase
    private let clock = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let boardWidth = max(120, min(geometry.size.width - 40, (geometry.size.height - 240) / 2))
            ZStack {
                LinearGradient(colors: [Color(red: 0.07, green: 0.13, blue: 0.18), Color(red: 0.025, green: 0.055, blue: 0.085)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    HStack(alignment: .center, spacing: 8) {
                        stat("SCORE", value: String(game.score))
                        stat("BEST", value: String(game.best))
                        stat("LEVEL", value: "\(game.level)/10")
                        Spacer(minLength: 0)
                        nextPiece
                    }
                    .padding(.top, 12)
                    Spacer(minLength: 8)
                    BoardView(game: game)
                        .frame(width: boardWidth, height: boardWidth * 2)
                        .overlay { overlay }
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 20).onEnded { value in
                            guard game.phase == .playing else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            if abs(dx) > abs(dy) { game.move(dx > 0 ? 1 : -1) }
                            else if dy > 0 { game.hardDrop() }
                        })
                        .simultaneousGesture(TapGesture().onEnded { game.rotate() })
                        .accessibilityLabel("Game board")
                        .accessibilityValue("Score \(game.score), level \(game.level), \(game.lines) lines")
                    Spacer(minLength: 8)
                    controls
                    Text("TAP TO ROTATE  ·  SWIPE DOWN TO DROP")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(muted)
                        .padding(.top, 9)
                        .padding(.bottom, 4)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { gameCenter.start() }
        .sheet(item: $gameCenter.presentation) { item in
            GameCenterController(controller: item.controller)
                .ignoresSafeArea()
        }
        .onChange(of: gameCenter.presentation?.id) { id in
            if id != nil { game.pause() }
        }
        .alert("Game Center", isPresented: Binding(
            get: { gameCenter.alertMessage != nil },
            set: { if !$0 { gameCenter.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { gameCenter.alertMessage = nil }
        } message: {
            Text(gameCenter.alertMessage ?? "")
        }
        .onReceive(clock) { game.update(now: $0) }
        .onChange(of: scenePhase) { phase in
            if phase != .active { game.pause() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill").font(.system(size: 12))
                    Text("STACKFALL").font(.system(size: 17, weight: .black, design: .rounded)).tracking(2)
                }.foregroundStyle(ink)
                Text("FRESH FRUIT. FAST FALLS.")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.5).foregroundStyle(muted)
            }
            Spacer()
            Button {
                game.pause()
                gameCenter.showLeaderboard()
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
            .foregroundStyle(aqua)
            .accessibilityLabel("Game Center leaderboard")
            Button(action: game.togglePause) {
                Image(systemName: game.phase == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
            .foregroundStyle(ink)
            .disabled(game.phase != .playing && game.phase != .paused)
            .opacity(game.phase == .playing || game.phase == .paused ? 1 : 0.4)
            .accessibilityLabel(game.phase == .paused ? "Resume" : "Pause")
        }
        .padding(.top, 5)
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.1).foregroundStyle(muted)
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nextPiece: some View {
        HStack(spacing: 7) {
            Text("NEXT").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(muted)
            Canvas { context, size in
                let atlas = context.resolve(Image("FruitAtlas"))
                let cells = game.next.cells
                let minX = cells.map(\.x).min() ?? 0
                let maxX = cells.map(\.x).max() ?? 0
                let minY = cells.map(\.y).min() ?? 0
                let maxY = cells.map(\.y).max() ?? 0
                let unit: CGFloat = 7
                let originX = (size.width - CGFloat(maxX - minX + 1) * unit) / 2
                let originY = (size.height - CGFloat(maxY - minY + 1) * unit) / 2
                for cell in cells {
                    let center = CGPoint(x: originX + (CGFloat(cell.x - minX) + 0.5) * unit, y: originY + (CGFloat(cell.y - minY) + 0.5) * unit)
                    drawFruit(context: context, atlas: atlas, rect: CGRect(x: center.x - unit / 2, y: center.y - unit / 2, width: unit, height: unit), block: game.next)
                }
            }.frame(width: 31, height: 28)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next fruit: \(game.next.fruitName)")
    }

    @ViewBuilder private var overlay: some View {
        if game.phase != .playing {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.02, green: 0.05, blue: 0.08).opacity(0.86))
                VStack(spacing: 12) {
                    Image(systemName: game.phase == .won ? "trophy.fill" : game.phase == .over ? "sparkles" : "square.stack.3d.up.fill")
                        .font(.system(size: 26)).foregroundStyle(aqua)
                    Text(game.phase == .ready ? "READY TO STACK?" : game.phase == .paused ? "PAUSED" : game.phase == .won ? "YOU WIN!" : "GAME OVER")
                        .font(.system(size: 19, weight: .black, design: .rounded)).tracking(1).foregroundStyle(ink)
                    Text(game.phase == .ready ? "Clear 10 levels to win." : game.phase == .paused ? "Take your time." : "\(game.lines) lines cleared · \(game.score) points")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(muted)
                    Button(game.phase == .paused ? "RESUME" : game.phase == .over || game.phase == .won ? "PLAY AGAIN" : "START GAME") {
                        if game.phase == .paused { game.togglePause() } else { game.start() }
                    }
                    .font(.system(size: 11, weight: .black, design: .rounded)).tracking(1)
                    .foregroundStyle(Color(red: 0.03, green: 0.12, blue: 0.14))
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(aqua, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 5)
                }.multilineTextAlignment(.center).padding(12)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            control("arrow.left", label: "Move left") { game.move(-1) }
            control("arrow.right", label: "Move right") { game.move(1) }
            control("arrow.clockwise", label: "Rotate") { game.rotate() }
            control("arrow.down", label: "Soft drop") { game.softDrop() }
            Button(action: game.hardDrop) {
                VStack(spacing: 3) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 18, weight: .bold))
                    Text("DROP").font(.system(size: 8, weight: .black, design: .rounded)).tracking(0.6)
                }
                .frame(maxWidth: .infinity).frame(height: 54)
                .foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.16))
                .background(aqua, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Hard drop")
            .disabled(game.phase != .playing)
        }.opacity(game.phase == .playing ? 1 : 0.55)
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity).frame(height: 54)
                .foregroundStyle(ink)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(game.phase != .playing)
        .accessibilityLabel(label)
    }
}

private struct BoardView: View {
    @ObservedObject var game: GameModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || game.phase != .playing)) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let unit = size.width / CGFloat(GameModel.columns)
                let atlas = context.resolve(Image("FruitAtlas"))
                let background = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 13)
                context.fill(background, with: .color(Color(red: 0.025, green: 0.065, blue: 0.09)))
                for y in 0..<GameModel.rows {
                    for x in 0..<GameModel.columns {
                        let rect = CGRect(x: CGFloat(x) * unit + 1, y: CGFloat(y) * unit + 1, width: unit - 2, height: unit - 2)
                        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Color.white.opacity(0.035)))
                    }
                }
                let dropAge = now.timeIntervalSince(game.dropAt)
                if !reduceMotion && dropAge >= 0 && dropAge < 0.25 {
                    let alpha = (1 - dropAge / 0.25) * 0.30
                    for column in game.dropColumns {
                        let rect = CGRect(x: CGFloat(column) * unit + unit * 0.3, y: CGFloat(max(0, game.dropStartRow)) * unit,
                                          width: unit * 0.4, height: CGFloat(max(0, game.dropEndRow - max(0, game.dropStartRow) + 1)) * unit)
                        context.fill(Path(roundedRect: rect, cornerRadius: unit * 0.2), with: .color(aqua.opacity(alpha)))
                    }
                }
                let impactAge = now.timeIntervalSince(game.impactAt)
                for y in 0..<GameModel.rows {
                    for x in 0..<GameModel.columns {
                        guard let block = game.board[y][x] else { continue }
                        var rect = CGRect(x: CGFloat(x) * unit + 1, y: CGFloat(y) * unit + 1, width: unit - 2, height: unit - 2)
                        if !reduceMotion && impactAge >= 0 && impactAge < 0.25 && game.impactCells.contains(Cell(x: x, y: y)) {
                            let pop = CGFloat(sin(.pi * impactAge / 0.25)) * unit * 0.08
                            rect = rect.insetBy(dx: -pop, dy: -pop)
                        }
                        drawFruit(context: context, atlas: atlas, rect: rect, block: block)
                    }
                }
                if game.phase == .playing || game.phase == .paused {
                    for cell in game.ghost.cells where cell.y >= 0 {
                        let rect = CGRect(x: CGFloat(cell.x) * unit + 2, y: CGFloat(cell.y) * unit + 2, width: unit - 4, height: unit - 4)
                        context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(game.current.block.color.opacity(0.45)), lineWidth: 1.5)
                    }
                    let bob: CGFloat = (!reduceMotion && game.phase == .playing) ? CGFloat(sin(now.timeIntervalSinceReferenceDate * 4)) * unit * 0.035 : 0
                    for cell in game.current.cells where cell.y >= 0 {
                        let rect = CGRect(x: CGFloat(cell.x) * unit + 1, y: CGFloat(cell.y) * unit + 1 + bob, width: unit - 2, height: unit - 2)
                        drawFruit(context: context, atlas: atlas, rect: rect, block: game.current.block)
                    }
                }
                let clearAge = now.timeIntervalSince(game.lineClearAt)
                if !reduceMotion && clearAge >= 0 && clearAge < 0.32 {
                    context.fill(background, with: .color(aqua.opacity((1 - clearAge / 0.32) * 0.25)))
                }
                context.stroke(background, with: .color(Color.white.opacity(0.13)), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }
}

// Each sprite occupies one cell of the transparent four-by-two atlas.
private func drawFruit(context: GraphicsContext, atlas: GraphicsContext.ResolvedImage, rect: CGRect, block: Block) {
    let position = block.atlasPosition
    var clipped = context
    clipped.clip(to: Path(rect))
    let sheet = CGRect(x: rect.minX - CGFloat(position.column) * rect.width,
                       y: rect.minY - CGFloat(position.row) * rect.height,
                       width: rect.width * 4, height: rect.height * 2)
    clipped.draw(atlas, in: sheet)
}
