import Foundation
import Security

struct DeviceIdentity: Codable { let id: String; let secret: String }
enum SecureStore {
    private static let service = "hu.csaladitv.meteor.ios"
    static func read<T: Decodable>(_ key: String, as type: T.Type) throws -> T? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?; let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw MeteorError.secureStorage }
        return try JSONDecoder().decode(T.self, from: data)
    }
    static func write<T: Encodable>(_ key: String, _ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        let updates: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query; for (k,v) in updates { insert[k] = v }; guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw MeteorError.secureStorage }
        } else if status != errSecSuccess { throw MeteorError.secureStorage }
    }
    static func identity() throws -> DeviceIdentity {
        if let value = try read("identity", as: DeviceIdentity.self) { return value }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw MeteorError.secureStorage }
        let token = Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let value = DeviceIdentity(id: UUID().uuidString.lowercased(), secret: token); try write("identity", value); return value
    }
}
