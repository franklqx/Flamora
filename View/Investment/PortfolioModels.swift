import Foundation

struct PortfolioDataPoint {
    let date: Date
    let value: Double
}

enum PortfolioTimeRange: CaseIterable, Hashable {
    case oneWeek, oneMonth, threeMonths, ytd, all

    var label: String {
        switch self {
        case .oneWeek:      return "1W"
        case .oneMonth:     return "1M"
        case .threeMonths:  return "3M"
        case .ytd:          return "YTD"
        case .all:          return "ALL"
        }
    }
}
