import Foundation
import GudengCore
import GudengRuntime

public final class UserDefaultsPreferences: PreferencesStoring {
    public static let defaultKey = "gudeng.preferences.v1"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = UserDefaultsPreferences.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> UserPreferences? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserPreferences.self, from: data)
    }

    public func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
