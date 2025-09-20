# ScreenRip

ScreenRip is a basic macOS screenshot tool with scrolling automation & keyboard macros. This is not a serious project - it was mostly built to get something working for archiving long webpages.
## Features

- **Multiple Screenshots**: Capture sequences of 1-50 screenshots with configurable timing
- **Auto-Scroll/Page Turn**: Automatically scroll between captures using scroll wheel stepping or keyboard buttons (arrows, page up/down, space, etc.)
- **Specifiable Delay**: Set precise delays between captures (0.1-30.0 seconds)
- **Basic Custom File Naming**: Add prefix/suffix text with sequential numbering or timestamp uniqueness

## System Requirements

- **macOS 13.0** or later
- **Screen Recording Permission**: Required for screenshot capture
- **Accessibility Permission**: Required for auto-scroll functionality (optional)

## Installation

### Requirements
- **Xcode 15.2** (tested version)
    - Download from: https://download.developer.apple.com/Developer_Tools/Xcode_15.2/Xcode_15.2.xip
    - Or search for other versions at: https://developer.apple.com/download/all/?q=xcode%2015.2

### Building from Source

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ScreenRip
   ```

2. **Open and build**
   - Open Xcode
   - Open the `ScreenRip.xcodeproj` file
   - Press `Cmd+R` to build and run

## Usage

1. **Launch and Setup Permissions**
   - Launch ScreenRip
   - Grant Screen Recording permission in System Settings when prompted
   - Grant Accessibility permission for scrolling features (optional)
   - May need to restart the app after granting permissions

2. **Configure Capture Settings**
   - Set number of screenshots to capture
   - Choose scrolling options (scroll wheel or keyboard buttons)
   - Set delay between captures
   - Configure file name options (prefix, suffix, numbering)

3. **Start Capture**
   - Click "Start Area Selection"
   - Draw selection rectangle around the area to capture
   - If using scrolling, click inside the target window to ensure it's in focus before the first screenshot is taken
   - Capture begins automatically after the specified delay

## Debug

Enable debug logging in the app to generate detailed logs saved as 'debug.txt' in your screenshot folder. Logs include permission status, capture coordinates, scroll events, and error messages.

## License

This project is provided as-is for educational and personal use.

## Contributing

Contributions are welcome. Feel free to fork the repository or submit pull requests.
