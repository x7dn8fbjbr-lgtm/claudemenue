import SwiftUI
import AppKit

private class PlaceholderTextView: NSTextView {
    var placeholder: String = "" {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty else { return }
        let inset = textContainerInset
        let padding = textContainer?.lineFragmentPadding ?? 5
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        NSAttributedString(string: placeholder, attributes: attrs)
            .draw(at: NSPoint(x: inset.width + padding, y: inset.height))
    }
}

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isDisabled: Bool
    var onSubmit: () -> Void
    var onClose: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let textView = PlaceholderTextView()
        textView.placeholder = "Was liegt dir auf dem Herzen?"
        textView.minSize = NSSize(width: 0, height: 80)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor(white: 0.15, alpha: 1)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = !isDisabled
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.3
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor(white: 0.15, alpha: 1),
            .paragraphStyle: paragraphStyle
        ]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Always update callbacks so coordinator never holds stale closures
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onClose = onClose
        textView.isEditable = !isDisabled
        if textView.string != text {
            let sel = textView.selectedRange()
            textView.string = text
            context.coordinator.applyMarkdown(to: textView)
            textView.setSelectedRange(sel)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 560, height: 120)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, onClose: onClose)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        var onClose: () -> Void
        private var isApplyingMarkdown = false
        private var eventMonitor: Any?

        init(text: Binding<String>, onSubmit: @escaping () -> Void, onClose: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
            self.onClose = onClose
            super.init()
            // keyCode 36 = Return
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == 36, event.modifierFlags.contains(.command) {
                    self.onSubmit()
                    return nil
                }
                if event.keyCode == 53 { // Escape
                    self.onClose()
                    return nil
                }
                return event
            }
        }

        deinit {
            if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingMarkdown, let tv = notification.object as? NSTextView else { return }
            text = tv.string
            applyMarkdown(to: tv)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onClose()
                return true
            }
            return false
        }

        func applyMarkdown(to textView: NSTextView) {
            guard !isApplyingMarkdown, let storage = textView.textStorage else { return }
            isApplyingMarkdown = true
            defer { isApplyingMarkdown = false }

            let sel = textView.selectedRange()
            let fullRange = NSRange(location: 0, length: storage.length)

            storage.beginEditing()
            storage.setAttributes([
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.textColor
            ], range: fullRange)

            // **bold**
            if let re = try? NSRegularExpression(pattern: "\\*\\*[^*\n]+\\*\\*") {
                re.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
                    if let r = match?.range {
                        storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 16), range: r)
                    }
                }
            }

            // *italic* (not **)
            if let re = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)[^*\n]+(?<!\\*)\\*(?!\\*)") {
                re.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
                    if let r = match?.range {
                        let italic = NSFontManager.shared.convert(.systemFont(ofSize: 16), toHaveTrait: .italicFontMask)
                        storage.addAttribute(.font, value: italic, range: r)
                    }
                }
            }

            storage.endEditing()
            textView.setSelectedRange(sel)
        }
    }
}
