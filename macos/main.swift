import AppKit

public typealias CloseCallback = @convention(c) () -> Void

class FloatLyricContainerView: NSView {
    weak var closeButton: NSView?
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            closeButton?.animator().alphaValue = 1.0
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            closeButton?.animator().alphaValue = 0.0
        }
    }
}

class FloatCloseButton: NSView {
    var target: AnyObject?
    var action: Selector?
    
    private let label = NSTextField(labelWithString: "×")
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 4.0
        layer?.backgroundColor = NSColor.clear.cgColor
        
        label.textColor = .white
        label.alignment = .center
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(
                equalTo: centerYAnchor,
                constant: -1
            )
        ])
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            layer?.backgroundColor = NSColor.red.cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let target = target, let action = action {
            _ = target.perform(action, with: self)
        }
    }
}

class FloatLyricManager {
    static let shared = FloatLyricManager()
    
    private var window: NSPanel?
    private var textField: NSTextField?
    private var closeCallback: CloseCallback?
    
    private init() {}
    
    func setCloseCallback(_ callback: @escaping CloseCallback) {
        self.closeCallback = callback
    }
    
    func show(lyric: String, opacity: Double, fontsize: Int32) {
        DispatchQueue.main.async {
            if self.window == nil {
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
                panel.hasShadow = false
                panel.hidesOnDeactivate = false
                panel.isMovableByWindowBackground = true
                
                let alpha = max(0.0, min(1.0, opacity / 100.0))
                panel.backgroundColor = NSColor.black.withAlphaComponent(alpha)
                
                let container = FloatLyricContainerView(frame: NSRect(x: 0, y: 0, width: width, height: height))
                
                let label = NSTextField(labelWithString: lyric)
                label.textColor = .white
                label.alignment = .center
                label.font = .systemFont(ofSize: CGFloat(fontsize > 0 ? fontsize : 16))
                label.isEditable = false
                label.isSelectable = false
                label.drawsBackground = false
                label.translatesAutoresizingMaskIntoConstraints = false
                
                container.addSubview(label)
                
                let closeButton = FloatCloseButton(frame: .zero)
                closeButton.target = self
                closeButton.action = #selector(self.handleCloseClick)
                closeButton.alphaValue = 0.0
                closeButton.translatesAutoresizingMaskIntoConstraints = false
                
                container.closeButton = closeButton
                container.addSubview(closeButton)
                
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    label.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -60),
                    
                    closeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                    closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                    closeButton.widthAnchor.constraint(equalToConstant: 24),
                    closeButton.heightAnchor.constraint(equalToConstant: 24)
                ])
                
                panel.contentView = container
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
    
    @objc private func handleCloseClick() {
        hide()
        closeCallback?()
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
            let alpha = max(0.0, min(1.0, opacity / 100.0))
            panel.backgroundColor = NSColor.black.withAlphaComponent(alpha)
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

@_cdecl("RegisterCloseCallback")
public func RegisterCloseCallback(_ callback: @convention(c) @escaping () -> Void) {
    manager.setCloseCallback(callback)
}
