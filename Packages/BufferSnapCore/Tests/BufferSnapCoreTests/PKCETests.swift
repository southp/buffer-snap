import BufferSnapCore
import Foundation
import Testing

struct PKCETests {
    /// The example in RFC 7636's appendix B, so this checks against the spec rather than against our own code.
    @Test func challengeMatchesTheRFCExample() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func verifierAndChallengeAreBase64URLOfTheRightLength() {
        let pkce = PKCE()
        let base64URLCharacters = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        )

        #expect(pkce.verifier.count == 43)
        #expect(pkce.challenge.count == 43)
        #expect(pkce.verifier.unicodeScalars.allSatisfy(base64URLCharacters.contains))
        #expect(pkce.challenge.unicodeScalars.allSatisfy(base64URLCharacters.contains))
    }

    @Test func everyPairIsNew() {
        #expect(PKCE().verifier != PKCE().verifier)
    }
}
