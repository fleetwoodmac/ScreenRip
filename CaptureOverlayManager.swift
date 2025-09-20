import AppKit
import SwiftUI

class CaptureOverlayManager: ObservableObject {
    private var frameOverlayWindow: NSWindow?
    private var flashOverlayWindow: NSWindow?
    private var counterOverlayWindow: NSWindow?
    private var cancelCallback: (() -> Void)?
    
    func setCancelCallback(_ callback: @escaping () -> Void) {
        self.cancelCallback = callback
    }
    
    // Show persistent frame around capture area
    func showCaptureFrame(for area: CGRect) {
        hideCaptureFrame() // Remove any existing frame
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // Convert CGRect to NSRect and adjust for screen coordinates
        let frameRect = NSRect(
            x: area.origin.x,
            y: screenFrame.height - area.origin.y - area.height,
            width: area.width,
            height: area.height
        )
        
        // Create overlay window for the frame
        frameOverlayWindow = NSWindow(
            contentRect: frameRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let frameOverlayWindow = frameOverlayWindow else { return }
        
        frameOverlayWindow.level = NSWindow.Level.screenSaver
        frameOverlayWindow.backgroundColor = NSColor.clear
        frameOverlayWindow.isOpaque = false
        frameOverlayWindow.hasShadow = false
        frameOverlayWindow.ignoresMouseEvents = true
        frameOverlayWindow.collectionBehavior = [.canJoinAllSpaces]
        
        // Create the frame view
        let frameView = CaptureFrameView(frame: frameRect)
        frameOverlayWindow.contentView = frameView
        frameOverlayWindow.orderFront(nil)
    }
    
    // Hide the persistent frame
    func hideCaptureFrame() {
        frameOverlayWindow?.orderOut(nil)
        frameOverlayWindow = nil
    }
    
    // Show counter and countdown near capture area
    func showCounter(for area: CGRect, current: Int, total: Int, countdown: Int) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // Position counter above the capture area
        let counterRect = NSRect(
            x: area.origin.x,
            y: screenFrame.height - area.origin.y + 20, // Above the capture area
            width: 200,
            height: 80 // Increased height to accommodate cancel button
        )
        
        // Create or update counter overlay window
        if counterOverlayWindow == nil {
            counterOverlayWindow = NSWindow(
                contentRect: counterRect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            guard let counterOverlayWindow = counterOverlayWindow else { return }
            
            counterOverlayWindow.level = NSWindow.Level.screenSaver + 2 // Above other overlays
            counterOverlayWindow.backgroundColor = NSColor.clear
            counterOverlayWindow.isOpaque = false
            counterOverlayWindow.hasShadow = false
            counterOverlayWindow.ignoresMouseEvents = false // Allow mouse events for cancel button
            counterOverlayWindow.collectionBehavior = [.canJoinAllSpaces]
            
            let counterView = CaptureCounterView(frame: counterRect.size)
            counterView.setCancelCallback { [weak self] in
                self?.cancelCallback?()
            }
            counterOverlayWindow.contentView = counterView
            counterOverlayWindow.orderFront(nil)
        }
        
        // Update the counter display
        if let counterView = counterOverlayWindow?.contentView as? CaptureCounterView {
            counterView.updateCounter(current: current, total: total, countdown: countdown)
        }
        
        // Update window position in case capture area changed
        counterOverlayWindow?.setFrame(counterRect, display: true)
    }
    
    // Hide the counter overlay
    func hideCounter() {
        counterOverlayWindow?.orderOut(nil)
        counterOverlayWindow = nil
    }
    
    // Show flash effect when screenshot is taken
    func showCaptureFlash(for area: CGRect) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // Convert CGRect to NSRect and adjust for screen coordinates
        let flashRect = NSRect(
            x: area.origin.x - 10, // Slightly larger than capture area
            y: screenFrame.height - area.origin.y - area.height - 10,
            width: area.width + 20,
            height: area.height + 20
        )
        
        // Create overlay window for the flash effect
        flashOverlayWindow = NSWindow(
            contentRect: flashRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let flashOverlayWindow = flashOverlayWindow else { return }
        
        flashOverlayWindow.level = NSWindow.Level.screenSaver + 1 // Above frame overlay
        flashOverlayWindow.backgroundColor = NSColor.clear
        flashOverlayWindow.isOpaque = false
        flashOverlayWindow.hasShadow = false
        flashOverlayWindow.ignoresMouseEvents = true
        flashOverlayWindow.collectionBehavior = [.canJoinAllSpaces]
        
        // Create the flash view
        let flashView = CaptureFlashView(frame: flashRect)
        flashOverlayWindow.contentView = flashView
        flashOverlayWindow.orderFront(nil)
        
        // Animate the flash effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.flashOverlayWindow?.orderOut(nil)
            self.flashOverlayWindow = nil
        }
    }
}

// MARK: - Capture Frame View
class CaptureFrameView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw frame border
        let borderPath = NSBezierPath(rect: bounds)
        borderPath.lineWidth = 3.0
        NSColor.systemBlue.setStroke()
        borderPath.stroke()
        
        // Draw corner handles
        drawCornerHandles()
        
        // Draw dimension label
        drawDimensionLabel()
    }
    
    private func drawCornerHandles() {
        let handleSize: CGFloat = 8
        let handleColor = NSColor.systemBlue
        
        let corners = [
            NSPoint(x: 0, y: 0),
            NSPoint(x: bounds.width - handleSize, y: 0),
            NSPoint(x: 0, y: bounds.height - handleSize),
            NSPoint(x: bounds.width - handleSize, y: bounds.height - handleSize)
        ]
        
        handleColor.setFill()
        for corner in corners {
            let handleRect = NSRect(x: corner.x, y: corner.y, width: handleSize, height: handleSize)
            NSBezierPath(rect: handleRect).fill()
        }
    }
    
    private func drawDimensionLabel() {
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        let dimensionText = "\(width) × \(height)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.systemBlue.withAlphaComponent(0.8)
        ]
        
        let attributedString = NSAttributedString(string: " \(dimensionText) ", attributes: attributes)
        let textSize = attributedString.size()
        
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: bounds.height + 5,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
    }
}

// MARK: - Capture Flash View
class CaptureFlashView: NSView {
    private var animationProgress: CGFloat = 0.0
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startFlashAnimation()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw flash effect with animated opacity
        let flashColor = NSColor.white.withAlphaComponent(0.6 * (1.0 - animationProgress))
        flashColor.setFill()
        bounds.fill()
        
        // Draw animated border
        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: 5, dy: 5))
        borderPath.lineWidth = 4.0
        NSColor.systemGreen.withAlphaComponent(1.0 - animationProgress).setStroke()
        borderPath.stroke()
    }
    
    private func startFlashAnimation() {
        // Use Timer-based animation for macOS 13 compatibility
        let animationDuration: TimeInterval = 0.15
        let frameRate: TimeInterval = 1.0 / 60.0 // 60 FPS
        let totalFrames = Int(animationDuration / frameRate)
        var currentFrame = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentFrame += 1
            self.animationProgress = CGFloat(currentFrame) / CGFloat(totalFrames)
            
            DispatchQueue.main.async {
                self.needsDisplay = true
            }
            
            if currentFrame >= totalFrames {
                timer.invalidate()
                self.animationProgress = 1.0
                DispatchQueue.main.async {
                    self.needsDisplay = true
                }
            }
        }
        
        // Ensure timer runs on main thread
        RunLoop.main.add(timer, forMode: .common)
    }
}

// MARK: - Capture Counter View
class CaptureCounterView: NSView {
    private var currentShot: Int = 1
    private var totalShots: Int = 1
    private var countdown: Int = 0
    private var cancelCallback: (() -> Void)?
    private var cancelButtonRect: NSRect = .zero
    
    convenience init(frame frameSize: NSSize) {
        self.init(frame: NSRect(origin: .zero, size: frameSize))
    }
    
    func setCancelCallback(_ callback: @escaping () -> Void) {
        self.cancelCallback = callback
    }
    
    func updateCounter(current: Int, total: Int, countdown: Int) {
        self.currentShot = current
        self.totalShots = total
        self.countdown = countdown
        
        DispatchQueue.main.async {
            self.needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background with rounded corners
        let backgroundPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 5), xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.8).setFill()
        backgroundPath.fill()
        
        // Border
        NSColor.systemBlue.setStroke()
        backgroundPath.lineWidth = 2.0
        backgroundPath.stroke()
        
        // Counter text
        let counterText = "\(currentShot) / \(totalShots)"
        let counterAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        
        let counterString = NSAttributedString(string: counterText, attributes: counterAttributes)
        let counterSize = counterString.size()
        let counterRect = NSRect(
            x: (bounds.width - counterSize.width) / 2,
            y: bounds.height - 30, // Adjusted to make room for cancel button
            width: counterSize.width,
            height: counterSize.height
        )
        counterString.draw(in: counterRect)
        
        // Countdown text (if applicable)
        if countdown > 0 {
            let countdownText = "Next in: \(countdown)s"
            let countdownAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.systemYellow
            ]
            
            let countdownString = NSAttributedString(string: countdownText, attributes: countdownAttributes)
            let countdownSize = countdownString.size()
            let countdownRect = NSRect(
                x: (bounds.width - countdownSize.width) / 2,
                y: 32, // Adjusted position
                width: countdownSize.width,
                height: countdownSize.height
            )
            countdownString.draw(in: countdownRect)
        }
        
        // Cancel button
        let buttonWidth: CGFloat = 60
        let buttonHeight: CGFloat = 20
        cancelButtonRect = NSRect(
            x: (bounds.width - buttonWidth) / 2,
            y: 4,
            width: buttonWidth,
            height: buttonHeight
        )
        
        // Button background
        let buttonPath = NSBezierPath(roundedRect: cancelButtonRect, xRadius: 4, yRadius: 4)
        NSColor.systemRed.withAlphaComponent(0.8).setFill()
        buttonPath.fill()
        
        // Button border
        NSColor.systemRed.setStroke()
        buttonPath.lineWidth = 1.0
        buttonPath.stroke()
        
        // Button text
        let buttonText = "Cancel"
        let buttonAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        
        let buttonString = NSAttributedString(string: buttonText, attributes: buttonAttributes)
        let buttonTextSize = buttonString.size()
        let buttonTextRect = NSRect(
            x: cancelButtonRect.midX - buttonTextSize.width / 2,
            y: cancelButtonRect.midY - buttonTextSize.height / 2,
            width: buttonTextSize.width,
            height: buttonTextSize.height
        )
        buttonString.draw(in: buttonTextRect)
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        if cancelButtonRect.contains(location) {
            cancelCallback?()
        }
    }
}
