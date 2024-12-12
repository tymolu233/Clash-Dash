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
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // 初始设置文本和高亮
        textView.text = text
        highlightSyntax(textView)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text && !context.coordinator.isUpdatingText {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            highlightSyntax(uiView)
            uiView.selectedRange = selectedRange
        }
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
            // 主要 YAML 关键字（使用蓝色和粗体）
            let mainKeywords = ["proxies:", "proxy-groups:", "rules:", "proxy-providers:", "script:"]
            for keyword in mainKeywords {
                let pattern = "^\\s*\(keyword)"
                let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
                regex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                    if let range = match?.range {
                        attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
                        attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: font.pointSize), range: range)
                    }
                }
            }
            
            // 注释（使用绿色）
            let commentPattern = "#.*$"
            let commentRegex = try NSRegularExpression(pattern: commentPattern, options: .anchorsMatchLines)
            commentRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                if let range = match?.range {
                    attributedText.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: range)
                    attributedText.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: font.pointSize), range: range)
                }
            }
            
            // 键值对中的键（使用紫色）
            let keyPattern = "^\\s*([\\w-]+):"
            let keyRegex = try NSRegularExpression(pattern: keyPattern, options: .anchorsMatchLines)
            keyRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                if let range = match?.range(at: 1) {
                    attributedText.addAttribute(.foregroundColor, value: UIColor.systemPurple, range: range)
                }
            }
            
            // 数组项的破折号（使用橙色）
            let dashPattern = "^\\s*-\\s"
            let dashRegex = try NSRegularExpression(pattern: dashPattern, options: .anchorsMatchLines)
            dashRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                if let range = match?.range {
                    attributedText.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: range)
                }
            }
            
            // URL（使用蓝色和下划线）
            // let urlPattern = "(https?://[\\w\\d\\-\\.]+\\.[\\w\\d\\-\\./\\?\\=\\&\\%\\+\\#]+)"
            // let urlRegex = try NSRegularExpression(pattern: urlPattern, options: [])
            // urlRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
            //     if let range = match?.range {
            //         attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
            //         attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            //     }
            // }
            
            // 布尔值（使用红色）
            let boolPattern = "\\s(true|false)\\s"
            let boolRegex = try NSRegularExpression(pattern: boolPattern, options: [])
            boolRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                if let range = match?.range(at: 1) {
                    attributedText.addAttribute(.foregroundColor, value: UIColor.systemRed, range: range)
                    attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: font.pointSize), range: range)
                }
            }
            
            // 数字（使用蓝绿色）
            let numberPattern = "\\s(\\d+)\\s"
            let numberRegex = try NSRegularExpression(pattern: numberPattern, options: [])
            numberRegex.enumerateMatches(in: textView.text, range: wholeRange) { match, _, _ in
                if let range = match?.range(at: 1) {
                    attributedText.addAttribute(.foregroundColor, value: UIColor.systemTeal, range: range)
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        textView.attributedText = attributedText
        textView.selectedRange = selectedRange
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
    }
} 