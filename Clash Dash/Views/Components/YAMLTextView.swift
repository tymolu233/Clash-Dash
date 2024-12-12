import SwiftUI
import UIKit

struct YAMLTextView: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.layoutManager.allowsNonContiguousLayout = false
        
        // 初始设置文本和高亮
        textView.text = text
        highlightSyntax(textView)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 只在外部更新文本时才重新设置
        if uiView.text != text && !context.coordinator.isUpdatingText {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            highlightSyntax(uiView)
            uiView.selectedRange = selectedRange
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func highlightSyntax(_ textView: UITextView) {
        let attributedText = NSMutableAttributedString(string: textView.text)
        let wholeRange = NSRange(location: 0, length: textView.text.utf16.count)
        let selectedRange = textView.selectedRange
        
        // 设置基本字体和颜色
        attributedText.addAttribute(.font, value: font, range: wholeRange)
        attributedText.addAttribute(.foregroundColor, value: UIColor.label, range: wholeRange)
        
        // 使用正则表达式进行语法高亮
        do {
            // 注释
            let commentPattern = "#.*$"
            let commentRegex = try NSRegularExpression(pattern: commentPattern, options: .anchorsMatchLines)
            commentRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                if let range = match?.range {
                    attributedText.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: range)
                }
            }
            
            // 键（包括缩进的键）
            let keyPattern = "^\\s*([\\w-]+):"
            let keyRegex = try NSRegularExpression(pattern: keyPattern, options: .anchorsMatchLines)
            keyRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                if let range = match?.range(at: 1) {
                    let color = textView.text[Range(range, in: textView.text)!].hasPrefix(" ") ? 
                        UIColor.systemRed : UIColor.systemPink
                    attributedText.addAttribute(.foregroundColor, value: color, range: range)
                }
            }
            
            // 破折号
            let dashPattern = "^\\s*-"
            let dashRegex = try NSRegularExpression(pattern: dashPattern, options: .anchorsMatchLines)
            dashRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                if let range = match?.range {
                    attributedText.addAttribute(.foregroundColor, value: UIColor.systemRed, range: range)
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        textView.attributedText = attributedText
        textView.selectedRange = selectedRange
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: YAMLTextView
        var isUpdatingText = false
        
        init(_ parent: YAMLTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            isUpdatingText = true
            parent.text = textView.text
            parent.highlightSyntax(textView)
            isUpdatingText = false
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // 可以在这里添加其他光标位置相关的逻辑
        }
    }
} 