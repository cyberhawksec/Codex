import SwiftUI
import Combine

struct Cell: Hashable {
    var x: Int
    var y: Int
}

enum Block: Int, CaseIterable {
    case i, o, t, s, z, j, l

    // Position in the four-column, two-row fruit sprite atlas.
    var atlasPosition: (column: Int, row: Int) {
        switch self {
        case .i: return (0, 0)
        case .o: return (1, 0)
        case .t: return (2, 0)
        case .s: return (3, 0)
        case .z: return (0, 1)
        case .j: return (1, 1)
        case .l: return (2, 1)
        }
    }

    var fruitName: String {
        switch self {
        case .i: return "apples"
        case .o: return "lemons"
        case .t: return "grapes"
        case .s: return "kiwis"
        case .z: return "strawberries"
        case .j: return "blueberries"
        case .l: return "oranges"
        }
    }

    var color: Color {
        switch self {
        case .i: return Color(red: 0.29, green: 0.88, blue: 0.91)
        case .o: return Color(red: 1.00, green: 0.78, blue: 0.35)
        case .t: return Color(red: 0.70, green: 0.53, blue: 0.98)
        case .s: return Color(red: 0.42, green: 0.86, blue: 0.65)
        case .z: return Color(red: 1.00, green: 0.43, blue: 0.51)
        case .j: return Color(red: 0.39, green: 0.62, blue: 0.99)
        case .l: return Color(red: 1.00, green: 0.62, blue: 0.35)
        }
    }

    // Coordinates live in a four-by-four rotation box.
    var cells: [Cell] {
        switch self {
        case .i: return [Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1), Cell(x: 3, y: 1)]
        case .o: return [Cell(x: 1, y: 0), Cell(x: 2, y: 0), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
        case .t: return [Cell(x: 1, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
        case .s: return [Cell(x: 1, y: 0), Cell(x: 2, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)]
        case .z: return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
        case .j: return [Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
        case .l: return [Cell(x: 2, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
        }
    }
}

struct Piece {
    let block: Block
    var rotation = 0
    var x = 3
    var y = 0

    var cells: [Cell] {
        block.cells.map { original in
            var cell = original
            if block != .o {
                for _ in 0..<rotation {
                    cell = Cell(x: 3 - cell.y, y: cell.x)
                }
            }
            return Cell(x: cell.x + x, y: cell.y + y)
        }
    }
}

enum GamePhase { case ready, playing, paused, over, won }

@MainActor
final class GameModel: ObservableObject {
    static let columns = 10
    static let rows = 20

    @Published private(set) var board = Array(repeating: Array<Block?>(repeating: nil, count: GameModel.columns), count: GameModel.rows)
    @Published private(set) var current = Piece(block: .t)
    @Published private(set) var next: Block = .i
    @Published private(set) var phase: GamePhase = .ready
    @Published private(set) var score = 0
    @Published private(set) var lines = 0
    @Published private(set) var best: Int
    @Published private(set) var impactAt = Date.distantPast
    @Published private(set) var lineClearAt = Date.distantPast
    @Published private(set) var dropAt = Date.distantPast
    @Published private(set) var impactCells: Set<Cell> = []
    @Published private(set) var dropColumns: Set<Int> = []
    @Published private(set) var dropStartRow = 0
    @Published private(set) var dropEndRow = 0
    private var bag: [Block] = []
    private var lastFall = Date()
    private var runPlayerID: String?

    var level: Int { min(10, lines / 10 + 1) }
    var fallInterval: TimeInterval { max(0.09, 0.80 * pow(0.85, Double(level - 1))) }
    var ghost: Piece {
        var result = current
        while canPlace(result, dx: 0, dy: 1) { result.y += 1 }
        return result
    }

    init() {
        best = UserDefaults.standard.integer(forKey: "stackfall.best")
    }

    func start() {
        board = Array(repeating: Array<Block?>(repeating: nil, count: Self.columns), count: Self.rows)
        score = 0
        lines = 0
        bag = []
        impactAt = .distantPast
        lineClearAt = .distantPast
        dropAt = .distantPast
        impactCells = []
        dropColumns = []
        runPlayerID = GameCenterManager.shared.playerID
        current = Piece(block: takeBlock())
        next = takeBlock()
        lastFall = Date()
        phase = .playing
    }

    func togglePause() {
        if phase == .playing { phase = .paused }
        else if phase == .paused { lastFall = Date(); phase = .playing }
    }

    func pause() {
        if phase == .playing { phase = .paused }
    }

    func update(now: Date) {
        guard phase == .playing, now.timeIntervalSince(lastFall) >= fallInterval else { return }
        lastFall = now
        stepDown(awardPoint: false)
    }

    func move(_ dx: Int) {
        guard phase == .playing, canPlace(current, dx: dx, dy: 0) else { return }
        current.x += dx
    }

    func rotate() {
        guard phase == .playing else { return }
        var rotated = current
        rotated.rotation = (rotated.rotation + 1) % 4
        // Small wall kicks make rotations forgiving near edges and stacks.
        for offset in [Cell(x: 0, y: 0), Cell(x: -1, y: 0), Cell(x: 1, y: 0), Cell(x: -2, y: 0), Cell(x: 2, y: 0), Cell(x: 0, y: -1)] {
            if canPlace(rotated, dx: offset.x, dy: offset.y) {
                rotated.x += offset.x
                rotated.y += offset.y
                current = rotated
                return
            }
        }
    }

    func softDrop() {
        guard phase == .playing else { return }
        stepDown(awardPoint: true)
        lastFall = Date()
    }

    func hardDrop() {
        guard phase == .playing else { return }
        let startingCells = current.cells
        var distance = 0
        while canPlace(current, dx: 0, dy: 1) { current.y += 1; distance += 1 }
        if distance > 0 {
            dropColumns = Set(startingCells.map(\.x))
            dropStartRow = startingCells.map(\.y).min() ?? 0
            dropEndRow = current.cells.map(\.y).max() ?? 0
            dropAt = Date()
        }
        addScore(distance * 2)
        lockPiece()
        lastFall = Date()
    }

    private func stepDown(awardPoint: Bool) {
        if canPlace(current, dx: 0, dy: 1) {
            current.y += 1
            if awardPoint { addScore(1) }
        } else {
            lockPiece()
        }
    }

    private func canPlace(_ piece: Piece, dx: Int, dy: Int) -> Bool {
        for cell in piece.cells {
            let x = cell.x + dx
            let y = cell.y + dy
            if x < 0 || x >= Self.columns || y >= Self.rows { return false }
            if y >= 0 && board[y][x] != nil { return false }
        }
        return true
    }

    private func lockPiece() {
        if current.cells.contains(where: { $0.y < 0 }) { finishGame(.over); return }
        for cell in current.cells { board[cell.y][cell.x] = current.block }
        impactCells = Set(current.cells)
        impactAt = Date()
        let oldLevel = level
        let remaining = board.filter { row in row.contains(where: { $0 == nil }) }
        let cleared = Self.rows - remaining.count
        if cleared > 0 {
            lineClearAt = Date()
            impactCells = []
            board = Array(repeating: Array<Block?>(repeating: nil, count: Self.columns), count: cleared) + remaining
            lines += cleared
            addScore([0, 100, 300, 500, 800][min(cleared, 4)] * oldLevel)
        }
        if lines >= 100 {
            finishGame(.won)
            return
        }
        current = Piece(block: next)
        next = takeBlock()
        if !canPlace(current, dx: 0, dy: 0) { finishGame(.over) }
    }

    private func finishGame(_ result: GamePhase) {
        phase = result
        GameCenterManager.shared.finish(score: score, playerID: runPlayerID)
        runPlayerID = nil
    }

    private func takeBlock() -> Block {
        if bag.isEmpty { bag = Block.allCases.shuffled() }
        return bag.removeLast()
    }

    private func addScore(_ amount: Int) {
        score += amount
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: "stackfall.best")
        }
    }
}

