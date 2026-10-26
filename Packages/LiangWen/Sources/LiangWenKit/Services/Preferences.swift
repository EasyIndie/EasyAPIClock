import Foundation
import LiangWenCore
import LiangWenRuntime

public final class UserDefaultsPreferences: PreferencesStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "liangwen.preferences.v1") {
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
