import Foundation

/// Keyboard-style stepping: first step at 60 points, one more every further 200, never retracted.
public struct DiscreteStepper: Sendable {
    public static let firstStep: Double = 60
    public static let nextStep: Double = 200

    private let axis: Axis
    private let dragDownAction: DragDownAction
    private var distance: Double = 0
    private var committed = 0  // signed step count in the current direction
    private var verticalFired = false

    public init(axis: Axis, dragDownAction: DragDownAction) {
        self.axis = axis
        self.dragDownAction = dragDownAction
    }

    public mutating func move(delta: Double) -> [StepCommand] {
        distance += delta
        switch axis {
        case .vertical:
            guard !verticalFired, abs(distance) >= DiscreteStepper.firstStep else { return [] }
            verticalFired = true
            if distance < 0 { return [.missionControl] }
            switch dragDownAction {
            case .appExpose: return [.appExpose]
            case .showDesktop: return [.showDesktop]
            case .none: return []
            }
        case .horizontal:
            let direction = distance > 0 ? 1 : (distance < 0 ? -1 : 0)
            if direction != 0, committed != 0, (committed > 0) != (direction > 0) {
                committed = 0
            }
            let magnitude = abs(distance)
            let target = magnitude < DiscreteStepper.firstStep
                ? 0
                : 1 + Int((magnitude - DiscreteStepper.firstStep) / DiscreteStepper.nextStep)
            let have = abs(committed)
            guard target > have, direction != 0 else { return [] }
            committed = direction * target
            let step: StepCommand = direction > 0 ? .moveSpaceRight : .moveSpaceLeft
            return Array(repeating: step, count: target - have)
        }
    }
}
