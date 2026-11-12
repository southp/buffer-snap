import Foundation

/// Where BufSnap's help and code live, for the account menu's links.
public enum ProjectLinks {
    /// The support page's "Report a problem" section (`site/support/index.html`, `id="report"`), which offers GitHub
    /// and email. Not GitHub directly: most people using BufSnap have no GitHub account.
    public static let reportProblem = url("https://southp.github.io/buffer-snap/support/#report")

    /// The repo: BufSnap is free and open source (MIT).
    public static let sourceCode = url("https://github.com/southp/buffer-snap")

    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Not a URL: \(string)")
        }
        return url
    }
}
