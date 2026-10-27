import Foundation
import GudengCore
import GudengRuntime

public final class UserDefaultsPreferences: PreferencesStoring {
    /// Current key. Renamed from the legacy LiangWen key with a one-way read
    /// migration so existing v0.1.x preferences survive the engineering rename.
    public static let defaultKey = "gudeng.preferences.v1"
    public static let legacyKey = "liangwen.preferences.v1"

    private let defaults: UserDefaults
    private let key: String
    private let legacyKey: String?

    public init(
        defaults: UserDefaults = .standard,
        key: String = UserDefaultsPreferences.defaultKey,
        legacyKey: String? = UserDefaultsPreferences.legacyKey
    ) {
        self.defaults = defaults
        self.key = key
        self.legacyKey = legacyKey
    }

    public func load() -> UserPreferences? {
        if let data = defaults.data(forKey: key),
            let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data)
        {
            return preferences
        }
        guard let legacyKey, legacyKey != key,
            let data = defaults.data(forKey: legacyKey),
            let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else {
            return nil
        }
        // Keep the legacy value so rolling back to the previous build still works.
        save(preferences)
        return preferences
    }

    public func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
