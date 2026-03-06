import Foundation

struct BarAnimator {
    static let barCount = 12

    static func bars(for state: MonitorState, at time: CGFloat) -> [Bar] {
        (0..<barCount).map { i in
            bar(for: state, index: i, time: time)
        }
    }

    private static func bar(for state: MonitorState, index i: Int, time t: CGFloat) -> Bar {
        let angle = (CGFloat(i) / CGFloat(barCount)) * 2 * .pi

        switch state {
        case .sleeping:
            return sleepingBar(angle: angle, index: i, time: t)
        case .working:
            return workingBar(angle: angle, time: t)
        case .idle:
            return idleBar(angle: angle, index: i, time: t)
        case .waiting:
            return waitingBar(angle: angle, index: i, time: t)
        }
    }

    private static func sleepingBar(angle: CGFloat, index i: Int, time t: CGFloat) -> Bar {
        let phase = t * 2 * .pi * 0.4
        let breathe = sin(phase + CGFloat(i) * 0.15) * 0.5 + 0.5
        return Bar(
            angle: angle,
            innerR: 0.18 + breathe * 0.04,
            outerR: 0.40 + breathe * 0.18,
            opacity: 0.3 + breathe * 0.35,
            thickness: 0.09
        )
    }

    private static func workingBar(angle: CGFloat, time t: CGFloat) -> Bar {
        let phase = t * 2 * .pi * 1.2
        let wave = sin(angle - phase) * 0.5 + 0.5
        let wave2 = sin(angle - phase * 0.7 + 1.5) * 0.3 + 0.3
        return Bar(
            angle: angle,
            innerR: 0.18 - wave * 0.04,
            outerR: 0.38 + wave * 0.35 + wave2 * 0.12,
            opacity: 0.2 + wave * 0.55,
            thickness: 0.075 + wave * 0.02
        )
    }

    private static func idleBar(angle: CGFloat, index i: Int, time t: CGFloat) -> Bar {
        let phase = t * 2 * .pi * 0.5
        let pulse = sin(phase) * 0.5 + 0.5
        let shimmer = sin(phase * 2.5 + CGFloat(i) * 0.8) * 0.08
        return Bar(
            angle: angle,
            innerR: 0.18,
            outerR: 0.50 + pulse * 0.15 + shimmer,
            opacity: 0.45 + pulse * 0.25 + shimmer,
            thickness: 0.09
        )
    }

    private static func waitingBar(angle: CGFloat, index i: Int, time t: CGFloat) -> Bar {
        let phase = t * 2 * .pi * 0.45
        let ripple1 = sin(phase * 2) * 0.5 + 0.5
        let ripple2 = sin(phase * 2.5 + .pi) * 0.5 + 0.5
        let r = (i % 2 == 0) ? ripple1 : ripple2
        return Bar(
            angle: angle,
            innerR: 0.15 + (1 - r) * 0.1,
            outerR: 0.3 + r * 0.45,
            opacity: 0.3 + r * 0.5,
            thickness: 0.09 + r * 0.02
        )
    }
}
