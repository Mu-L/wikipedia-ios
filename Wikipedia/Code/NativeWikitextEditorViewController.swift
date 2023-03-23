import UIKit

protocol NativeWikitextEditorDelegate: AnyObject {
    func wikitextViewDidChange(_ textView: UITextView)
}

class NativeWikitextEditorViewController: UIViewController, Themeable {
    
    weak var delegate: NativeWikitextEditorDelegate?
    private let theme: Theme
    
    private lazy var editorInputViewsController: EditorInputViewsController = {
        let inputViewsController = EditorInputViewsController(webView: nil, webMessagingController: nil, findAndReplaceDisplayDelegate: self)
        inputViewsController.delegate = self
        
        return inputViewsController
    }()
    
    private var editorView: NativeWikitextEditorView {
        return view as! NativeWikitextEditorView
    }
    
    init(delegate: NativeWikitextEditorDelegate, theme: Theme) {
        self.delegate = delegate
        self.theme = theme
        
        super.init(nibName: nil, bundle: nil)
        
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIApplication.keyboardWillChangeFrameNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIApplication.keyboardWillHideNotification,
                                               object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let editorView = NativeWikitextEditorView(theme: theme)
//        if #available(iOS 16.0, *) {
//            editorView.textView.textContentStorage?.delegate = self
//        }
        editorView.textView.delegate = self
        view = editorView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    override var inputViewController: UIInputViewController? {
        return editorInputViewsController.inputViewController
    }
    
    // MARK: Public
    
    func setupInitialText(_ text: String) {
        
        guard self.editorView.textView.text.count == 0 else {
            assertionFailure("Initial text should only be set once.")
            return
        }
        
        self.editorView.textView.text = text
    }
    
    func undo() {
        editorView.textView.undoManager?.undo()
    }
    
    func redo() {
        editorView.textView.undoManager?.redo()
    }
    
    func setInputAccessoryView(_ inputAccessoryView: UIView?) {
        editorView.textView.inputAccessoryView = inputAccessoryView
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        updateInsets(keyboardHeight: 0)
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = max(frame.height - view.safeAreaInsets.bottom, 0)
            updateInsets(keyboardHeight: keyboardHeight)
        }
    }

    private func updateInsets(keyboardHeight: CGFloat) {
        editorView.textView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        editorView.textView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
    }
    
    func apply(theme: Theme) {
        editorInputViewsController.apply(theme: theme)
        editorView.apply(theme: theme)
    }
}

extension NativeWikitextEditorViewController: NSTextContentStorageDelegate {
    @available(iOS 15.0, *)
    func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange) -> NSTextParagraph? {
        guard let originalText = textContentStorage.textStorage?.attributedSubstring(from: range),
              originalText.length > 0 else {
            return nil
        }
        let textWithDisplayAttributes = NSMutableAttributedString(attributedString: originalText)
        textWithDisplayAttributes.addWikitextSyntaxFormatting(withSearch: NSRange(location: 0, length: originalText.length), fontSizeTraitCollection: traitCollection, needsColors: true, theme: theme)
        return NSTextParagraph(attributedString: textWithDisplayAttributes)
    }
}

extension NativeWikitextEditorViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        // pageEditorInputViewsController.textSelectionDidChange(isRangeSelected: textView.selectedTextRange?.isEmpty ?? false)
        // todo: tell delegate that textView has changed. It can determine it's own publish button states. (in the case of talk page new topic, title field and this text view > 0, in the case of article editor, just this field > 0
        // publishButton.isEnabled = bodyTextView.textStorage.length == 0 ? false : true
        // formattingToolbarView.undoButton.isEnabled = textView.undoManager?.canUndo ?? false
        // formattingToolbarView.redoButton.isEnabled = textView.undoManager?.canRedo ?? false
        delegate?.wikitextViewDidChange(textView)
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        editorInputViewsController.textSelectionDidChange(isRangeSelected: textView.selectedRange.length > 0)
        
        if selectedTextRangeOrCursorIsBold {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .bold))
        }
        
        if selectedTextRangeOrCursorIsItalic {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .italic))
        }
        
        if selectedTextRangeOrCursorIsTemplate {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .template))
        }
        
        if selectedTextRangeOrCursorIsReference {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .reference))
        }
        
        if selectedTextRangeOrCursorIsSuperscript {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .superscript))
        }
        
        if selectedTextRangeOrCursorIsSubscript {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .subscript))
        }
        
        if selectedTextRangeOrCursorIsUnderline {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .underline))
        }
        
        if selectedTextRangeOrCursorIsStrikethrough {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .strikethrough))
        }
        
        if selectedTextRangeOrCursorIsListBullet {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .li(ordered: false)))
            // todo: why aren't indent buttons enabling?
        } else {
            editorInputViewsController.disableButton(button: EditorButton(kind: .increaseIndentDepth))
            editorInputViewsController.disableButton(button: EditorButton(kind: .decreaseIndentDepth))
        }
        
        if selectedTextRangeOrCursorIsListNumber {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .li(ordered: true)))
            // todo: why aren't indent buttons enabling?
        } else {
            editorInputViewsController.disableButton(button: EditorButton(kind: .increaseIndentDepth))
            editorInputViewsController.disableButton(button: EditorButton(kind: .decreaseIndentDepth))
        }
        
        if selectedTextRangeOrCursorIsH2 {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .heading(type: .heading)))
        }
        
        if selectedTextRangeOrCursorIsH3 {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .heading(type: .subheading1)))
        }
        
        if selectedTextRangeOrCursorIsH4 {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .heading(type: .subheading2)))
        }
        
        if selectedTextRangeOrCursorIsH5 {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .heading(type: .subheading3)))
        }
        
        if selectedTextRangeOrCursorIsH6 {
            editorInputViewsController.buttonSelectionDidChange(button: EditorButton(kind: .heading(type: .subheading4)))
        }
    }
}


extension NativeWikitextEditorViewController: EditorInputViewsControllerDelegate {
    func editorInputViewsControllerDidTapBold(_ editorInputViewsController: EditorInputViewsController) {
        let formattingString = "'''"
        let isBold = selectedTextRangeOrCursorIsBold
        addOrRemoveFormattingStringFromSelectedText(formattingString: formattingString, shouldAddFormatting: !isBold)
    }
    
    func editorInputViewsControllerDidTapItalic(_ editorInputViewsController: EditorInputViewsController) {
        let formattingString = "''"
        let isItalic = selectedTextRangeOrCursorIsItalic
        addOrRemoveFormattingStringFromSelectedText(formattingString: formattingString, shouldAddFormatting: !isItalic)
    }
    
    func editorInputViewsControllerDidTapTemplate(_ editorInputViewsController: EditorInputViewsController) {
        let isTemplate = selectedTextRangeOrCursorIsTemplate
        addOrRemoveFormattingStringFromSelectedText(startingFormattingString: "{{", endingFormattingString: "}}", shouldAddFormatting: !isTemplate)
    }
    
    func editorInputViewsControllerDidTapReference(_ editorInputViewsController: EditorInputViewsController) {
        let isReference = selectedTextRangeOrCursorIsReference
        addOrRemoveFormattingStringFromSelectedText(startingFormattingString: "<ref>", endingFormattingString: "</ref>", shouldAddFormatting: !isReference)
    }
    
    func editorInputViewsControllerDidTapSuperscript(_ editorInputViewsController: EditorInputViewsController) {
        let isSuperscript = selectedTextRangeOrCursorIsSuperscript
        addOrRemoveFormattingStringFromSelectedText(startingFormattingString: "<sup>", endingFormattingString: "</sup>", shouldAddFormatting: !isSuperscript)
    }
    
    func editorInputViewsControllerDidTapSubscript(_ editorInputViewsController: EditorInputViewsController) {
        let isSubscript = selectedTextRangeOrCursorIsSubscript
        addOrRemoveFormattingStringFromSelectedText(startingFormattingString: "<sub>", endingFormattingString: "</sub>", shouldAddFormatting: !isSubscript)
    }
    
    func editorInputViewsControllerDidTapUnderline(_ editorInputViewsController: EditorInputViewsController) {
        let isUnderline = selectedTextRangeOrCursorIsUnderline
        addOrRemoveFormattingStringFromSelectedText(startingFormattingString: "<u>", endingFormattingString: "</u>", shouldAddFormatting: !isUnderline)
    }
    
    func editorInputViewsControllerDidTapStrikethrough(_ editorInputViewsController: EditorInputViewsController) {
        let isStrikethrough = selectedTextRangeOrCursorIsStrikethrough
        addOrRemoveFormattingStringFromSelectedText(startingFormattingString: "<s>", endingFormattingString: "</s>", shouldAddFormatting: !isStrikethrough)
    }
    
    func editorInputViewsControllerDidTapListBullet(_ editorInputViewsController: EditorInputViewsController) {
        let textView = editorView.textView
        
        let nsString = textView.attributedText.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange)
        if selectedTextRangeOrCursorIsListBullet {
            var numBullets = 0
            for char in textView.textStorage.attributedSubstring(from: lineRange).string {
                if char == "*" {
                    numBullets += 1
                }
            }
            textView.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: numBullets), with: "")
            // reset cursor so it doesn't move
            if let selectedRange = textView.selectedTextRange {
                if let newStart = textView.position(from: selectedRange.start, offset: -1*numBullets),
                let newEnd = textView.position(from: selectedRange.end, offset: -1*numBullets) {
                    textView.selectedTextRange = textView.textRange(from: newStart, to: newEnd)
                }
            }
            
        } else {
            textView.textStorage.insert(NSAttributedString(string: "*"), at: lineRange.location)
            // reset cursor so it doesn't move
            if let selectedRange = textView.selectedTextRange {
                if let newStart = textView.position(from: selectedRange.start, offset: 1),
                let newEnd = textView.position(from: selectedRange.end, offset: 1) {
                    textView.selectedTextRange = textView.textRange(from: newStart, to: newEnd)
                }
            }
        }
        
        textViewDidChange(textView)
        textViewDidChangeSelection(textView)
    }
    
    func editorInputViewsControllerDidTapListNumber(_ editorInputViewsController: EditorInputViewsController) {
        let textView = editorView.textView
        
        let nsString = textView.attributedText.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange)
        if selectedTextRangeOrCursorIsListNumber {
            var numNumbers = 0
            for char in textView.textStorage.attributedSubstring(from: lineRange).string {
                if char == "#" {
                    numNumbers += 1
                }
            }
            textView.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: numNumbers), with: "")
            // reset cursor so it doesn't move
            if let selectedRange = textView.selectedTextRange {
                if let newStart = textView.position(from: selectedRange.start, offset: -1*numNumbers),
                let newEnd = textView.position(from: selectedRange.end, offset: -1*numNumbers) {
                    textView.selectedTextRange = textView.textRange(from: newStart, to: newEnd)
                }
            }
            
        } else {
            textView.textStorage.insert(NSAttributedString(string: "#"), at: lineRange.location)
            // reset cursor so it doesn't move
            if let selectedRange = textView.selectedTextRange {
                if let newStart = textView.position(from: selectedRange.start, offset: 1),
                let newEnd = textView.position(from: selectedRange.end, offset: 1) {
                    textView.selectedTextRange = textView.textRange(from: newStart, to: newEnd)
                }
            }
        }
        
        textViewDidChange(textView)
        textViewDidChangeSelection(textView)
    }
    
    func editorInputViewsControllerDidTapIndent(_ editorInputViewsController: EditorInputViewsController) {
        guard selectedTextRangeOrCursorIsListBullet || selectedTextRangeOrCursorIsListNumber else {
            assertionFailure("Button should have been disabled")
            return
        }
        
        let textView = editorView.textView
        
        let nsString = textView.attributedText.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange)
        
        textView.textStorage.insert(NSAttributedString(string: "*"), at: lineRange.location)
        // reset cursor so it doesn't move
        if let selectedRange = textView.selectedTextRange {
            if let newStart = textView.position(from: selectedRange.start, offset: 1),
            let newEnd = textView.position(from: selectedRange.end, offset: 1) {
                textView.selectedTextRange = textView.textRange(from: newStart, to: newEnd)
            }
        }
    }
    
    func editorInputViewsControllerDidTapUnindent(_ editorInputViewsController: EditorInputViewsController) {
        guard selectedTextRangeOrCursorIsListNumber || selectedTextRangeOrCursorIsListNumber else {
            assertionFailure("Button should have been disabled")
            return
        }
        
        let textView = editorView.textView
        
        let nsString = textView.attributedText.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange)
        
        textView.textStorage.insert(NSAttributedString(string: ""), at: lineRange.location)
        // reset cursor so it doesn't move
        if let selectedRange = textView.selectedTextRange {
            if let newStart = textView.position(from: selectedRange.start, offset: 1),
            let newEnd = textView.position(from: selectedRange.end, offset: 1) {
                textView.selectedTextRange = textView.textRange(from: newStart, to: newEnd)
            }
        }
    }
    
    func editorInputViewsControllerDidTapHeading(_ editorInputViewsController: EditorInputViewsController, depth: Int) {
        
        let isCurrentlyH2 = selectedTextRangeOrCursorIsH2
        let isCurrentlyH3 = selectedTextRangeOrCursorIsH3
        let isCurrentlyH4 = selectedTextRangeOrCursorIsH4
        let isCurrentlyH5 = selectedTextRangeOrCursorIsH5
        let isCurrentlyH6 = selectedTextRangeOrCursorIsH6
        
        let formattingToRemove: String?
        if isCurrentlyH2 && depth != 2 {
            formattingToRemove = "=="
        } else if isCurrentlyH3 && depth != 3 {
            formattingToRemove = "==="
        } else if isCurrentlyH4 && depth != 4 {
            formattingToRemove = "===="
        } else if isCurrentlyH5 && depth != 5 {
            formattingToRemove = "====="
        } else if isCurrentlyH6 && depth != 6 {
            formattingToRemove = "======"
        } else {
            formattingToRemove = nil
        }
        
        let formattingToAdd: String?
        if !isCurrentlyH2 && depth == 2 {
            formattingToAdd = "=="
        } else if !isCurrentlyH3 && depth == 3 {
            formattingToAdd = "==="
        } else if !isCurrentlyH4 && depth == 4 {
            formattingToAdd = "===="
        } else if !isCurrentlyH5 && depth == 5 {
            formattingToAdd = "====="
        } else if !isCurrentlyH6 && depth == 6 {
            formattingToAdd = "======"
        } else {
            formattingToAdd = nil
        }
        
        guard formattingToRemove != nil || formattingToAdd != nil else {
            return
        }
        
        if let formattingToRemove {
            expandSelectedRangeUpToNearestFormattingStrings(startingFormattingString: formattingToRemove, endingFormattingString: formattingToRemove)
            if selectedRangeIsSurroundedByFormattingString(formattingString: formattingToRemove) {
                removeSurroundingFormattingStringFromSelectedRange(formattingString: formattingToRemove)
            }
        }
        
        if let formattingToAdd {
            addStringFormattingCharacters(formattingString: formattingToAdd)
        }
    }
    
    func editorInputViewsControllerDidChangeInputAccessoryView(_ editorInputViewsController: EditorInputViewsController, inputAccessoryView: UIView?) {
        editorView.textView.inputAccessoryView = inputAccessoryView
        editorView.textView.reloadInputViews()
    }
    
    func editorInputViewsControllerDidTapMediaInsert(_ editorInputViewsController: EditorInputViewsController) {
        print("tell delegate to present media insert)")
    }
    
    func editorInputViewsControllerDidTapLinkInsert(_ editorInputViewsController: EditorInputViewsController) {
        print("tell delegate to present link insert)")
    }
}

extension NativeWikitextEditorViewController: FindAndReplaceKeyboardBarDisplayDelegate {
    func keyboardBarDidTapReplaceSwitch(_ keyboardBar: FindAndReplaceKeyboardBar) {
        print("replace in text storage")
    }
    
    func keyboardBarDidShow(_ keyboardBar: FindAndReplaceKeyboardBar) {
        print("??")
    }
    
    func keyboardBarDidHide(_ keyboardBar: FindAndReplaceKeyboardBar) {
        print("??")
    }
}

// MARK: Selection Formatting Determination Methods

private extension NativeWikitextEditorViewController {
    
    func targetSelectedRangeAndAttributedText() -> (NSRange, NSAttributedString)? {
        
        let textView = editorView.textView
        
        // Expand selected range before evaluating if necessary
        var selectedRange = textView.selectedRange
        
        if selectedRange.length == 0,
           selectedRange.location > 0,
           textView.attributedText.length > 1,
           textView.attributedText.length > textView.selectedRange.location + 1 {
            
            selectedRange = NSRange(location: textView.selectedRange.location - 1, length: 2)
        }

//        if #available(iOS 16.0, *) {
//
//            if let textRange = textView.textLayoutManager?.textSelections.first?.textRanges.first {
//
//                if let paragraphElement = textView.textLayoutManager?.textLayoutFragment(for: textRange.location)?.textElement as? NSTextParagraph,
//                   let contentManager = textView.textContentStorage {
//
//                    let targetAttributedText = paragraphElement.attributedString
//                    if let paragraphContentRange = paragraphElement.paragraphContentRange {
//                        let paragraphContentNSRange = NSRange(paragraphContentRange, in: contentManager)
//                        let targetSelectedRange = NSRange(location: selectedRange.location - paragraphContentNSRange.location, length: selectedRange.length)
//                        guard targetSelectedRange.location >= 0 else {
//                            return nil
//                        }
//                        return (targetSelectedRange, targetAttributedText)
//                    }
//                }
//            }
//
//            return nil
//
//        } else {
            return (selectedRange, textView.attributedText)
        // }
    }
    
    func selectedTextRangeOrCursorIsAttributeKey(_ attributeKey: NSAttributedString.Key) -> Bool {
        if let targetSelectionValues = targetSelectedRangeAndAttributedText() {
            
            let range = targetSelectionValues.0
            let attributedString = targetSelectionValues.1
            
            var isAttribute = false
            attributedString.enumerateAttribute(attributeKey, in: range, options: .longestEffectiveRangeNotRequired) { value, range, stop in
                if let value = value as? NSNumber,
                   value.boolValue == true {
                    isAttribute = true
                    stop.pointee = true
                } else {
                    isAttribute = false
                    stop.pointee = true
                }
            }
                    
            return isAttribute
        }
        
        return false
    }
    
    var selectedTextRangeOrCursorIsBold: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextBoldAndItalic) || selectedTextRangeOrCursorIsAttributeKey(.wikitextBold)
    }
    
    var selectedTextRangeOrCursorIsItalic: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextBoldAndItalic) || selectedTextRangeOrCursorIsAttributeKey(.wikitextItalic)
    }
    
    var selectedTextRangeOrCursorIsH2: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextH2)
    }
    
    var selectedTextRangeOrCursorIsH3: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextH3)
    }
    
    var selectedTextRangeOrCursorIsH4: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextH4)
    }
    
    var selectedTextRangeOrCursorIsH5: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextH5)
    }
    
    var selectedTextRangeOrCursorIsH6: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextH6)
    }
    
    var selectedTextRangeOrCursorIsTemplate: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextTemplate)
    }
    
    var selectedTextRangeOrCursorIsReference: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextRef)
    }
    
    var selectedTextRangeOrCursorIsSuperscript: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextSuperscript)
    }
    
    var selectedTextRangeOrCursorIsSubscript: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextSubscript)
    }
    
    var selectedTextRangeOrCursorIsUnderline: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextUnderline)
    }
    
    var selectedTextRangeOrCursorIsStrikethrough: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextStrikethrough)
    }
    
    var selectedTextRangeOrCursorIsListBullet: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextListBullet)
    }
    
    var selectedTextRangeOrCursorIsListNumber: Bool {
        return selectedTextRangeOrCursorIsAttributeKey(.wikitextListNumber)
    }
}

// MARK: Programmatic Selection Methods

private extension NativeWikitextEditorViewController {
    
    func addOrRemoveFormattingStringFromSelectedText(formattingString: String, shouldAddFormatting: Bool) {
        if !shouldAddFormatting {
            expandSelectedRangeUpToNearestFormattingStrings(startingFormattingString: formattingString, endingFormattingString: formattingString)
            if selectedRangeIsSurroundedByFormattingString(formattingString: formattingString) {
                removeSurroundingFormattingStringFromSelectedRange(formattingString: formattingString)
            }
        } else {
            addStringFormattingCharacters(formattingString: formattingString)
        }
    }
    
    func addOrRemoveFormattingStringFromSelectedText(startingFormattingString: String, endingFormattingString: String, shouldAddFormatting: Bool) {
        if !shouldAddFormatting {
            expandSelectedRangeUpToNearestFormattingStrings(startingFormattingString: startingFormattingString, endingFormattingString: endingFormattingString)
            if selectedRangeIsSurroundedByFormattingString(startingFormattingString: startingFormattingString, endingFormattingString: endingFormattingString) {
                removeSurroundingFormattingStringFromSelectedRange(startingFormattingString: startingFormattingString, endingFormattingString: endingFormattingString)
            }
        } else {
            addStringFormattingCharacters(startingFormattingString: startingFormattingString, endingFormattingString: endingFormattingString)
        }
    }
    
    func expandSelectedRangeUpToNearestFormattingStrings(startingFormattingString: String, endingFormattingString: String) {
        
        let textView = editorView.textView
        
        if let textPositions = textPositionsConsideringNearestFormattingStrings(startingFormattingString: startingFormattingString, endingFormattingString: endingFormattingString) {
            textView.selectedTextRange = textView.textRange(from: textPositions.startRange, to: textPositions.endRange)
        }
    }
    
    func textPositionsConsideringNearestFormattingStrings(startingFormattingString: String, endingFormattingString: String) -> (startRange: UITextPosition, endRange: UITextPosition)? {
        
        let textView = editorView.textView
        
        guard let originalSelectedRange = textView.selectedTextRange else {
            return nil
        }
        
        let breakOnOppositeTag = startingFormattingString != endingFormattingString
        
        // loop backwards to find start
        var i = 0
        var finalStart: UITextPosition?
        while let newStart = textView.position(from: originalSelectedRange.start, offset: i) {
            let newRange = textView.textRange(from: newStart, to: originalSelectedRange.end)

            if rangeIsPrecededByFormattingString(range: newRange, formattingString: startingFormattingString) {

                finalStart = newStart
                break
            }
            
            if rangeIsPrecededByFormattingString(range: newRange, formattingString: "\n") {
                break
            }
            
            if breakOnOppositeTag && rangeIsPrecededByFormattingString(range: newRange, formattingString: endingFormattingString) {
                break
            }
            
            i = i - 1
        }
        
        // loop forwards to find end
        i = 0
        var finalEnd: UITextPosition?
        while let newEnd = textView.position(from: originalSelectedRange.end, offset: i) {
            let newRange = textView.textRange(from: originalSelectedRange.start, to: newEnd)
            
            if rangeIsFollowedByFormattingString(range: newRange, formattingString: endingFormattingString) {

                finalEnd = newEnd
                break
            }
            
            if rangeIsFollowedByFormattingString(range: newRange, formattingString: "\n") {
                break
            }
            
            if breakOnOppositeTag && rangeIsFollowedByFormattingString(range: newRange, formattingString: startingFormattingString) {
                break
            }
            
            i = i + 1
        }
        
        // Select new range
        guard let finalStart = finalStart,
                  let finalEnd = finalEnd else {
                      return nil
                  }
        
        return (finalStart, finalEnd)
    }
    
    func selectedRangeIsSurroundedByFormattingString(startingFormattingString: String, endingFormattingString: String) -> Bool {
        let textView = editorView.textView
        return rangeIsPrecededByFormattingString(range: textView.selectedTextRange, formattingString: startingFormattingString) && rangeIsFollowedByFormattingString(range: textView.selectedTextRange, formattingString: endingFormattingString)
    }
    
    func selectedRangeIsSurroundedByFormattingString(formattingString: String) -> Bool {
        let textView = editorView.textView
        
        return rangeIsPrecededByFormattingString(range: textView.selectedTextRange, formattingString: formattingString) && rangeIsFollowedByFormattingString(range: textView.selectedTextRange, formattingString: formattingString)
    }
    
    func rangeIsPrecededByFormattingString(range: UITextRange?, formattingString: String) -> Bool {
        let textView = editorView.textView
        guard let range = range,
              let newStart = textView.position(from: range.start, offset: -formattingString.count) else {
            return false
        }
        
        guard let startingRange = textView.textRange(from: newStart, to: range.start),
              let startingString = textView.text(in: startingRange) else {
            return false
        }
        
        return startingString == formattingString
    }
    
    func rangeIsFollowedByFormattingString(range: UITextRange?, formattingString: String) -> Bool {
        let textView = editorView.textView
        guard let range = range,
              let newEnd = textView.position(from: range.end, offset: formattingString.count) else {
            return false
        }
        
        guard let endingRange = textView.textRange(from: range.end, to: newEnd),
              let endingString = textView.text(in: endingRange) else {
            return false
        }
        
        return endingString == formattingString
    }
    
    func removeSurroundingFormattingStringFromSelectedRange(formattingString: String) {
        removeSurroundingFormattingStringFromSelectedRange(startingFormattingString: formattingString, endingFormattingString: formattingString)
    }
    
    // Check selectedRangeIsSurroundedByFormattingString first before running this
    func removeSurroundingFormattingStringFromSelectedRange(startingFormattingString: String, endingFormattingString: String) {
        
        let textView = editorView.textView

        guard let originalSelectedTextRange = textView.selectedTextRange,
              let formattingTextStart = textView.position(from: originalSelectedTextRange.start, offset: -startingFormattingString.count),
              let formattingTextEnd = textView.position(from: originalSelectedTextRange.end, offset: endingFormattingString.count) else {
            return
        }
        
        guard let formattingTextStartRange = textView.textRange(from: formattingTextStart, to: originalSelectedTextRange.start),
              let formattingTextEndRange = textView.textRange(from: originalSelectedTextRange.end, to: formattingTextEnd) else {
            return
        }
        
        // Note: replacing end first ordering is important here, otherwise range gets thrown off if you begin with start. Check with RTL
        textView.replace(formattingTextEndRange, withText: "")
        textView.replace(formattingTextStartRange, withText: "")

        // Reset selection
        let delta = endingFormattingString.count - startingFormattingString.count
        guard
            let newSelectionStartPosition = textView.position(from: originalSelectedTextRange.start, offset: -startingFormattingString.count),
            let newSelectionEndPosition = textView.position(from: originalSelectedTextRange.end, offset: -endingFormattingString.count + delta) else {
            return
        }

        textView.selectedTextRange = textView.textRange(from: newSelectionStartPosition, to: newSelectionEndPosition)
    }
    
    /// Adds formatting characters around selected text or around cursor
    /// - Parameters:
    ///   - formattingString: string used for formatting, will surround selected text or cursor
    func addStringFormattingCharacters(startingFormattingString: String, endingFormattingString: String) {
        
        let textView = editorView.textView
        let startingCursorOffset = startingFormattingString.count
        let endingCursorOffset = endingFormattingString.count
        if let selectedRange = textView.selectedTextRange {
            let cursorPosition = textView.offset(from: textView.endOfDocument, to: selectedRange.end)
            if selectedRange.isEmpty {
                textView.replace(textView.selectedTextRange ?? UITextRange(), withText: startingFormattingString + endingFormattingString)

                let newPosition = textView.position(from: textView.endOfDocument, offset: cursorPosition - endingCursorOffset)
                textView.selectedTextRange = textView.textRange(from: newPosition ?? textView.endOfDocument, to: newPosition ?? textView.endOfDocument)
            } else {
                if let selectedSubstring = textView.text(in: selectedRange) {
                    textView.replace(textView.selectedTextRange ?? UITextRange(), withText: startingFormattingString + selectedSubstring + endingFormattingString)

                    let delta = endingFormattingString.count - startingFormattingString.count
                    let newStartPosition = textView.position(from: selectedRange.start, offset: startingCursorOffset)
                    let newEndPosition = textView.position(from: selectedRange.end, offset: endingCursorOffset - delta)
                    textView.selectedTextRange = textView.textRange(from: newStartPosition ?? textView.endOfDocument, to: newEndPosition ?? textView.endOfDocument)
                } else {
                    textView.replace(textView.selectedTextRange ?? UITextRange(), withText: startingFormattingString + endingFormattingString)
                }
            }
        }
    }
    
    func addStringFormattingCharacters(formattingString: String) {
        addStringFormattingCharacters(startingFormattingString: formattingString, endingFormattingString: formattingString)
    }
}

extension UITextView {

    @available(iOS 16.0, *)
    var textContentStorage: NSTextContentStorage? {
        return textLayoutManager?.textContentManager as? NSTextContentStorage
    }

}

extension NSRange {
    @available(iOS 15.0, *)
    init(_ textRange: NSTextRange, in textContentManager: NSTextContentManager) {
        let location = textContentManager.offset(from: textContentManager.documentRange.location, to: textRange.location)
        let length = textContentManager.offset(from: textRange.location, to: textRange.endLocation)
        self.init(location: location, length: length)
    }
}