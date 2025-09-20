import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var captureManager = ScreenCaptureManager()
    @State private var delay: Double = 3.0
    @State private var captureCount: Int = 1
    @State private var filenamePrefix: String = ""
    @State private var enableScrolling: Bool = false
    @State private var scrollAmount: Double = 300.0
    @State private var scrollByAreaHeight: Bool = true
    @State private var useKeyboardScroll: Bool = false
    @State private var selectedScrollKey: ScrollKey = .downArrow
    @State private var saveLocation: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
    @State private var isCapturing = false
    @State private var showingAreaSelection = false
    @State private var showingFilePicker = false
    @State private var showingPermissionAlert = false
    @State private var showingAccessibilityAlert = false
    @State private var permissionMessage = ""
    @State private var accessibilityMessage = ""
    @State private var screenRecordingPermissionGranted = false
    @State private var accessibilityPermissionGranted = false
    @State private var hasCheckedPermissions = false
    @State private var enableDebugLogging: Bool = false
    @State private var delayText: String = "3.0"
    
    @State private var filenameSuffix: String = ""
    enum UniquenessMethod: String, CaseIterable {
        case none = "none"
        case sequential = "sequential" 
        case timestamp = "timestamp"
        case random = "random"
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .sequential: return "Sequential (1, 2, 3...)"
            case .timestamp: return "Timestamp (HH:MM:SS:mmm)"
            case .random: return "Random (ABC123)"
            }
        }
    }
    
    @State private var uniquenessMethod: UniquenessMethod = .none
    @State private var uniquenessPosition: UniquenessPosition = .afterSuffix
    @State private var sequenceCounter: Int = 1
    
    enum UniquenessPosition: String, CaseIterable {
        case beforeSuffix = "before"
        case afterSuffix = "after"
        
        var displayName: String {
            switch self {
            case .beforeSuffix: return "Before suffix"
            case .afterSuffix: return "After suffix"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.blue)
                    Text("ScreenRip")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                }
                
                Text("Screenshot tool with scrolling automation & keyboard macros")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                    Text("Permissions Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(screenRecordingPermissionGranted ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Recording")
                                .font(.headline)
                                .fontWeight(.medium)
                            Text("Required to capture screenshots")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(screenRecordingPermissionGranted ? "Granted" : "Required")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(screenRecordingPermissionGranted ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((screenRecordingPermissionGranted ? Color.green : Color.red).opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    HStack {
                        Circle()
                            .fill(accessibilityPermissionGranted ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility")
                                .font(.headline)
                                .fontWeight(.medium)
                            Text("Required for auto-scrolling between captures")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(accessibilityPermissionGranted ? "Granted" : "Optional")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(accessibilityPermissionGranted ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((accessibilityPermissionGranted ? Color.green : Color.orange).opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    if !accessibilityPermissionGranted {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text("Enable accessibility permission to use auto-scroll features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Grant") {
                                requestAccessibilityPermission()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .frame(width: 16)
                        Text("Capture Delay")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        TextField("0.0", text: $delayText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                            .onSubmit {
                                updateDelayFromText()
                            }
                            .onExitCommand {
                                updateDelayFromText()
                            }
                            .onChange(of: delayText) { newValue in
                                // Allow any text during editing, validate on submit or focus loss
                            }
                        
                        Text("seconds")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("0.0 - 30.0s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "camera.circle")
                            .foregroundColor(.purple)
                            .frame(width: 16)
                        Text("Number of Screenshots")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        TextField("1", text: Binding(
                            get: { String(captureCount) },
                            set: { newValue in
                                if newValue.isEmpty { return }
                                if let value = Int(newValue) {
                                    captureCount = max(1, min(1000, value))
                                }
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                        .onSubmit {
                            captureCount = max(1, min(1000, captureCount))
                        }
                        
                        Text(captureCount == 1 ? "screenshot" : "screenshots")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("1 - 1000")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                            .foregroundColor(.indigo)
                            .frame(width: 16)
                        Text("Auto-Scroll Between Shots")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $enableScrolling) {
                            HStack {
                                Text("Enable automatic scrolling")
                                    .foregroundColor(.primary)
                                
                                if enableScrolling && !accessibilityPermissionGranted {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .indigo))
                        .onChange(of: enableScrolling) { newValue in
                            if newValue {
                                accessibilityPermissionGranted = captureManager.checkAccessibilityPermissions()
                            }
                        }
                        
                        if enableScrolling {
                            Toggle(isOn: $scrollByAreaHeight) {
                                Text("Scroll by capture area height")
                                    .foregroundColor(useKeyboardScroll ? .secondary : .primary)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .indigo))
                            .padding(.leading, 16)
                            .disabled(useKeyboardScroll)
                            .opacity(useKeyboardScroll ? 0.5 : 1.0)
                            
                            Toggle(isOn: $useKeyboardScroll) {
                                Text("Use keyboard keys (instead of scroll wheel)")
                                    .foregroundColor(.primary)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .indigo))
                            .padding(.leading, 16)
                        .onChange(of: useKeyboardScroll) { newValue in
                            if newValue {
                                scrollByAreaHeight = false
                            }
                        }
                            
                            if useKeyboardScroll {
                                HStack {
                                    Text("Scroll key:")
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Scroll Key", selection: $selectedScrollKey) {
                                        ForEach(ScrollKey.allCases, id: \.self) { key in
                                            HStack {
                                                Text(key.symbol)
                                                    .font(.system(.body, design: .monospaced))
                                                Text(key.rawValue)
                                            }
                                            .tag(key)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(width: 140)
                                    
                                    Spacer()
                                    
                                    Text(selectedScrollKey.symbol)
                                        .font(.title2)
                                        .foregroundColor(.indigo)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.indigo.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(.leading, 32)
                            }
                        }
                        
                        if enableScrolling && !useKeyboardScroll && !scrollByAreaHeight {
                            HStack {
                                Text("Scroll distance:")
                                    .foregroundColor(.secondary)
                                
                                TextField("300", text: Binding(
                                    get: { String(format: "%.0f", scrollAmount) },
                                    set: { newValue in
                                        if let value = Double(newValue), value >= 0 && value <= 2000 {
                                            scrollAmount = value
                                        }
                                    }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .multilineTextAlignment(.center)
                                .onSubmit {
                                    scrollAmount = max(0, min(2000, scrollAmount))
                                }
                                
                                Text("pixels")
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("0 - 2000px")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .padding(.leading, 20)
                        }
                        
                        if enableScrolling && useKeyboardScroll {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                Text("1 key press between each screenshot")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Text("Save Location")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(saveLocation.lastPathComponent)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        
                        Button(action: {
                            showingFilePicker = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                Text("Browse")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                            .frame(width: 16)
                        Text("Debug Logging")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $enableDebugLogging) {
                            Text("Save debug logs to file")
                                .foregroundColor(.primary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .gray))
                        .onChange(of: enableDebugLogging) { newValue in
                            captureManager.setDebugLogging(enabled: newValue, saveLocation: saveLocation)
                        }
                        
                        if enableDebugLogging {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                Text("Debug info will be saved to 'debug.txt' in the same folder as screenshots")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "textformat")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.purple)
                        Text("Filename Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.badge.plus")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 16, weight: .medium))
                                Text("Custom Text")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Prefix (before filename)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("e.g. MyApp", text: $filenamePrefix)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Suffix (after filename)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("e.g. Draft", text: $filenameSuffix)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "number.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16, weight: .medium))
                                Text("Uniqueness Method")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                if hasCustomTextOptions() {
                                    Text("Uniqueness is required when using custom text to prevent overwrites:")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .fontWeight(.medium)
                                } else {
                                    Text("How to make filenames unique when taking multiple screenshots:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Picker("Uniqueness Method", selection: $uniquenessMethod) {
                                    ForEach(UniquenessMethod.allCases, id: \.self) { method in
                                        Text(method.displayName).tag(method)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if uniquenessMethod != .none {
                                    HStack {
                                        Text("Position:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Picker("Position", selection: $uniquenessPosition) {
                                            ForEach(UniquenessPosition.allCases, id: \.self) { position in
                                                Text(position.displayName).tag(position)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .frame(width: 140)
                                        
                                        Spacer()
                                    }
                                    .padding(.top, 4)
                                }
                                
                                if uniquenessMethod == .sequential {
                                    HStack {
                                        Text("Next number:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(sequenceCounter)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                        Spacer()
                                        Button("Reset to 1") {
                                            sequenceCounter = 1
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "eye")
                                    .foregroundColor(.green)
                                    .font(.system(size: 16, weight: .medium))
                                Text("Preview")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Default (no custom options):")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                Text("Screenshot 2024-01-15 at 2.30.45 PM.png")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                
                                if hasAnyCustomOptions() {
                                    HStack {
                                        Text("With your settings:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if hasCustomTextOptions() && uniquenessMethod == .none {
                                            Text("(sequential numbering auto-applied)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                                .fontWeight(.medium)
                                        }
                                        Spacer()
                                    }
                                    .padding(.top, 4)
                                    
                                    Text(generatePreviewFilename())
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                VStack(spacing: 12) {
                    Divider()
                    
                    // Status Display
                    HStack {
                        Circle()
                            .fill(isCapturing ? Color.orange : (screenRecordingPermissionGranted ? Color.green : Color.red))
                            .frame(width: 8, height: 8)
                        
                        if isCapturing {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(captureManager.statusMessage)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        } else if !hasCheckedPermissions {
                            Text("Checking permissions...")
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        } else if !screenRecordingPermissionGranted {
                            Text("Screen recording permission required")
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                        } else {
                            Text("Ready to capture")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    // Capture Button
                    Button(action: {
                        if !screenRecordingPermissionGranted {
                            requestScreenRecordingPermission()
                        } else {
                            startCapture()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else if !screenRecordingPermissionGranted {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 18, weight: .medium))
                            } else {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 18, weight: .medium))
                            }
                            Text(isCapturing ? "Capturing..." : 
                                 (!screenRecordingPermissionGranted ? "Grant Screen Recording Permission" : "Start Area Selection"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: isCapturing ? [Color.gray.opacity(0.6), Color.gray.opacity(0.4)] : 
                                       (!screenRecordingPermissionGranted ? [Color.orange, Color.orange.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: isCapturing ? Color.clear : (!screenRecordingPermissionGranted ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3)), radius: 4, x: 0, y: 2)
                    }
                    .disabled(isCapturing || !hasCheckedPermissions)
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Instructions
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("How to use")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if !screenRecordingPermissionGranted && hasCheckedPermissions {
                            HStack {
                                Text("•")
                                    .foregroundColor(.orange)
                                Text("Grant screen recording permission to start capturing")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                            }
                        } else {
                            HStack {
                                Text("•")
                                    .foregroundColor(.blue)
                                Text("Click 'Start Area Selection' and drag to select capture area")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("•")
                                    .foregroundColor(.blue)
                                Text("Files saved with custom naming (see Filename Settings above)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("•")
                                    .foregroundColor(.blue)
                                Text("Enter precise delay values (e.g., 2.5s) for exact timing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if enableScrolling {
                                HStack {
                                    Text("•")
                                        .foregroundColor(.blue)
                                    Text("Auto-scroll enabled: \(Int(scrollAmount))px between shots")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor).opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            // Initialize delay text from current delay value
            delayText = String(format: "%.1f", delay)
            
            // Silently check permissions on app launch without prompting
            Task {
                let screenRecordingGranted = await captureManager.checkScreenRecordingPermissionsAsync()
                let accessibilityGranted = captureManager.checkAccessibilityPermissions()
                await MainActor.run {
                    screenRecordingPermissionGranted = screenRecordingGranted
                    accessibilityPermissionGranted = accessibilityGranted
                    hasCheckedPermissions = true
                }
            }
        }
        .onChange(of: delay) { newValue in
            // Update delay text when delay value changes
            delayText = String(format: "%.1f", newValue)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    saveLocation = url
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
        .sheet(isPresented: $showingAreaSelection) {
            AreaSelectionView { selectedArea in
                showingAreaSelection = false
                if let area = selectedArea {
                    performCapture(area: area)
                } else {
                    isCapturing = false
                }
            }
        }
        .alert("Screen Recording Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open System Preferences") {
                openSystemPreferences()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionMessage)
        }
        .alert("Accessibility Permission Required", isPresented: $showingAccessibilityAlert) {
            Button("Request Permission") {
                requestAccessibilityPermission()
            }
            Button("Open System Preferences") {
                openAccessibilityPreferences()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(accessibilityMessage)
        }
    }
    
    private func startCapture() {
        isCapturing = true
        
        // Check accessibility permissions first if scrolling is enabled
        if enableScrolling && !captureManager.checkAccessibilityPermissions() {
            isCapturing = false
            accessibilityMessage = "Accessibility permission is required for auto-scrolling. Please grant permission in System Preferences > Privacy & Security > Accessibility."
            showingAccessibilityAlert = true
            return
        }
        
        // Screen recording permissions should already be granted at this point
        showingAreaSelection = true
    }
    
    private func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func requestAccessibilityPermission() {
        captureManager.requestAccessibilityPermissions()
        
        // Check permission status after a delay to update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            accessibilityPermissionGranted = captureManager.checkAccessibilityPermissions()
        }
    }
    
    private func requestScreenRecordingPermission() {
        captureManager.requestPermissions { granted in
            DispatchQueue.main.async {
                screenRecordingPermissionGranted = granted
                if !granted {
                    permissionMessage = "Screen recording permission is required to capture screenshots. Please grant permission in System Preferences and try again."
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func updateDelayFromText() {
        // Parse the text and update the delay value
        if let value = Double(delayText) {
            // Clamp to valid range
            delay = max(0, min(30.0, value))
            // Update the text to show the clamped/formatted value
            delayText = String(format: "%.1f", delay)
        } else {
            // Invalid input, reset to current delay value
            delayText = String(format: "%.1f", delay)
        }
    }
    
    // MARK: - Filename Generation
    
    private var hasPrefix: Bool {
        !filenamePrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var hasSuffix: Bool {
        !filenameSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func hasAnyCustomOptions() -> Bool {
        return hasPrefix || hasSuffix
    }
    
    private func hasCustomTextOptions() -> Bool {
        return hasPrefix || hasSuffix
    }
    
    private func generatePreviewFilename() -> String {
        let baseTimestamp = "2024-01-15 at 2.30.45 PM"
        return generateFilename(usePreviewTimestamp: true, previewTimestamp: baseTimestamp)
    }
    
    private func generateFilename(usePreviewTimestamp: Bool = false, previewTimestamp: String = "") -> String {
        // If no custom options, use standard macOS screenshot naming
        if !hasAnyCustomOptions() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
            let timestamp = usePreviewTimestamp ? previewTimestamp : formatter.string(from: Date())
            return "Screenshot \(timestamp).png"
        }
        
        // Build custom filename ONLY from custom options (no timestamp)
        var filenameParts: [String] = []
        
        // Add prefix if provided
        if hasPrefix {
            let cleanPrefix = sanitizeFilename(filenamePrefix.trimmingCharacters(in: .whitespacesAndNewlines))
            filenameParts.append(cleanPrefix)
        }
        
        // Handle suffix and uniqueness positioning
        
        // When custom text options are used, uniqueness is REQUIRED
        // Default to sequential if no method is selected
        let effectiveUniquenessMethod = hasCustomTextOptions() && uniquenessMethod == .none ? .sequential : uniquenessMethod
        let hasUniqueness = effectiveUniquenessMethod != .none
        
        if hasSuffix && hasUniqueness {
            let cleanSuffix = sanitizeFilename(filenameSuffix.trimmingCharacters(in: .whitespacesAndNewlines))
            let uniqueId = generateUniqueIdentifier(usePreview: usePreviewTimestamp, method: effectiveUniquenessMethod)
            
            if uniquenessPosition == .beforeSuffix {
                // Uniqueness before suffix
                filenameParts.append(uniqueId)
                filenameParts.append(cleanSuffix)
            } else {
                // Uniqueness after suffix
                filenameParts.append(cleanSuffix)
                filenameParts.append(uniqueId)
            }
        } else if hasSuffix {
            // Only suffix, but uniqueness is required for custom options
            let cleanSuffix = sanitizeFilename(filenameSuffix.trimmingCharacters(in: .whitespacesAndNewlines))
            filenameParts.append(cleanSuffix)
            if hasCustomTextOptions() {
                let uniqueId = generateUniqueIdentifier(usePreview: usePreviewTimestamp, method: effectiveUniquenessMethod)
                filenameParts.append(uniqueId)
            }
        } else if hasUniqueness {
            // Only uniqueness, no suffix
            let uniqueId = generateUniqueIdentifier(usePreview: usePreviewTimestamp, method: effectiveUniquenessMethod)
            filenameParts.append(uniqueId)
        }
        
        // Join parts with spaces, or fallback if somehow no parts
        let filename = filenameParts.isEmpty ? "Untitled" : filenameParts.joined(separator: " ")
        return "\(filename).png"
    }
    
    private func generateUniqueIdentifier(usePreview: Bool = false, method: UniquenessMethod? = nil) -> String {
        let effectiveMethod = method ?? uniquenessMethod
        switch effectiveMethod {
        case .none:
            return ""
        case .sequential:
            return usePreview ? "1" : "\(sequenceCounter)"
        case .timestamp:
            if usePreview {
                return "14:30:45:123"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss:SSS"
                return formatter.string(from: Date())
            }
        case .random:
            if usePreview {
                return "ABC123"
            } else {
                let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                return String((0..<6).map { _ in chars.randomElement()! })
            }
        }
    }
    
    private func sanitizeFilename(_ input: String) -> String {
        // Remove or replace invalid filename characters
        let invalidChars = CharacterSet(charactersIn: "/:\"*?<>|\\")
        return input.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    private func generateUniqueFilename(baseURL: URL) -> URL {
        let filename = generateFilename()
        var finalURL = baseURL.appendingPathComponent(filename)
        
        // Ensure uniqueness to prevent overwrites (add parentheses if file exists)
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let nameWithoutExtension = (filename as NSString).deletingPathExtension
            let fileExtension = (filename as NSString).pathExtension
            let uniqueFilename = "\(nameWithoutExtension) (\(counter)).\(fileExtension)"
            finalURL = baseURL.appendingPathComponent(uniqueFilename)
            counter += 1
        }
        
        // Increment sequence counter for next capture if using sequential method
        let effectiveMethod = hasCustomTextOptions() && uniquenessMethod == .none ? .sequential : uniquenessMethod
        if effectiveMethod == .sequential {
            sequenceCounter += 1
        }
        
        return finalURL
    }
    
    private func minimizeMainWindow() {
        // Find the main app window (not overlay windows)
        for window in NSApplication.shared.windows {
            if window.title.contains("ScreenRip") || window.isMainWindow {
                window.miniaturize(nil)
                break
            }
        }
    }
    
    private func restoreMainWindow() {
        // Find and restore the minimized app window
        for window in NSApplication.shared.windows {
            if window.isMiniaturized && (window.title.contains("ScreenRip") || window.isMainWindow) {
                window.deminiaturize(nil)
                break
            }
        }
    }
    
    private func performCapture(area: CGRect) {
        // Add a small delay to let the sheet dismiss, then minimize the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.minimizeMainWindow()
        }
        
        captureManager.captureArea(
            area: area,
            delay: delay,
            count: captureCount,
            filenameGenerator: {
                return self.generateUniqueFilename(baseURL: self.saveLocation).lastPathComponent
            },
            enableScrolling: enableScrolling,
            scrollAmount: scrollAmount,
            scrollByAreaHeight: scrollByAreaHeight,
            useKeyboardScroll: useKeyboardScroll,
            scrollKey: selectedScrollKey,
            saveLocation: saveLocation
        ) { success in
            DispatchQueue.main.async {
                self.isCapturing = false
                // Restore the main window after capture completes or is cancelled
                self.restoreMainWindow()
                
                if success {
                    // Show success message
                } else {
                    // Show error message or cancellation message
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
