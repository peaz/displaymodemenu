//
//  AppConfig.swift
//  DisplayModeMenu
//
//  Application configuration constants
//

import Foundation

struct AppConfig {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1337 Version"
    static let websiteURL = "https://atpeaz.com"
    static let buyMeCoffeeURL = "https://buymeacoffee.com/kenyc"
    static let appName = "DisplayMode Menu"
    static let developerName = "Ken"
}
