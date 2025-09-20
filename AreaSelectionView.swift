import SwiftUI
import AppKit

// Custom window that can become key to receive keyboard events
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

struct AreaSelectionView: NSViewRepresentable {
    let onAreaSelected: (CGRect?) -> Void
    
    func makeNSView(context: Context) -> AreaSelectionNSView {
        let view = AreaSelectionNSView()
        view.onAreaSelected = onAreaSelected
        return view
    }
    
    func updateNSView(_ nsView: AreaSelectionNSView, context: Context) {
        // No updates needed
    }
}

class AreaSelectionNSView: NSView {
    var onAreaSelected: ((CGRect?) -> Void)?
    private var startPoint: NSPoint?
    private var currentRect: NSRect = NSRect.zero
    private var isDragging = false
    private var overlayWindow: NSWindow?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let window = self.window {
            // Hide the original window
            window.orderOut(nil)
            
            // Create full-screen overlay
            createOverlayWindow()
        }
    }
    
    private func createOverlayWindow() {
        // Get screen frame
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // Create overlay window that covers the entire screen using custom KeyableWindow
        overlayWindow = KeyableWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let overlayWindow = overlayWindow else { return }
        
        overlayWindow.level = NSWindow.Level.screenSaver
        overlayWindow.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        overlayWindow.isOpaque = false
        overlayWindow.hasShadow = false
        overlayWindow.ignoresMouseEvents = false
        
        // Create content view for the overlay
        let overlayContentView = AreaSelectionOverlayView()
        overlayContentView.onAreaSelected = { [weak self] rect in
            print("✅ Area selected, closing overlay")
            self?.closeOverlay()
            self?.onAreaSelected?(rect)
        }
        overlayContentView.onCancel = { [weak self] in
            print("🚫 Area selection cancelled, closing overlay")
            self?.closeOverlay()
            self?.onAreaSelected?(nil)
        }
        
        overlayWindow.contentView = overlayContentView
        overlayWindow.makeKeyAndOrderFront(nil)
        
        // Ensure the overlay window can receive keyboard events
        overlayWindow.acceptsMouseMovedEvents = true
        
        // Make the content view the first responder to handle ESC key
        DispatchQueue.main.async {
            overlayWindow.makeFirstResponder(overlayContentView)
        }
    }
    
    private func closeOverlay() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        
        // Close the parent window as well
        self.window?.close()
    }
}

class AreaSelectionOverlayView: NSView {
    var onAreaSelected: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var isDragging = false
    private var keyEventMonitor: Any?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        print("🖼️ AreaSelectionOverlayView moved to window")
        
        // Add instructions
        let instructionLabel = NSTextField(labelWithString: "Click and drag to select an area. Press ESC to cancel.")
        instructionLabel.textColor = .white
        instructionLabel.font = NSFont.systemFont(ofSize: 16)
        instructionLabel.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        instructionLabel.isBordered = false
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 50)
        ])
        
        // Try to become first responder immediately
        DispatchQueue.main.async {
            print("🎯 Attempting to become first responder...")
            if self.window?.makeFirstResponder(self) == true {
                print("✅ Successfully became first responder")
            } else {
                print("❌ Failed to become first responder")
            }
        }
        
        // Set up global key event monitor as backup
        setupKeyEventMonitor()
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isDragging = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging, let start = startPoint, let current = currentPoint else {
            isDragging = false
            return
        }
        
        isDragging = false
        
        // Calculate selection rectangle
        let minX = min(start.x, current.x)
        let minY = min(start.y, current.y)
        let maxX = max(start.x, current.x)
        let maxY = max(start.y, current.y)
        
        let width = maxX - minX
        let height = maxY - minY
        
        // Only proceed if we have a meaningful selection
        if width > 10 && height > 10 {
            // Convert to screen coordinates
            guard let window = self.window else { return }
            let windowRect = NSRect(x: minX, y: minY, width: width, height: height)
            let screenRect = window.convertToScreen(windowRect)
            
            // Convert to CGRect and flip Y coordinate (macOS screen coordinates are flipped)
            let screenFrame = NSScreen.main?.frame ?? NSRect.zero
            let flippedY = screenFrame.height - screenRect.maxY
            let cgRect = CGRect(x: screenRect.minX, y: flippedY, width: screenRect.width, height: screenRect.height)
            
            cleanupKeyEventMonitor()
            onAreaSelected?(cgRect)
        } else {
            cleanupKeyEventMonitor()
            onCancel?()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        print("🔑 Key pressed: keyCode = \(event.keyCode)")
        if event.keyCode == 53 { // ESC key
            print("🚪 ESC key detected, cancelling area selection")
            cleanupKeyEventMonitor()
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        print("🎯 acceptsFirstResponder called, returning true")
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        print("✅ becomeFirstResponder called")
        return super.becomeFirstResponder()
    }
    
    private func setupKeyEventMonitor() {
        print("🔧 Setting up global key event monitor")
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            print("🔑 Global key monitor - Key pressed: keyCode = \(event.keyCode)")
            if event.keyCode == 53 { // ESC key
                print("🚪 Global ESC key detected, cancelling area selection")
                self?.onCancel?()
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func cleanupKeyEventMonitor() {
        if let monitor = keyEventMonitor {
            print("🧹 Cleaning up key event monitor")
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    deinit {
        cleanupKeyEventMonitor()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw semi-transparent overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        
        // Draw selection rectangle if dragging
        if isDragging, let start = startPoint, let current = currentPoint {
            let minX = min(start.x, current.x)
            let minY = min(start.y, current.y)
            let maxX = max(start.x, current.x)
            let maxY = max(start.y, current.y)
            
            let selectionRect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            
            // Clear the selection area (make it transparent)
            NSColor.clear.setFill()
            selectionRect.fill(using: .copy)
            
            // Draw selection border
            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: selectionRect)
            borderPath.lineWidth = 2.0
            borderPath.stroke()
            
            // Draw corner handles
            drawCornerHandles(for: selectionRect)
            
            // Draw dimensions
            drawDimensions(for: selectionRect)
        }
    }
    
    private func drawCornerHandles(for rect: NSRect) {
        let handleSize: CGFloat = 8
        let handleColor = NSColor.white
        
        let corners = [
            NSPoint(x: rect.minX - handleSize/2, y: rect.minY - handleSize/2),
            NSPoint(x: rect.maxX - handleSize/2, y: rect.minY - handleSize/2),
            NSPoint(x: rect.minX - handleSize/2, y: rect.maxY - handleSize/2),
            NSPoint(x: rect.maxX - handleSize/2, y: rect.maxY - handleSize/2)
        ]
        
        handleColor.setFill()
        for corner in corners {
            let handleRect = NSRect(x: corner.x, y: corner.y, width: handleSize, height: handleSize)
            handleRect.fill()
        }
    }
    
    private func drawDimensions(for rect: NSRect) {
        let width = Int(rect.width)
        let height = Int(rect.height)
        let dimensionText = "\(width) × \(height)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        
        let attributedString = NSAttributedString(string: dimensionText, attributes: attributes)
        let textSize = attributedString.size()
        
        let textRect = NSRect(
            x: rect.midX - textSize.width / 2,
            y: rect.maxY + 5,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
    }
}
