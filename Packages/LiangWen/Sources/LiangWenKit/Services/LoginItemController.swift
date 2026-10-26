import Foundation
import Combine
#if os(macOS)
    import ServiceManagement
#endif

@MainActor
public protocol LoginItemManaging {
    var state: LoginItemState { get }
    func setEnabled(_ enabled: Bool) throws
    func openSettings()
}

public enum LoginItemState: Sendable {
    case enabled, disabled, requiresApproval, unavailable
}

@MainActor
public final class LoginItemController: ObservableObject {
    @Published public private(set) var state: LoginItemState = .unavailable
    @Published public private(set) var errorMessage: String?
    private let service: any LoginItemManaging

    public init(service: any LoginItemManaging = SystemLoginItemService()) {
        self.service = service
        refresh()
    }

    public func refresh() { state = service.state }

    public func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do { try service.setEnabled(enabled) } catch {
            errorMessage = ClockText.loginFailure + error.localizedDescription
        }
        refresh()
    }

    public func openSettings() { service.openSettings() }
}

@MainActor
public struct SystemLoginItemService: LoginItemManaging {
    public init() {}

    public var state: LoginItemState {
        #if os(macOS)
            switch SMAppService.mainApp.status {
            case .enabled: .enabled
            case .notRegistered: .disabled
            case .requiresApproval: .requiresApproval
            case .notFound: .unavailable
            @unknown default: .unavailable
            }
        #else
            .unavailable
        #endif
    }

    public func setEnabled(_ enabled: Bool) throws {
        #if os(macOS)
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        #endif
    }

    public func openSettings() {
        #if os(macOS)
            SMAppService.openSystemSettingsLoginItems()
        #endif
    }
}
