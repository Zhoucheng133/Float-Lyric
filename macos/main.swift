import AppKit

class FloatLyricManager {
    static let shared = FloatLyricManager()
    
    private var window: NSPanel?
    private var textField: NSTextField?
    
    private init() {}
    
    func show(lyric: String, opacity: Double, fontsize: Int32) {
        DispatchQueue.main.async {
            if self.window == nil {
                let app = NSApplication.shared
                app.setActivationPolicy(.accessory)
                
                let width: CGFloat = 600
                let height: CGFloat = 80
                
                let screen = NSScreen.main ?? NSScreen.screens.first
                let screenRect = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                let x = screenRect.origin.x + (screenRect.width - width) / 2
                let y = screenRect.origin.y + 80
                
                let panel = NSPanel(
                    contentRect: NSRect(x: x, y: y, width: width, height: height),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                
                panel.isFloatingPanel = true
                panel.level = .floating
                panel.isOpaque = false
                panel.hasShadow = true
                panel.hidesOnDeactivate = false
                panel.isMovableByWindowBackground = true
                
                let alpha = opacity > 1.0 ? opacity / 100.0 : (opacity == 1.0 ? 1.0 : opacity)
                panel.backgroundColor = NSColor.black.withAlphaComponent(max(0.0, min(1.0, alpha)))
                
                let label = NSTextField(labelWithString: lyric)
                label.textColor = .white
                label.alignment = .center
                label.font = .systemFont(ofSize: CGFloat(fontsize > 0 ? fontsize : 16))
                label.isEditable = false
                label.isSelectable = false
                label.drawsBackground = false
                
                panel.contentView = label
                panel.orderFrontRegardless()
                
                self.window = panel
                self.textField = label
            } else {
                self.updateLyric(lyric)
                self.updateOpacity(opacity)
                self.updateFontSize(fontsize)
                self.window?.orderFrontRegardless()
            }
        }
    }
    
    func hide() {
        DispatchQueue.main.async {
            self.window?.orderOut(nil)
            self.window = nil
            self.textField = nil
        }
    }
    
    func updateLyric(_ lyric: String) {
        DispatchQueue.main.async {
            self.textField?.stringValue = lyric
        }
    }
    
    func updateOpacity(_ opacity: Double) {
        DispatchQueue.main.async {
            guard let panel = self.window else { return }
            let alpha = opacity > 1.0 ? opacity / 100.0 : (opacity == 1.0 ? 1.0 : opacity)
            panel.backgroundColor = NSColor.black.withAlphaComponent(max(0.0, min(1.0, alpha)))
        }
    }
    
    func updateFontSize(_ fontsize: Int32) {
        DispatchQueue.main.async {
            guard let tf = self.textField else { return }
            let size = CGFloat(fontsize > 0 ? fontsize : 16)
            tf.font = .systemFont(ofSize: size)
        }
    }
}

private let manager = FloatLyricManager.shared

@_cdecl("ShowFloatLyric")
public func ShowFloatLyric(_ lyric: UnsafePointer<CChar>?, _ opacity: Double, _ fontsize: Int32) {
    let lyricStr = lyric != nil ? String(cString: lyric!) : ""
    manager.show(lyric: lyricStr, opacity: opacity, fontsize: fontsize)
}

@_cdecl("HideFloatLyric")
public func HideFloatLyric() {
    manager.hide()
}

@_cdecl("UpdateLyric")
public func UpdateLyric(_ lyric: UnsafePointer<CChar>?) {
    let lyricStr = lyric != nil ? String(cString: lyric!) : ""
    manager.updateLyric(lyricStr)
}

@_cdecl("UpdateOpacity")
public func UpdateOpacity(_ opacity: Double) {
    manager.updateOpacity(opacity)
}

@_cdecl("UpdateFontSize")
public func UpdateFontSize(_ fontsize: Int32) {
    manager.updateFontSize(fontsize)
}
