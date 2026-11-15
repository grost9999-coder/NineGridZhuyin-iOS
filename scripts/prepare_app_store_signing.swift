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


let root = env["RUNNER_TEMP"]! + "/ninegrid-signing"
let refs = root + "/resources.json"
let cleanup = CommandLine.arguments.contains("--cleanup")
let fm = FileManager.default
try fm.createDirectory(atPath: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
func api(_ method: String, _ path: String, _ payload: [String: Any]? = nil) throws -> [String: Any] {
    var req = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com/v1/" + path)!)
    req.httpMethod = method
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let payload { req.httpBody = try JSONSerialization.data(withJSONObject: payload) }
    let sem = DispatchSemaphore(value: 0)
    var bytes = Data()
    var status = 0
    let task = URLSession.shared.dataTask(with: req) { data, response, _ in
        bytes = data ?? Data()
        status = (response as? HTTPURLResponse)?.statusCode ?? 0
        sem.signal()
    }
    task.resume()
    guard sem.wait(timeout: .now() + 45) == .success else {
        task.cancel()
        throw NSError(domain: "Apple API timeout", code: 1)
    }
    guard (200...299).contains(status) else {
        print("Apple signing API \(method) \(path.components(separatedBy: "?")[0]) returned HTTP \(status)")
        throw NSError(domain: "Apple signing API", code: status)
    }
    return (try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]) ?? [:]
}
func run(_ executable: String, _ arguments: [String]) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: executable)
    p.arguments = arguments
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try p.run()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { throw NSError(domain: "Signing utility failed", code: Int(p.terminationStatus)) }
}
var resources = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: refs)))) as? [String: [String]] ?? ["profiles": [], "certificates": []]
func record(_ type: String, _ id: String) throws {
    resources[type, default: []].append(id)
    try JSONSerialization.data(withJSONObject: resources).write(to: URL(fileURLWithPath: refs), options: .atomic)
}
if cleanup {
    var failed = false
    for type in ["profiles", "certificates"] {
        for id in resources[type] ?? [] {
            do { _ = try api("DELETE", "\(type)/\(id)") }
            catch { failed = true; print("Temporary signing resource cleanup needs review: \(type) \(id)") }
        }
    }
    try? run("/usr/bin/security", ["delete-keychain", root + "/build.keychain-db"])
    try? fm.removeItem(atPath: root)
    if failed { exit(1) }
    print("Temporary signing certificate and profiles cleaned up.")
    exit(0)
}
do {
    let keyPath = root + "/distribution.key"
    let csrPath = root + "/distribution.csr"
    try run("/usr/bin/openssl", ["req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", keyPath, "-out", csrPath, "-subj", "/CN=NineGrid temporary CI distribution"])
    let csr = try String(contentsOfFile: csrPath, encoding: .utf8)
    let result = try api("POST", "certificates", ["data": ["type": "certificates", "attributes": ["certificateType": "DISTRIBUTION", "csrContent": csr]]])
    guard let cert = result["data"] as? [String: Any], let certID = cert["id"] as? String,
          let attrs = cert["attributes"] as? [String: Any],
          let encoded = attrs["certificateContent"] as? String, let certData = Data(base64Encoded: encoded)
    else { throw NSError(domain: "Missing distribution certificate", code: 1) }
    try record("certificates", certID)
    let certPath = root + "/distribution.cer"
    try certData.write(to: URL(fileURLWithPath: certPath))
    let keychain = root + "/build.keychain-db"
    let password = UUID().uuidString
    try run("/usr/bin/security", ["create-keychain", "-p", password, keychain])
    try run("/usr/bin/security", ["set-keychain-settings", "-lut", "21600", keychain])
    try run("/usr/bin/security", ["unlock-keychain", "-p", password, keychain])
    try run("/usr/bin/security", ["list-keychains", "-d", "user", "-s", keychain])
    try run("/usr/bin/security", ["import", keyPath, "-k", keychain, "-T", "/usr/bin/codesign"])
    try run("/usr/bin/security", ["import", certPath, "-k", keychain, "-T", "/usr/bin/codesign"])
    try run("/usr/bin/security", ["set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", password, keychain])
    let profilesPath = NSHomeDirectory() + "/Library/MobileDevice/Provisioning Profiles"
    try fm.createDirectory(atPath: profilesPath, withIntermediateDirectories: true)
    let names = [("com.grost9999.ninegridzhuyin", "NineGridHost"), ("com.grost9999.ninegridzhuyin.keyboard", "NineGridKeyboard")]
    var mapping: [String: String] = [:]
    for (bundle, name) in names {
        let lookup = try api("GET", "bundleIds?filter%5Bidentifier%5D=\(bundle)")
        guard let rows = lookup["data"] as? [[String: Any]], let bundleID = rows.first?["id"] as? String
        else { throw NSError(domain: "App ID missing", code: 1) }
        let profileName = "\(name)-\(env["GITHUB_RUN_ID"]!)-\(env["GITHUB_RUN_ATTEMPT"]!)"
        let created = try api("POST", "profiles", ["data": [
            "type": "profiles", "attributes": ["name": profileName, "profileType": "IOS_APP_STORE"],
            "relationships": ["bundleId": ["data": ["type": "bundleIds", "id": bundleID]],
                              "certificates": ["data": [["type": "certificates", "id": certID]]]]
        ]])
        guard let profile = created["data"] as? [String: Any], let profileID = profile["id"] as? String,
              let values = profile["attributes"] as? [String: Any],
              let uuid = values["uuid"] as? String,
              let content = values["profileContent"] as? String, let data = Data(base64Encoded: content)
        else { throw NSError(domain: "Profile creation failed", code: 1) }
        try record("profiles", profileID)
        try data.write(to: URL(fileURLWithPath: profilesPath + "/\(uuid).mobileprovision"))
        mapping[bundle] = profileName
        print("App Store profile ready for \(bundle)")
    }
    let exportOptions: [String: Any] = ["method": "app-store-connect", "destination": "export",
        "teamID": env["APPLE_TEAM_ID"]!, "signingStyle": "manual",
        "signingCertificate": "Apple Distribution", "manageAppVersionAndBuildNumber": false,
        "provisioningProfiles": mapping]
    try PropertyListSerialization.data(fromPropertyList: exportOptions, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: env["RUNNER_TEMP"]! + "/ExportOptions.plist"))
    let projectPath = "project.yml"
    var project = try String(contentsOfFile: projectPath, encoding: .utf8)
    project = project.replacingOccurrences(of: "CODE_SIGN_STYLE: Automatic", with: "CODE_SIGN_STYLE: Manual\n        CODE_SIGN_IDENTITY: Apple Distribution")
    for (bundle, name) in mapping {
        project = project.replacingOccurrences(of: "PRODUCT_BUNDLE_IDENTIFIER: \(bundle)\n",
            with: "PRODUCT_BUNDLE_IDENTIFIER: \(bundle)\n        PROVISIONING_PROFILE_SPECIFIER: \(name)\n")
    }
    try project.write(toFile: projectPath, atomically: true, encoding: .utf8)
    print("Manual App Store signing prepared.")
} catch {
    print("Manual signing preparation failed. HTTP 403 requires a Team Key permitted to create distribution certificates and profiles.")
    exit(1)
}
