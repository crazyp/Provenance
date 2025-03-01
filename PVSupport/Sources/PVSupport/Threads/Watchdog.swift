import Foundation

/// Class for logging excessive blocking on the main thread.
final public class Watchdog {
    fileprivate let pingThread: PingThread

    @objc public static let defaultThreshold = 0.4

    /// Convenience initializer that allows you to construct a `WatchDog` object with default behavior.
    /// - parameter threshold: number of seconds that must pass to consider the main thread blocked.
    /// - parameter strictMode: boolean value that stops the execution whenever the threshold is reached.
    @objc public convenience init(threshold: Double = Watchdog.defaultThreshold, strictMode: Bool = false) {
        let message = "👮 Main thread was blocked for " + String(format: "%.2f", threshold) + "s 👮"

        self.init(threshold: threshold) {
            if strictMode {
                fatalError(message)
            } else {
                NSLog("%@", message)
            }
        }
    }

    /// Default initializer that allows you to construct a `WatchDog` object specifying a custom callback.
    /// - parameter threshold: number of seconds that must pass to consider the main thread blocked.
    /// - parameter watchdogFiredCallback: a callback that will be called when the the threshold is reached
    @objc public init(threshold: Double = Watchdog.defaultThreshold, watchdogFiredCallback: @escaping () -> Void) {
        self.pingThread = PingThread(threshold: threshold, handler: watchdogFiredCallback)

        self.pingThread.start()
    }
    
    deinit {
        pingThread.cancel()
    }
}

private final class PingThread: Thread {
    fileprivate var pingTaskIsRunning: Bool {
        get {
            objc_sync_enter(pingTaskIsRunningLock)
            let result = _pingTaskIsRunning;
            objc_sync_exit(pingTaskIsRunningLock)
            return result
        }
        set {
            objc_sync_enter(pingTaskIsRunningLock)
            _pingTaskIsRunning = newValue
            objc_sync_exit(pingTaskIsRunningLock)
        }
    }
    private var _pingTaskIsRunning = false
    private let pingTaskIsRunningLock = NSObject()
    fileprivate var semaphore = DispatchSemaphore(value: 0)
    fileprivate let threshold: Double
    fileprivate let handler: () -> Void
    
    init(threshold: Double, handler: @escaping () -> Void) {
        self.threshold = threshold
        self.handler = handler
        super.init()
        self.name = "WatchDog"
    }

    @preconcurrency
    nonisolated
    override func main() {
        while !isCancelled {
            pingTaskIsRunning = true
            #warning("TODO: Implement a proper ping task")
            DispatchQueue.main.async { [weak self] in
//                guard let self else { return }
//                self.pingTaskIsRunning = false
//                self.semaphore.signal()
            }
            
            Thread.sleep(forTimeInterval: threshold)
            if pingTaskIsRunning {
                handler()
            }
            
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }
}

//private final class PingController {
//    private var pingTask: Task<Void, Never>?
//    private let semaphore = DispatchSemaphore(value: 0)
//    private var isCancelled = false
//    private let threshold: TimeInterval = 5 // Adjust according to your needs
//
//    func start() {
//        self.pingTask = Task {
//            while !isCancelled {
//                await performPingTask()
//                try? await Task.sleep(nanoseconds: UInt64(threshold * 1_000_000_000))
//                semaphore.signal()
////                semaphore.wait()
//            }
//        }
//    }
//
//    func cancel() {
//        isCancelled = true
//        pingTask?.cancel()
//    }
//
//    private func performPingTask() async {
//        // Perform the ping task here
//        // Example:
//        await withUnsafeContinuation { continuation in
//            // Placeholder for actual ping operation
//            DispatchQueue.main.asyncAfter(deadline: .now() + threshold) {
//                self.semaphore.signal()
//                continuation.resume()
//            }
//        }
//    }
//}
