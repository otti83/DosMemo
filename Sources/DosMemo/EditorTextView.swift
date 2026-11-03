import AppKit

final class EditorTextView: NSTextView {
    var onZoom: ((CGFloat) -> Void)?

    private var zoomAccumulator: CGFloat = 0
    private let zoomThreshold: CGFloat = 4.0

    override func scrollWheel(with event: NSEvent) {
        let mods = event.modifierFlags
        if (mods.contains(.command) || mods.contains(.control)) && onZoom != nil {
            zoomAccumulator += event.scrollingDeltaY
            while zoomAccumulator >= zoomThreshold {
                onZoom?(1)
                zoomAccumulator -= zoomThreshold
            }
            while zoomAccumulator <= -zoomThreshold {
                onZoom?(-1)
                zoomAccumulator += zoomThreshold
            }
            return
        }
        super.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        guard onZoom != nil else {
            super.magnify(with: event)
            return
        }
        zoomAccumulator += event.magnification * 20
        while zoomAccumulator >= zoomThreshold {
            onZoom?(1)
            zoomAccumulator -= zoomThreshold
        }
        while zoomAccumulator <= -zoomThreshold {
            onZoom?(-1)
            zoomAccumulator += zoomThreshold
        }
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        return [.string]
    }
}
