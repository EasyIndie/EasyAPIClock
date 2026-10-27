public enum PreviewOutcome: Sendable, Equatable {
    case idle
    case permissionRequired
    case finished
    case failed(String)
}
