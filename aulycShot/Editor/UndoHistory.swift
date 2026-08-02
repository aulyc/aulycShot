struct UndoHistory<State> {
    private var undoStates: [State] = []
    private var redoStates: [State] = []

    var canUndo: Bool { !undoStates.isEmpty }
    var canRedo: Bool { !redoStates.isEmpty }

    mutating func record(_ current: State) {
        undoStates.append(current)
        redoStates.removeAll()
    }

    mutating func undo(current: State) -> State? {
        guard let previous = undoStates.popLast() else { return nil }
        redoStates.append(current)
        return previous
    }

    mutating func redo(current: State) -> State? {
        guard let next = redoStates.popLast() else { return nil }
        undoStates.append(current)
        return next
    }
}
