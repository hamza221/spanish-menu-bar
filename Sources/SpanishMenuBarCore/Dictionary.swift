import Foundation

/// One meaning of a Spanish headword, e.g. `("evergreen", "{adj} [botany]")`.
public struct Sense: Equatable, Hashable {
    public let definition: String
    /// Raw tag from the dictionary: `{part of speech}` optionally followed by `[usage]`. May be empty.
    public let type: String

    public init(definition: String, type: String) {
        self.definition = definition
        self.type = type
    }

    /// Readable tag, e.g. `{adj} [botany]` → `adjective · botany`, `{m}` → `masculine noun`.
    public var label: String {
        var parts: [String] = []
        if let code = Self.firstMatch(#"\{([^}]*)\}"#, in: type) {
            parts.append(Self.partsOfSpeech[code] ?? code)
        }
        if let usage = Self.firstMatch(#"\[([^\]]*)\]"#, in: type) {
            parts.append(usage)
        }
        return parts.isEmpty ? type : parts.joined(separator: " · ")
    }

    private static func firstMatch(_ pattern: String, in string: String) -> String? {
        guard let range = string.range(of: pattern, options: .regularExpression) else { return nil }
        let inner = string[range].dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
        return inner.isEmpty ? nil : inner
    }

    private static let partsOfSpeech: [String: String] = [
        "m": "masculine noun", "f": "feminine noun", "mf": "masculine or feminine noun", "n": "noun",
        "mp": "masculine plural noun", "fp": "feminine plural noun", "prop": "proper noun", "propm": "proper noun (masculine)",
        "adj": "adjective", "adjf": "adjective (feminine)", "adjmf": "adjective", "adv": "adverb",
        "v": "verb", "vt": "transitive verb", "vi": "intransitive verb", "vr": "reflexive verb", "vp": "pronominal verb",
        "vtr": "transitive verb", "vir": "intransitive verb", "vit": "verb", "vitr": "verb", "vrr": "reflexive verb", "vm": "modal verb",
        "prep": "preposition", "conj": "conjunction", "pron": "pronoun", "interj": "interjection", "art": "article",
        "determiner": "determiner", "num": "numeral", "cardinal num": "cardinal number", "letter": "letter",
        "prefix": "prefix", "suffix": "suffix", "abbr": "abbreviation", "initialism": "initialism", "acronym": "acronym",
        "contraction": "contraction", "phrase": "phrase", "idiom": "idiom", "proverb": "proverb", "symbol": "symbol",
    ]
}

/// Spanish → English dictionary grouped by headword.
public struct SpanishDictionary {
    /// Headword → senses, in source order, duplicates removed.
    public let entries: [String: [Sense]]
    /// All headwords, sorted.
    public let words: [String]

    public init(entries: [String: [Sense]]) {
        self.entries = entries
        self.words = entries.keys.sorted()
    }

    /// Loads the bundled `es-en.xml`. Prefers the `.app` bundle's Resources, falls back to the SwiftPM resource bundle (`swift run`).
    public static func loadBundled() throws -> SpanishDictionary {
        let url = Bundle.main.url(forResource: "es-en", withExtension: "xml")
            ?? Bundle.module.url(forResource: "es-en", withExtension: "xml")
        guard let url else { throw DictionaryError.missingResource }
        return try parse(Data(contentsOf: url))
    }

    public static func parse(_ data: Data) throws -> SpanishDictionary {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw DictionaryError.malformed(parser.parserError?.localizedDescription ?? "unknown error")
        }
        return SpanishDictionary(entries: delegate.entries)
    }
}

public enum DictionaryError: Error, CustomStringConvertible {
    case missingResource
    case malformed(String)

    public var description: String {
        switch self {
        case .missingResource: return "es-en.xml not found in app bundle"
        case .malformed(let reason): return "es-en.xml could not be parsed: \(reason)"
        }
    }
}

/// Parses `<w><c>word</c><d>definition</d><t>{type}</t></w>` records.
private final class ParserDelegate: NSObject, XMLParserDelegate {
    var entries: [String: [Sense]] = [:]
    private var seen: [String: Set<Sense>] = [:]
    private var text = ""
    private var word = ""
    private var definition = ""
    private var type = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        if name == "w" { word = ""; definition = ""; type = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "c": word = value
        case "d": definition = value
        case "t": type = value
        case "w":
            guard !word.isEmpty, !definition.isEmpty else { return }
            let sense = Sense(definition: definition, type: type)
            if seen[word, default: []].insert(sense).inserted {
                entries[word, default: []].append(sense)
            }
        default: break
        }
        text = ""
    }
}
