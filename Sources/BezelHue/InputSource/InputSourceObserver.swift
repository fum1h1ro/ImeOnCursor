import Carbon.HIToolbox
import Combine
import Foundation

final class InputSourceObserver {
    let currentSource = CurrentValueSubject<InputSourceInfo?, Never>(nil)

    private var registered = false

    init() {
        if let info = InputSourceInfo.current() {
            currentSource.send(info)
        }
        startObserving()
    }

    deinit {
        guard registered else { return }
        let notificationName = kTISNotifySelectedKeyboardInputSourceChanged as CFString
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(notificationName),
            nil
        )
    }

    private func startObserving() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let notificationName = kTISNotifySelectedKeyboardInputSourceChanged as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(),
            selfPtr,
            { _, selfPtr, _, _, _ in
                guard let selfPtr else { return }
                let observer = Unmanaged<InputSourceObserver>.fromOpaque(selfPtr).takeUnretainedValue()
                DispatchQueue.main.async { [weak observer] in
                    guard let observer else { return }
                    if let info = InputSourceInfo.current() {
                        observer.currentSource.send(info)
                    }
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )
        registered = true
    }
}
