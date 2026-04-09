import Foundation

/// Single source of truth for the `pulse` release version.
/// Bumped by CI at release time (see .github/workflows/release.yml).
public enum PulseVersion {
    public static let current = "0.2.0"
}
