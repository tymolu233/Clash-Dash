import SwiftUI

struct YAMLHighlighter {
    static func highlight(_ line: String) -> AttributedString {
        var attributedString = AttributedString(line)
        
        // 注释
        if line.trimmingCharacters(in: .whitespaces).starts(with: "#") {
            attributedString.foregroundColor = .green
            return attributedString
        }
        
        // 键值对中的键
        if let colonIndex = line.firstIndex(of: ":") {
            let keyPart = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let keyRange = attributedString.startIndex..<attributedString.index(attributedString.startIndex, offsetByCharacters: colonIndex.utf16Offset(in: line))
            
            // 检查是否是缩进的键
            let leadingSpaces = line.prefix(while: { $0 == " " })
            let isIndented = !leadingSpaces.isEmpty
            
            if keyRange.lowerBound < keyRange.upperBound {
                attributedString[keyRange].foregroundColor = isIndented ? .red : .pink
            }
        }
        
        // 数组项的破折号
        if line.trimmingCharacters(in: .whitespaces).starts(with: "-") {
            if let dashRange = line.range(of: "-") {
                let start = attributedString.index(attributedString.startIndex, offsetByCharacters: dashRange.lowerBound.utf16Offset(in: line))
                let end = attributedString.index(attributedString.startIndex, offsetByCharacters: dashRange.upperBound.utf16Offset(in: line))
                if start < end {
                    attributedString[start..<end].foregroundColor = .red
                }
            }
        }
        
        return attributedString
    }
} 