import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case allProviders
    case lowestRemaining
    case iconOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allProviders:
            "모두 표시"
        case .lowestRemaining:
            "가장 부족한 항목"
        case .iconOnly:
            "아이콘만"
        }
    }
}
