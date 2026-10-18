import Foundation

/// Keyboard-style stepping: first step at 60 points, one more every further 200, never retracted.
/// With natural direction on, dragging left moves to the Space on the right, as a trackpad swipe does.
public struct DiscreteStepper: Sendable {
    public static let firstStep: Double = 60
    public static let nextStep: Double = 200

    private let axis: Axis
    private let dragDownAction: DragDownAction
    private let naturalDirection: Bool
    private var distance: Double = 0
    private var committed = 0  // signed step count in the current direction
    private var verticalFired = false

    public init(axis: Axis, dragDownAction: DragDownAction, naturalDirection: Bool) {
        self.axis = axis
        self.dragDownAction = dragDownAction
        self.naturalDirection = naturalDirection
    }

    public static func horizontalStep(forDistance distance: Double, naturalDirection: Bool) -> StepCommand {
        let rightward = naturalDirection ? distance < 0 : distance > 0
        return rightward ? .moveSpaceRight : .moveSpaceLeft
    }

    public mutating func move(delta: Double) -> [StepCommand] {
        distance += delta
        switch axis {
        case .vertical:
            guard !verticalFired, abs(distance) >= DiscreteStepper.firstStep else { return [] }
            verticalFired = true
            if distance < 0 { return [.missionControl] }
            switch dragDownAction {
            case .exitMissionControl: return [.missionControl]  // the hotkey toggles it closed
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
            let step = DiscreteStepper.horizontalStep(forDistance: distance, naturalDirection: naturalDirection)
            return Array(repeating: step, count: target - have)
        }
    }
}
