//
//  Preferences.swift
//  DisplayModeMenu
//
//  Centralized app preferences storage and access.
//

import Foundation
import ServiceManagement

struct FavoriteResolution: Codable, Equatable {
    let width: Int
    let height: Int
    let refreshRate: Double
    let hiDPI: Bool
}

final class Preferences {
    private enum Keys {
        static let favoriteResolutions = "Preferences.FavoriteResolutions"
        static let minRefreshRate = "Preferences.MinRefreshRate"
        static let startAtLogin = "Preferences.StartAtLogin"
        static let showLowResolution = "Preferences.ShowLowResolution"
        static let lastUsedResolutions = "Preferences.LastUsedResolutions"
    }
    
    // MARK: - Favorite Resolutions
    static func defaultFavoriteResolutions() -> [FavoriteResolution] {
        return [
            FavoriteResolution(width: 5120, height: 2880, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 3840, height: 2160, refreshRate: 60, hiDPI: false),
            FavoriteResolution(width: 3840, height: 2160, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 3840, height: 2160, refreshRate: 144, hiDPI: false),
            FavoriteResolution(width: 2560, height: 1600, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 2560, height: 1440, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 2560, height: 1440, refreshRate: 144, hiDPI: false),
            FavoriteResolution(width: 2560, height: 1440, refreshRate: 165, hiDPI: false),
            FavoriteResolution(width: 1920, height: 1200, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 1920, height: 1200, refreshRate: 120, hiDPI: true),
            FavoriteResolution(width: 1920, height: 1080, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 1920, height: 1080, refreshRate: 144, hiDPI: false),
            FavoriteResolution(width: 1728, height: 1117, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 1728, height: 1117, refreshRate: 120, hiDPI: true),
            FavoriteResolution(width: 1680, height: 1050, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 1512, height: 982, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 1512, height: 982, refreshRate: 120, hiDPI: true),
            FavoriteResolution(width: 1440, height: 900, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 1440, height: 900, refreshRate: 120, hiDPI: true),
            FavoriteResolution(width: 1280, height: 800, refreshRate: 60, hiDPI: true),
            FavoriteResolution(width: 1280, height: 800, refreshRate: 120, hiDPI: true),
            FavoriteResolution(width: 1152, height: 720, refreshRate: 60, hiDPI: true)
        ]
    }
    
    static var favoriteResolutions: [FavoriteResolution] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.favoriteResolutions) else {
                return defaultFavoriteResolutions()
            }
            do {
                return try JSONDecoder().decode([FavoriteResolution].self, from: data)
            } catch {
                #if DEBUG
                NSLog("[Preferences] Failed to decode favorites: \(error)")
                #endif
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: Keys.favoriteResolutions)
            } catch {
                #if DEBUG
                NSLog("[Preferences] Failed to encode favorites: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Minimum Refresh Rate
    static var minRefreshRate: Double {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.minRefreshRate)
            return v > 0 ? v : 60.0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.minRefreshRate)
        }
    }
    
    // MARK: - Start at Login
    static var startAtLogin: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.startAtLogin)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.startAtLogin)
            // Attempt to register/unregister with system login items (macOS 13+)
            let service = SMAppService.mainApp
            do {
                if newValue {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                #if DEBUG
                NSLog("[Preferences] Failed to update login item: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Show Low Resolution
    static var showLowResolution: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.showLowResolution)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showLowResolution)
        }
    }
    
    // MARK: - Last Used Resolutions (Auto-restore on launch)
    static var lastUsedResolutions: [String: FavoriteResolution] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.lastUsedResolutions) else {
                return [:]
            }
            do {
                return try JSONDecoder().decode([String: FavoriteResolution].self, from: data)
            } catch {
                #if DEBUG
                NSLog("[Preferences] Failed to decode last used resolutions: \(error)")
                #endif
                return [:]
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: Keys.lastUsedResolutions)
            } catch {
                #if DEBUG
                NSLog("[Preferences] Failed to encode last used resolutions: \(error)")
                #endif
            }
        }
    }
}
