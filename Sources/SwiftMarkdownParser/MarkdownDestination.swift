import Foundation

/// The Destination of one link, image, or autolink: whether it is safe to
/// follow and which URL it represents.
///
/// This is the single authority on destination safety for every Output
/// Renderer. A destination is normalized before any decision, the way the
/// WHATWG URL parser in browsers reads it: C0 controls and spaces are trimmed
/// from both ends, and TAB, LF, and CR are removed everywhere, so a scheme
/// split by them is still recognized. Only `http`, `https`, and `mailto` may be
/// named explicitly; relative references, fragments, and the empty reference
/// to the current document are resolved against
/// the host's base URL with Foundation. The scheme is read by Unicode scalar,
/// and the resolved URL's own scheme is checked against the allowlist again;
/// `file` is accepted there only when a relative reference was resolved
/// against a host-chosen `file` base. A protocol-relative reference
/// (`//host/x`) names its own authority, so it is accepted only against an
/// `http` or `https` base.
enum MarkdownDestination {
    private static let allowedSchemes: Set<String> = ["http", "https", "mailto"]

    /// Resolves `destination` against `baseURL`, or returns `nil` when the
    /// destination is unsafe or not a URL.
    static func resolve(_ destination: String, relativeTo baseURL: URL?) -> URL? {
        let normalized = normalize(destination)
        guard !normalized.isEmpty else { return currentDocument(relativeTo: baseURL) }

        let scheme = explicitScheme(of: normalized)
        if let scheme, !allowedSchemes.contains(scheme) { return nil }
        if scheme == nil, namesUnchosenAuthority(normalized, relativeTo: baseURL) { return nil }

        let url = if scheme == nil, let baseURL {
            URL(string: normalized, relativeTo: baseURL)?.absoluteURL
        } else {
            URL(string: normalized)
        }
        guard let url, isAllowed(url, resolvedAgainst: scheme == nil ? baseURL : nil) else {
            return nil
        }
        return url
    }

    /// An empty destination refers to the current document, as in CommonMark:
    /// the base URL without its fragment (RFC 3986, section 5.2.2), or an
    /// empty relative reference when there is no base.
    private static func currentDocument(relativeTo baseURL: URL?) -> URL? {
        guard let baseURL else { return URLComponents().url }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else { return nil }
        components.fragment = nil
        guard let url = components.url, isAllowed(url, resolvedAgainst: baseURL) else { return nil }
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

    /// Whether a scheme-less reference starting with `//` would reach an
    /// authority the host did not choose. Without a base URL it is emitted as
    /// written and the browser reads it as `//evil.com` on the page's own
    /// scheme. Against a `file` base, `//evil.com/share` or `//:80/x` becomes a
    /// network share, and so can `////evil.com/share`, which Windows browsers
    /// read as a UNC path; only exactly `///` followed by a path segment, with an
    /// empty authority, stays local.
    /// Against an `http` or `https` base, it takes the base's scheme.
    private static func namesUnchosenAuthority(_ destination: String, relativeTo baseURL: URL?) -> Bool {
        guard destination.hasPrefix("//") else { return false }
        guard let baseURL else { return true }
        guard baseURL.isFileURL else { return false }
        let path = destination.unicodeScalars.dropFirst(3)
        return !destination.hasPrefix("///") || path.first == nil || path.first == "/"
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
