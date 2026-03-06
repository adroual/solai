import AppKit
import Combine

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let sessionManager: SessionManager
    private let notificationManager: NotificationManager
    private let preferences: PreferencesStore
    private let menuBuilder: MenuBuilder
    private var animationTimer: Timer?
    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private var cancellables = Set<AnyCancellable>()
    private var currentState: MonitorState = .sleeping

    init(sessionManager: SessionManager, notificationManager: NotificationManager, preferences: PreferencesStore) {
        self.sessionManager = sessionManager
        self.notificationManager = notificationManager
        self.preferences = preferences
        self.menuBuilder = MenuBuilder(sessionManager: sessionManager, preferences: preferences)
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = renderCurrentFrame()
        }

        statusItem.menu = menuBuilder.buildMenu()

        sessionManager.$aggregateState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.stateDidChange(to: newState)
            }
            .store(in: &cancellables)

        sessionManager.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let self = self else { return }
                self.statusItem.menu = self.menuBuilder.buildMenu()
                self.notificationManager.processStateChanges(
                    sessions: sessions,
                    notificationsEnabled: self.preferences.notificationsEnabled
                )
            }
            .store(in: &cancellables)

        startAnimation(fps: currentState.fps)
    }

    private func stateDidChange(to newState: MonitorState) {
        guard newState != currentState else { return }
        currentState = newState
        startAnimation(fps: newState.fps)
    }

    private func startAnimation(fps: Double) {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    private func tick() {
        statusItem.button?.image = renderCurrentFrame()
    }

    private func renderCurrentFrame() -> NSImage {
        let elapsed = CACurrentMediaTime() - startTime
        let bars = BarAnimator.bars(for: currentState, at: CGFloat(elapsed))
        return BarRenderer.render(bars: bars)
    }

    func cleanup() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}
