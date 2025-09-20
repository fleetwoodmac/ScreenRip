import Foundation
import ScreenCaptureKit
import AppKit
import CoreGraphics
import ApplicationServices

@MainActor
class ScreenCaptureManager: NSObject, ObservableObject {
    @Published var statusMessage: String = "Ready"
    private var availableContent: SCShareableContent?
    private var capturedImage: CGImage?
    private let overlayManager = CaptureOverlayManager()
    private var isCancelled = false
    private var captureTask: Task<Void, Never>?
    
    // Debug logging
    private var debugLoggingEnabled = false
    private var debugLogURL: URL?
    
    func setDebugLogging(enabled: Bool, saveLocation: URL) {
        debugLoggingEnabled = enabled
        if enabled {
            debugLogURL = saveLocation.appendingPathComponent("debug.txt")
            debugLog("🔧 Debug logging enabled - saving to: \(debugLogURL?.path ?? "unknown")")
            debugLog("📅 Debug session started at: \(Date())")
        } else {
            debugLog("🔧 Debug logging disabled")
            debugLogURL = nil
        }
    }
    
    private func debugLog(_ message: String) {
        // Always print to console
        print(message)
        
        // Also write to file if debug logging is enabled
        if debugLoggingEnabled, let logURL = debugLogURL {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let timestamp = formatter.string(from: Date())
            let logMessage = "[\(timestamp)] \(message)\n"
            
            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logURL.path) {
                    // Append to existing file
                    if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    // Create new file
                    try? data.write(to: logURL)
                }
            }
        }
    }
    
    // Check if accessibility permissions are granted
    func checkAccessibilityPermissions() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return accessEnabled
    }
    
    // Request accessibility permissions (will show system dialog)
    func requestAccessibilityPermissions() {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("🔓 Accessibility permissions: \(accessEnabled ? "granted" : "requesting...")")
    }
    
    // Silently check for screen recording permissions without prompting
    func checkScreenRecordingPermissionsAsync() async -> Bool {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.availableContent = content
            return true
        } catch {
            return false
        }
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // First check if we can get screen content (this will prompt for permission if needed)
                print("🔐 Requesting screen recording permission...")
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                self.availableContent = content
                print("✅ Screen recording permission granted")
                await MainActor.run {
                    completion(true)
                }
            } catch {
                print("❌ Failed to get screen content: \(error)")
                
                // Check if it's a permission error
                let errorCode = (error as NSError).code
                let errorDomain = (error as NSError).domain
                
                print("🔴 Error domain: \(errorDomain), code: \(errorCode)")
                
                // Check for common ScreenCaptureKit permission errors
                if errorDomain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" {
                    switch errorCode {
                    case -3801:
                        print("🚫 User declined screen recording permission (TCC denied)")
                    case -3802:
                        print("🛑 Screen recording not allowed")
                    default:
                        print("🔴 Other ScreenCaptureKit error: \(error.localizedDescription)")
                    }
                } else {
                    print("🔴 Unknown error: \(error.localizedDescription)")
                }
                
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
    
    func cancelCapture() {
        isCancelled = true
        captureTask?.cancel()
        overlayManager.hideCaptureFrame()
        overlayManager.hideCounter()
        statusMessage = "Capture cancelled"
    }
    
    func captureArea(area: CGRect, delay: Double, count: Int, filenameGenerator: @escaping () -> String, enableScrolling: Bool, scrollAmount: Double, scrollByAreaHeight: Bool, useKeyboardScroll: Bool, scrollKey: ScrollKey, saveLocation: URL, completion: @escaping (Bool) -> Void) {
        debugLog("🎯 Starting capture session:")
        debugLog("  📍 Area: \(area)")
        debugLog("  📏 Area dimensions: \(area.width)×\(area.height) pixels")
        debugLog("  📐 Area position: x=\(area.origin.x), y=\(area.origin.y)")
        debugLog("  ⏱️ Delay: \(delay)s")
        debugLog("  📷 Count: \(count)")
        debugLog("  📝 Filename: Custom generator provided")
        debugLog("  📜 Scrolling: \(enableScrolling ? (scrollByAreaHeight ? "by area height (\(area.height)px)" : "\(scrollAmount)px") : "disabled")")
        debugLog("  ⌨️ Scroll method: \(enableScrolling ? (useKeyboardScroll ? "keyboard \(scrollKey.symbol) (\(scrollKey.rawValue))" : "scroll wheel") : "N/A")")
        debugLog("  💾 Save to: \(saveLocation.path)")
        
        guard let content = availableContent else {
            print("❌ No available content - permissions not granted?")
            completion(false)
            return
        }
        
        print("✅ Available content found: \(content.displays.count) displays, \(content.windows.count) windows")
        
        // Reset cancellation state
        isCancelled = false
        
        // Set up cancel callback for overlay
        overlayManager.setCancelCallback { [weak self] in
            self?.cancelCapture()
            completion(false)
        }
        
        captureTask = Task {
            do {
                // Find the display that contains the area
                guard let display = self.findDisplayContaining(area: area, in: content.displays) else {
                    print("No display found for the selected area")
                    await MainActor.run {
                        completion(false)
                    }
                    return
                }
                
                // Create content filter for the display, excluding our overlay windows
                let excludedWindows = self.getOverlayWindows()
                let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
                
                // Configure capture
                let config = SCStreamConfiguration()
                config.width = Int(area.width * 2) // Retina scaling
                config.height = Int(area.height * 2)
                config.sourceRect = area
                config.scalesToFit = false
                config.capturesAudio = false
                config.excludesCurrentProcessAudio = true
                config.backgroundColor = .clear
                
                // Show frame overlay for visual feedback
                await MainActor.run {
                    overlayManager.showCaptureFrame(for: area)
                }
                
                // Show initial counter
                await MainActor.run {
                    overlayManager.showCounter(for: area, current: 1, total: count, countdown: Int(delay))
                }
                
                // Small delay to ensure overlay is visible
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                // Perform captures with delay
                print("🔄 Starting capture loop for \(count) screenshots")
                for i in 0..<count {
                    // Check for cancellation
                    if isCancelled {
                        print("🚫 Capture cancelled by user")
                        await MainActor.run {
                            overlayManager.hideCaptureFrame()
                            overlayManager.hideCounter()
                            completion(false)
                        }
                        return
                    }
                    
                    print("📸 Capture \(i + 1) of \(count)")
                    await MainActor.run {
                        if count > 1 {
                            statusMessage = "Capturing \(i + 1) of \(count)..."
                        } else {
                            statusMessage = "Capturing..."
                        }
                        // Show counter overlay
                        overlayManager.showCounter(for: area, current: i + 1, total: count, countdown: 0)
                    }
                    
                    // Apply delay with countdown before each capture (except the first one gets initial delay)
                    let delayToUse = (i > 0 || delay > 0) ? delay : 0
                    if delayToUse > 0 {
                        // Show countdown timer
                        for remainingSeconds in stride(from: Int(delayToUse), through: 1, by: -1) {
                            // Check for cancellation during countdown
                            if isCancelled {
                                print("🚫 Capture cancelled during countdown")
                                await MainActor.run {
                                    overlayManager.hideCaptureFrame()
                                    overlayManager.hideCounter()
                                    completion(false)
                                }
                                return
                            }
                            
                            await MainActor.run {
                                overlayManager.showCounter(for: area, current: i + 1, total: count, countdown: remainingSeconds)
                            }
                            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        }
                        // Clear countdown
                        await MainActor.run {
                            overlayManager.showCounter(for: area, current: i + 1, total: count, countdown: 0)
                        }
                    }
                    
                    // Temporarily hide overlays during capture to ensure they don't appear in screenshot
                    await MainActor.run {
                        overlayManager.hideCaptureFrame()
                        overlayManager.hideCounter()
                    }
                    
                    // Brief pause to ensure overlays are hidden
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    
                    // Capture screenshot using macOS 13 compatible method
                    print("🎬 Starting stream capture for shot \(i + 1)")
                    let image = try await self.captureImageWithStream(
                        filter: filter,
                        configuration: config
                    )
                    print("📷 Stream capture completed, got image: \(image != nil)")
                    
                    // Restore overlays after capture
                    await MainActor.run {
                        overlayManager.showCaptureFrame(for: area)
                        overlayManager.showCounter(for: area, current: i + 1, total: count, countdown: 0)
                    }
                    
                    // Generate filename using the provided generator
                    let filename = filenameGenerator()
                    let fileURL = saveLocation.appendingPathComponent(filename)
                    
                    debugLog("📝 Generated filename: \(filename)")
                    
                    guard let cgImage = image else {
                        print("Failed to create CGImage")
                        continue
                    }
                    
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    guard let tiffData = nsImage.tiffRepresentation,
                          let bitmapRep = NSBitmapImageRep(data: tiffData),
                          let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                        print("Failed to convert image to PNG")
                        continue
                    }
                    
                    try pngData.write(to: fileURL)
                    print("Saved screenshot to: \(fileURL.path)")
                    
                    // Show flash effect to indicate capture
                    await MainActor.run {
                        overlayManager.showCaptureFlash(for: area)
                    }
                    
                    // Perform scroll after capture (except for the last screenshot)
                    if enableScrolling && i < count - 1 {
                        print("🔄 Starting scroll for screenshot \(i + 1) of \(count)")
                        
                        if useKeyboardScroll {
                            // Keyboard scrolling: single key press between each screenshot
                            await MainActor.run {
                                statusMessage = "Pressing \(scrollKey.rawValue)..."
                            }
                            
                            await performSingleKeyPress(scrollKey: scrollKey)
                        } else {
                            // Scroll wheel scrolling: use area height or manual amount
                            let baseScrollAmount = scrollByAreaHeight ? area.height : scrollAmount
                            
                            // For now, use the area height directly - let's see what values we get
                            let actualScrollAmount = baseScrollAmount
                            
                            if let screen = NSScreen.main {
                                let scaleFactor = screen.backingScaleFactor
                            debugLog("🔄 Screen info: scale factor = \(scaleFactor)")
                            debugLog("🔄 Using raw area height: \(actualScrollAmount)px")
                            debugLog("🔄 Would be \(actualScrollAmount / scaleFactor)px if divided by scale")
                            debugLog("🔄 Would be \(actualScrollAmount * scaleFactor)px if multiplied by scale")
                            
                            // Show visual comparison
                            debugLog("📏 Visual reference:")
                            debugLog("   - 100px = very small scroll")
                            debugLog("   - 300px = small scroll") 
                            debugLog("   - 500px = medium scroll")
                            debugLog("   - 800px+ = large scroll")
                            debugLog("   - Your area: \(Int(actualScrollAmount))px")
                            }
                            
                            debugLog("🔄 Scroll wheel settings:")
                            debugLog("  📏 scrollByAreaHeight: \(scrollByAreaHeight)")
                            debugLog("  📐 area.height: \(area.height)px")
                            debugLog("  📊 scrollAmount: \(scrollAmount)px")
                            debugLog("  ➡️ finalScrollAmount: \(actualScrollAmount)px")
                            
                            await MainActor.run {
                                let scrollDescription = scrollByAreaHeight ? "area height (\(Int(actualScrollAmount))px)" : "\(Int(actualScrollAmount))px"
                                statusMessage = "Scrolling by \(scrollDescription)..."
                            }
                            
                            await performWheelScroll(amount: actualScrollAmount)
                        }
                        
                        print("⏳ Brief pause for scroll to register...")
                        // Brief pause to ensure scroll registers
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                        print("✅ Scroll registered, ready for next screenshot")
                    }
                }
                
                // Hide overlays
                await MainActor.run {
                    overlayManager.hideCaptureFrame()
                    overlayManager.hideCounter()
                }
                
                if !isCancelled {
                    await MainActor.run {
                        statusMessage = "Completed! Saved \(count) screenshot(s)"
                        completion(true)
                    }
                }
                
            } catch {
                if !isCancelled {
                    print("Capture failed: \(error)")
                    await MainActor.run {
                        overlayManager.hideCaptureFrame()
                        overlayManager.hideCounter()
                        statusMessage = "Capture failed: \(error.localizedDescription)"
                        completion(false)
                    }
                }
            }
        }
    }
    
    private func findDisplayContaining(area: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        for display in displays {
            let displayFrame = display.frame
            
            // Check if the area intersects with the display
            if displayFrame.intersects(area) {
                return display
            }
        }
        
        // If no exact match, return the main display
        return displays.first
    }
    
    // Get overlay windows to exclude from capture
    private func getOverlayWindows() -> [SCWindow] {
        guard let content = availableContent else { return [] }
        
        var excludedWindows: [SCWindow] = []
        
        print("🔍 Checking \(content.windows.count) windows for exclusion...")
        
        // Find windows from our app to exclude
        for window in content.windows {
            if let appName = window.owningApplication?.applicationName {
                // More comprehensive matching for our app
                if appName.contains("ScreenRip") ||
                   window.owningApplication?.bundleIdentifier == "org.anonymous.screenrip" {
                    excludedWindows.append(window)
                    print("🚫 Excluding window: \(window.title ?? "Untitled") from app: \(appName)")
                }
            }
            
            // Also check for windows with empty or system-like titles that might be overlays
            if let title = window.title, title.isEmpty {
                if let appName = window.owningApplication?.applicationName,
                   appName.contains("ScreenRip") {
                    excludedWindows.append(window)
                    print("🚫 Excluding untitled window from our app: \(appName)")
                }
            }
        }
        
        print("✅ Excluding \(excludedWindows.count) windows from capture")
        return excludedWindows
    }
    
    // Perform a single key press for keyboard scrolling
    private func performSingleKeyPress(scrollKey: ScrollKey) async {
        print("⌨️ Sending single \(scrollKey.rawValue) key press")
        
        await MainActor.run {
            let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: scrollKey.keyCode, keyDown: true)
            let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: scrollKey.keyCode, keyDown: false)
            
            keyDownEvent?.post(tap: .cghidEventTap)
            keyUpEvent?.post(tap: .cghidEventTap)
        }
        
        print("✅ Single key press complete")
    }
    
    // Perform scroll wheel scrolling (no keyboard keys involved)
    private func performWheelScroll(amount: Double) async {
        debugLog("🖱️ Scrolling exactly \(Int(amount)) pixels DOWN")
        
        // In macOS scroll wheel events: NEGATIVE values scroll DOWN, POSITIVE values scroll UP
        let scrollAmount = -Int32(amount)
        
        await MainActor.run {
            // Create scroll wheel event with negative amount to scroll down
            if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: scrollAmount, wheel2: 0, wheel3: 0) {
                scrollEvent.post(tap: .cghidEventTap)
                debugLog("✅ Posted scroll event: \(scrollAmount) pixels (negative = down)")
            } else {
                debugLog("❌ Failed to create scroll event")
            }
        }
        
        debugLog("✅ Scroll complete")
    }
    
    // macOS 13 compatible image capture using SCStream
    private func captureImageWithStream(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage? {
        print("🔧 Creating stream with config: \(configuration.width)x\(configuration.height)")
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    print("🎥 Creating SCStream...")
                    let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
                    
                    // Create a single frame capture
                    print("➕ Adding stream output...")
                    let captureManager = self
                    try stream.addStreamOutput(captureManager, type: .screen, sampleHandlerQueue: DispatchQueue.global())
                    
                    print("▶️ Starting capture...")
                    try await stream.startCapture()
                    
                    // Wait a brief moment for capture
                    print("⏳ Waiting for frame...")
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second - increased wait time
                    
                    print("⏹️ Stopping capture...")
                    try await stream.stopCapture()
                    
                    if let image = captureManager.capturedImage {
                        print("✅ Got captured image: \(image.width)x\(image.height)")
                        captureManager.capturedImage = nil
                        continuation.resume(returning: image)
                    } else {
                        print("❌ No image captured from stream")
                        continuation.resume(throwing: CaptureError.noImageCaptured)
                    }
                } catch {
                    print("💥 Stream capture error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - SCStreamOutput
extension ScreenCaptureManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        print("📺 Received sample buffer, type: \(type.rawValue)")
        
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("❌ Invalid sample buffer or not screen type")
            return
        }
        
        print("🖼️ Converting image buffer to CGImage...")
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            print("✅ Successfully created CGImage: \(cgImage.width)x\(cgImage.height)")
            Task { @MainActor in
                self.capturedImage = cgImage
            }
        } else {
            print("❌ Failed to create CGImage from buffer")
        }
    }
}

// MARK: - Error Types
enum CaptureError: Error {
    case noImageCaptured
    
    var localizedDescription: String {
        switch self {
        case .noImageCaptured:
            return "Failed to capture image from stream"
        }
    }
}
