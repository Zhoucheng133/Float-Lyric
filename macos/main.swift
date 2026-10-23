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
        
        label.textColor = NSColor.gray
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
    private var strokeTextField: NSTextField?
    private var fillTextField: NSTextField?
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
                
                let fontSize = CGFloat(fontsize > 0 ? fontsize : 16)
                let font = NSFont.systemFont(ofSize: fontSize)
                let strokeColor = NSColor(red: 24/255.0, green: 144/255.0, blue: 255/255.0, alpha: 1.0)
                
                let strokeLabel = NSTextField(labelWithString: "")
                let strokeAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.clear,
                    .strokeWidth: 3.0,
                    .strokeColor: strokeColor
                ]
                strokeLabel.attributedStringValue = NSAttributedString(string: lyric, attributes: strokeAttributes)
                strokeLabel.alignment = .center
                strokeLabel.isEditable = false
                strokeLabel.isSelectable = false
                strokeLabel.drawsBackground = false
                strokeLabel.translatesAutoresizingMaskIntoConstraints = false
                
                let fillLabel = NSTextField(labelWithString: lyric)
                fillLabel.textColor = .white
                fillLabel.alignment = .center
                fillLabel.font = font
                fillLabel.isEditable = false
                fillLabel.isSelectable = false
                fillLabel.drawsBackground = false
                fillLabel.translatesAutoresizingMaskIntoConstraints = false
                
                container.addSubview(strokeLabel)
                container.addSubview(fillLabel)
                
                let closeButton = FloatCloseButton(frame: .zero)
                closeButton.target = self
                closeButton.action = #selector(self.handleCloseClick)
                closeButton.alphaValue = 0.0
                closeButton.translatesAutoresizingMaskIntoConstraints = false
                
                container.closeButton = closeButton
                container.addSubview(closeButton)
                
                NSLayoutConstraint.activate([
                    strokeLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    strokeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    strokeLabel.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -60),
                    
                    fillLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    fillLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    fillLabel.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -60),
                    
                    closeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                    closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                    closeButton.widthAnchor.constraint(equalToConstant: 24),
                    closeButton.heightAnchor.constraint(equalToConstant: 24)
                ])
                
                panel.contentView = container
                panel.orderFrontRegardless()
                
                self.window = panel
                self.strokeTextField = strokeLabel
                self.fillTextField = fillLabel
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
            self.strokeTextField = nil
            self.fillTextField = nil
        }
    }
    
    func updateLyric(_ lyric: String) {
        DispatchQueue.main.async {
            let font = self.fillTextField?.font ?? NSFont.systemFont(ofSize: 16)
            let strokeColor = NSColor(red: 24/255.0, green: 144/255.0, blue: 255/255.0, alpha: 1.0)
            let strokeAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.clear,
                .strokeWidth: 3.0,
                .strokeColor: strokeColor
            ]
            self.strokeTextField?.attributedStringValue = NSAttributedString(string: lyric, attributes: strokeAttributes)
            self.fillTextField?.stringValue = lyric
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
            let size = CGFloat(fontsize > 0 ? fontsize : 16)
            let font = NSFont.systemFont(ofSize: size)
            
            let strokeColor = NSColor(red: 24/255.0, green: 144/255.0, blue: 255/255.0, alpha: 1.0)
            let strokeAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.clear,
                .strokeWidth: 3.0,
                .strokeColor: strokeColor
            ]
            
            if let currentText = self.fillTextField?.stringValue {
                self.strokeTextField?.attributedStringValue = NSAttributedString(string: currentText, attributes: strokeAttributes)
            }
            self.fillTextField?.font = font
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
