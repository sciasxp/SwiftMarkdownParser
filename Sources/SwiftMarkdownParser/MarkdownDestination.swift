import Foundation

/// The Destination of one link, image, or autolink: whether it is safe to
/// follow and which URL it represents.
///
/// This is the single authority on destination safety for every Output
/// Renderer. A destination is normalized before any decision, the way the
/// WHATWG URL parser in browsers reads it: C0 controls and spaces are trimmed
/// from both ends, and TAB, LF, and CR are removed everywhere, so a scheme
/// split by them is still recognized. Only `http`, `https`, and `mailto` may be
/// named explicitly; relative references and fragments are resolved against
/// the host's base URL with Foundation, and any scheme that resolution yields,
/// including `file`, is accepted because the host chose the base.
enum MarkdownDestination {
    private static let allowedSchemes: Set<String> = ["http", "https", "mailto"]

    /// Resolves `destination` against `baseURL`, or returns `nil` when the
    /// destination is unsafe, empty, or not a URL.
    static func resolve(_ destination: String, relativeTo baseURL: URL?) -> URL? {
        let normalized = normalize(destination)
        guard !normalized.isEmpty else { return nil }

        if let scheme = explicitScheme(of: normalized) {
            guard allowedSchemes.contains(scheme) else { return nil }
            return URL(string: normalized)
        }

        guard let baseURL else {
            guard let url = URL(string: normalized), url.scheme == nil else { return nil }
            return url
        }
        return URL(string: normalized, relativeTo: baseURL)?.absoluteURL
    }

    private static func normalize(_ destination: String) -> String {
        var scalars = Substring(destination).unicodeScalars
        while let first = scalars.first, isTrimmed(first) {
            scalars.removeFirst()
        }
        while let last = scalars.last, isTrimmed(last) {
            scalars.removeLast()
        }

        var normalized = String.UnicodeScalarView()
        normalized.append(contentsOf: scalars.filter { !["\t", "\n", "\r"].contains($0) })
        return String(normalized)
    }

    /// C0 controls and space, plus the Unicode whitespace trimmed before.
    private static func isTrimmed(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value <= 0x20 || CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    /// The lowercased scheme, when `destination` starts with one: an ASCII
    /// letter followed by letters, digits, `+`, `-`, or `.`, then `:`.
    private static func explicitScheme(of destination: String) -> String? {
        guard let colon = destination.firstIndex(of: ":") else { return nil }
        let candidate = destination[..<colon]
        guard let first = candidate.first, first.isASCII, first.isLetter,
              candidate.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "+-.".contains($0)) }) else {
            return nil
        }
        return candidate.lowercased()
    }
}
