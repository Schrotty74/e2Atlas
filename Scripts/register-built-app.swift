import Foundation
import CoreServices

// Refresh only this built bundle; never reset global Launch Services or Dock caches.
guard CommandLine.arguments.count == 2 else {
    fputs("Expected one app bundle path.\n", stderr)
    exit(64)
}
let appURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
guard let bundle = Bundle(url: appURL),
      let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String,
      !iconName.isEmpty,
      bundle.url(forResource: iconName, withExtension: "icns") != nil,
      bundle.url(forResource: "Assets", withExtension: "car") != nil else {
    fputs("The built app is missing its icon resources.\n", stderr)
    exit(1)
}
let result = LSRegisterURL(appURL as CFURL, true)
guard result == noErr else {
    fputs("The built app could not be registered with Launch Services (\(result)).\n", stderr)
    exit(1)
}
