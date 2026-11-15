import Foundation
import CryptoKit

// Safe, read-only CI diagnostic. Never print tokens, private keys, or response bodies.
let env = ProcessInfo.processInfo.environment
for name in ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_API_KEY_P8"] {
    if (env[name] ?? "").isEmpty {
        fputs("Missing GitHub Secret: \(name)\n", stderr)
        exit(2)
    }
}

func b64(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
}

let header: [String: String] = ["alg": "ES256", "kid": env["ASC_KEY_ID"]!, "typ": "JWT"]
let epoch = Int(Date().timeIntervalSince1970)
let claims: [String: Any] = ["iss": env["ASC_ISSUER_ID"]!, "iat": epoch,
                             "exp": epoch + 600, "aud": "appstoreconnect-v1"]

let token: String
do {
    let key = try P256.Signing.PrivateKey(pemRepresentation: env["ASC_API_KEY_P8"]!)
    let headerPart = b64(try JSONSerialization.data(withJSONObject: header))
    let claimPart = b64(try JSONSerialization.data(withJSONObject: claims))
    let dataToSign = Data("\(headerPart).\(claimPart)".utf8)
    let signature = try key.signature(for: dataToSign)
    token = "\(headerPart).\(claimPart).\(b64(signature.rawRepresentation))"
} catch {
    fputs("Private key cannot sign a JWT; update ASC_API_KEY_P8 with the matching original .p8 text.\n", stderr)
    exit(2)
}

struct Check {
    let title: String
    let url: String
    let mustContainRecord: Bool
}
let checks = [
    Check(title: "App Store Connect API", url: "https://api.appstoreconnect.apple.com/v1/apps?limit=1", mustContainRecord: false),
    Check(title: "Provisioning API - host App ID", url: "https://api.appstoreconnect.apple.com/v1/bundleIds?filter%5Bidentifier%5D=com.grost9999.ninegridzhuyin", mustContainRecord: true),
    Check(title: "Provisioning API - keyboard App ID", url: "https://api.appstoreconnect.apple.com/v1/bundleIds?filter%5Bidentifier%5D=com.grost9999.ninegridzhuyin.keyboard", mustContainRecord: true),
    Check(title: "Provisioning API - profiles", url: "https://api.appstoreconnect.apple.com/v1/profiles?limit=1", mustContainRecord: false)
]

// Check for accidental spaces/newlines and malformed identifier lengths without printing secrets.
let rawKeyID = env["ASC_KEY_ID"]!
let rawIssuerID = env["ASC_ISSUER_ID"]!
if rawKeyID != rawKeyID.trimmingCharacters(in: .whitespacesAndNewlines) ||
   rawKeyID.count != 10 {
    print("FAIL: ASC_KEY_ID must be the exact 10-character Apple Team API Key ID with no spaces or trailing newline")
    exit(1)
}
if rawIssuerID != rawIssuerID.trimmingCharacters(in: .whitespacesAndNewlines) ||
   UUID(uuidString: rawIssuerID) == nil {
    print("FAIL: ASC_ISSUER_ID must be the UUID from Apple App Store Connect Team Keys, with no extra whitespace")
    exit(1)
}

let session = URLSession(configuration: .ephemeral)
var failures = 0
for check in checks {
    guard let url = URL(string: check.url) else { failures += 1; continue }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 18
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let semaphore = DispatchSemaphore(value: 0)
    var status: Int?
    var returnedData: Data?
    var requestError: Error?
    session.dataTask(with: request) { data, response, error in
        returnedData = data
        status = (response as? HTTPURLResponse)?.statusCode
        requestError = error
        semaphore.signal()
    }.resume()
    let waited = semaphore.wait(timeout: .now() + 24)
    if waited == .timedOut {
        print("FAIL: \(check.title) - request timeout"); failures += 1; continue
    }
    if let requestError {
        print("FAIL: \(check.title) - network error: \(type(of: requestError))")
        failures += 1; continue
    }
    guard let status else {
        print("FAIL: \(check.title) - no HTTP status"); failures += 1; continue
    }
    if status == 200 {
        if check.mustContainRecord,
           let data = returnedData,
           let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let records = obj["data"] as? [Any], records.isEmpty {
            print("FAIL: \(check.title) - API works but this Bundle ID was not found in the key's team")
            failures += 1
        } else {
            print("PASS: \(check.title) - HTTP 200")
        }
    } else if status == 401 {
        // Never display an untrusted response body. Show a short verified code only.
        var code = "UNKNOWN"
        if let data = returnedData,
           let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let errors = root["errors"] as? [[String: Any]],
           let candidate = errors.first?["code"] as? String,
           !candidate.isEmpty, candidate.count <= 64,
           candidate.allSatisfy({ $0.isASCII && ($0.isUppercase || $0.isNumber || $0 == "_" || $0 == "-") }) {
            code = candidate
        }
        print("FAIL: \\(check.title) - HTTP 401 (Apple error code: \\(code)). Verify Team API Key ID, the matching .p8 file and team Issuer ID.")
        failures += 1
    } else if status == 403 {
        print("FAIL: \(check.title) - HTTP 403: key lacks access to this resource; review team key role and Apple Developer signing privileges")
        failures += 1
    } else {
        print("FAIL: \(check.title) - HTTP \(status)"); failures += 1
    }
}
session.invalidateAndCancel()
if failures > 0 {
    print("Signing API diagnostics did NOT pass. Do not retry the full signing workflow until the Apple key/role/team issue is addressed.")
    exit(1)
}
print("All REST API checks passed. If xcodebuild still gets 401 at listTeams.action, use manual Apple Distribution (.p12 + 2 profiles) signing or resolve this separate Xcode service access issue.")
