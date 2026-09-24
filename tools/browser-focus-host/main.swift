import Foundation

// Chrome owns this process. Stdout is reserved exclusively for framed JSON.
let input = FileHandle.standardInput
let output = FileHandle.standardOutput
func readExactly(_ count: Int) throws -> Data? {
    var data = Data()
    while data.count < count {
        guard let chunk = try input.read(upToCount: count - data.count), !chunk.isEmpty else { return nil }
        data.append(chunk)
    }
    return data
}
do {
    while let header = try readExactly(4) {
        let size = header.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
        guard size > 0, size <= 4096, let request = try readExactly(Int(size)),
              let message = try JSONSerialization.jsonObject(with: request) as? [String: String],
              message["type"] == "status" else { break }
        var response: [String: Any] = ["active": false, "domains": [], "expiresAt": 0, "remaining": 0]
        if let data = try? Data(contentsOf: BrowserFocusState.fileURL),
           let state = try? JSONDecoder().decode(BrowserFocusState.self, from: data),
           state.isValid(at: Date().timeIntervalSince1970) {
            response = ["active": true, "domains": state.domains,
                        "expiresAt": state.expiresAt, "remaining": state.remaining]
        }
        let data = try JSONSerialization.data(withJSONObject: response)
        var length = UInt32(data.count).littleEndian
        try output.write(contentsOf: withUnsafeBytes(of: &length) { Data($0) })
        try output.write(contentsOf: data)
    }
} catch {
    // EOF or a broken pipe must simply release the browser connection.
    exit(1)
}
