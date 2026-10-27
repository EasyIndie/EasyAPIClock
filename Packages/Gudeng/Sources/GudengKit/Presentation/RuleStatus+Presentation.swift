import GudengRuntime

public extension RuleStatus {
    var originText: String {
        origin == .bundled ? "内置规则" : "已下载规则"
    }
}
