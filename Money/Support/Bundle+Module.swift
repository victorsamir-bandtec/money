import Foundation

private final class BundleToken {}

extension Bundle {
    static var appModule: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle(for: BundleToken.self)
        #endif
    }
}
