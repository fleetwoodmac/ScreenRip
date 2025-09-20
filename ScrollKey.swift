import Foundation
import CoreGraphics

// Enum for scroll key options
enum ScrollKey: String, CaseIterable {
    case downArrow = "Down Arrow"
    case upArrow = "Up Arrow"
    case pageDown = "Page Down"
    case pageUp = "Page Up"
    case spaceBar = "Space Bar"
    case enter = "Enter"
    case j = "J Key"
    case k = "K Key"
    
    var keyCode: CGKeyCode {
        switch self {
        case .downArrow: return 0x7D
        case .upArrow: return 0x7E
        case .pageDown: return 0x79
        case .pageUp: return 0x74
        case .spaceBar: return 0x31
        case .enter: return 0x24
        case .j: return 0x26
        case .k: return 0x28
        }
    }
    
    var symbol: String {
        switch self {
        case .downArrow: return "↓"
        case .upArrow: return "↑"
        case .pageDown: return "⇟"
        case .pageUp: return "⇞"
        case .spaceBar: return "␣"
        case .enter: return "⏎"
        case .j: return "J"
        case .k: return "K"
        }
    }
}

