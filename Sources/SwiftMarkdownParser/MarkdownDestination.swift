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
/// the host's base URL with Foundation. The scheme is read by Unicode scalar,
/// and the resolved URL's own scheme is checked against the allowlist again;
/// `file` is accepted there only when a relative reference was resolved
/// against a host-chosen `file` base.
enum MarkdownDestination {
    private static let allowedSchemes: Set<String> = ["http", "https", "mailto"]

    /// Resolves `destination` against `baseURL`, or returns `nil` when the
    /// destination is unsafe, empty, or not a URL.
    static func resolve(_ destination: String, relativeTo baseURL: URL?) -> URL? {
        let normalized = normalize(destination)
        guard !normalized.isEmpty else { return nil }

        let scheme = explicitScheme(of: normalized)
        if let scheme, !allowedSchemes.contains(scheme) { return nil }

        let url = if scheme == nil, let baseURL {
            URL(string: normalized, relativeTo: baseURL)?.absoluteURL
        } else {
            URL(string: normalized)
        }
        guard let url, isAllowed(url, resolvedAgainst: scheme == nil ? baseURL : nil) else { return nil }
        return url
    }

    /// Checks the scheme of the URL that will actually be followed, so that
    /// nothing Foundation reads differently from the destination text can slip
    /// past the allowlist. A `file` URL is allowed only when a relative
    /// reference was resolved against a host-chosen `file` base.
    private static func isAllowed(_ url: URL, resolvedAgainst baseURL: URL?) -> Bool {
        let scheme = explicitScheme(of: url.absoluteString)
        guard url.scheme?.lowercased() == scheme else { return false }
        guard let scheme else { return true }

        if allowedSchemes.contains(scheme) { return true }
        return scheme == "file" && baseURL?.isFileURL == true
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
    ///
    /// Read by Unicode scalar, so a combining mark or joiner after the colon,
    /// which would fuse with it into one `Character`, cannot hide the scheme.
    private static func explicitScheme(of destination: String) -> String? {
        let scalars = destination.unicodeScalars
        guard let colon = scalars.firstIndex(of: ":") else { return nil }
        let candidate = scalars[..<colon]
        guard let first = candidate.first, isASCIILetter(first),
              candidate.allSatisfy({ isASCIILetter($0) || ("0"..."9").contains($0) || "+-.".contains(Character($0)) })
        else {
            return nil
        }
        return String(String.UnicodeScalarView(candidate)).lowercased()
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }
}
