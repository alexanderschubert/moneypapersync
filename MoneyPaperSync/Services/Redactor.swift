import Foundation

/// Entfernt sensible Daten (IBANs, Tokens) aus Texten, bevor sie protokolliert oder angezeigt werden.
enum Redactor {
    private static let ibanPattern = try! NSRegularExpression(
        pattern: #"\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?\b"#
    )
    private static let tokenPattern = try! NSRegularExpression(
        pattern: #"(?i)(token|bearer|authorization)[\s:=]+[A-Za-z0-9._\-]{16,}"#
    )
    private static let hexPattern = try! NSRegularExpression(pattern: #"\b[a-f0-9]{32,}\b"#)

    static func sanitize(_ text: String) -> String {
        var result = text
        let range = { NSRange(result.startIndex..., in: result) }
        result = ibanPattern.stringByReplacingMatches(in: result, range: range(), withTemplate: "[IBAN entfernt]")
        result = tokenPattern.stringByReplacingMatches(in: result, range: range(), withTemplate: "$1 [entfernt]")
        result = hexPattern.stringByReplacingMatches(in: result, range: range(), withTemplate: "[Hash]")
        return String(result.prefix(500))
    }
}

/// Karten- und Sparbuchnummern: Prüfung und Maskierung (nur die letzten vier Stellen bleiben sichtbar).
enum ReferenceTools {
    static func digits(_ text: String) -> String { text.filter(\.isNumber) }

    static func isValidCardNumber(_ text: String) -> Bool {
        let d = digits(text)
        guard (13...19).contains(d.count) else { return false }
        var sum = 0
        for (index, char) in d.reversed().enumerated() {
            guard var value = char.wholeNumberValue else { return false }
            if index % 2 == 1 {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
        }
        return sum % 10 == 0
    }

    static func mask(_ text: String) -> String {
        let d = digits(text)
        guard d.count >= 4 else { return "" }
        return "•••• \(d.suffix(4))"
    }
}

enum IBANTools {
    /// Maskiert eine IBAN: Land + Platzhalter + letzte vier Zeichen.
    static func mask(_ iban: String) -> String {
        let clean = iban.filter { $0.isLetter || $0.isNumber }.uppercased()
        guard clean.count >= 8 else { return "" }
        let country = clean.prefix(2)
        let last4 = clean.suffix(4)
        return "\(country)•• •••• •••• \(last4)"
    }

    /// Prüfsumme nach ISO 7064 (mod 97).
    static func isValid(_ iban: String) -> Bool {
        let clean = iban.filter { $0.isLetter || $0.isNumber }.uppercased()
        guard clean.count >= 15, clean.count <= 34 else { return false }
        let rearranged = clean.dropFirst(4) + clean.prefix(4)
        var remainder = 0
        for char in rearranged {
            let value: Int
            if let digit = char.wholeNumberValue, char.isNumber {
                value = digit
                remainder = (remainder * 10 + value) % 97
            } else if let ascii = char.asciiValue, ascii >= 65, ascii <= 90 {
                value = Int(ascii) - 55
                remainder = (remainder * 100 + value) % 97
            } else {
                return false
            }
        }
        return remainder == 1
    }
}
