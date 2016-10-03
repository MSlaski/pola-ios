import Foundation

protocol TimerDelegate: class {
    func timer(timer: Timer, didChangeProgress progress: Double)
    func timerDidEnd(timer: Timer)
}

final class Timer {
    private let stepInterval: Int
    private let finalStep: Int
    
    private var currentStep: Int = 0
    
    private var timer: NSTimer? {
        didSet {
            oldValue?.invalidate()
        }
    }
    
    weak var delegate: TimerDelegate?
    
    init(duration: Int, stepInterval: Int) {
        self.stepInterval = stepInterval
        self.finalStep = Int(ceil(Double(duration) / Double(stepInterval)))
    }
    
    @objc private func timerStepAction() {
        currentStep += 1
        if currentStep == finalStep {
            delegate?.timer(self, didChangeProgress: 1)
            delegate?.timerDidEnd(self)
            invalidate()
        } else {
            let progress = Double(currentStep) / Double(finalStep)
            delegate?.timer(self, didChangeProgress: progress)
        }
    }
    
    func play() {
        let stepIntervalInSeconds: Double = Double(self.stepInterval) / 1000
        timer = NSTimer.scheduledTimerWithTimeInterval(stepIntervalInSeconds, target: self, selector: #selector(Timer.timerStepAction), userInfo: nil, repeats: true)
    }
    
    func pause() {
        timer = nil
    }
    
    func invalidate() {
        timer = nil
        currentStep = 0
    }
}