import Foundation
import SwiftData

/// A single budget line — either income or an expense — on a given date.
@Model
final class BudgetEntry {
    var title: String
    var amount: Double
    var isIncome: Bool
    var category: String
    var date: Date
    var createdAt: Date

    init(title: String,
         amount: Double,
         isIncome: Bool,
         category: String,
         date: Date = .now) {
        self.title = title
        self.amount = amount
        self.isIncome = isIncome
        self.category = category
        self.date = date
        self.createdAt = .now
    }
}
