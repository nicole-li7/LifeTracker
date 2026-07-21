import SwiftUI
import SwiftData
import Charts

/// Charts for the Budget page: where your money goes, and income vs. expenses
/// over time.
struct BudgetInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [BudgetEntry]
    let month: Date

    private var cal: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    categoryCard
                    trendCard
                }
                .padding()
            }
            .background(Color.pagePink)
            .navigationTitle("Budget Insights")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .frame(minWidth: 580, minHeight: 620)
    }

    // MARK: Spending by category

    private var categorySpending: [(category: String, total: Double)] {
        let monthExpenses = entries.filter {
            !$0.isIncome && cal.isDate($0.date, equalTo: month, toGranularity: .month)
        }
        return Dictionary(grouping: monthExpenses, by: { $0.category })
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spending by category — \(month.formatted(.dateTime.month(.wide)))")
                .font(.headline)
                .foregroundStyle(Color.inkOnPink)

            if categorySpending.isEmpty {
                Text("No expenses recorded this month.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                Chart(categorySpending, id: \.category) { item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Amount", item.total)
                    )
                    .foregroundStyle(Color.expenseRose)
                    .annotation(position: .top) {
                        Text(shortMoney(item.total))
                            .font(.caption2)
                            .foregroundStyle(Color.inkOnPink.opacity(0.7))
                    }
                }
                .chartXScale(domain: categorySpending.map { $0.category })
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.inkOnPink.opacity(0.1))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(shortMoney(amount))
                                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(Color.inkOnPink.opacity(0.8))
                    }
                }
                .frame(height: 260)
            }
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Income vs expenses over time

    private struct MonthTotals: Identifiable {
        let id = UUID()
        let label: String
        let income: Double
        let expense: Double
    }

    private var monthlyTotals: [MonthTotals] {
        (0..<6).reversed().compactMap { back -> MonthTotals? in
            guard let m = cal.date(byAdding: .month, value: -back, to: month) else { return nil }
            let inMonth = entries.filter { cal.isDate($0.date, equalTo: m, toGranularity: .month) }
            return MonthTotals(
                label: m.formatted(.dateTime.month(.abbreviated)),
                income: inMonth.filter { $0.isIncome }.reduce(0) { $0 + $1.amount },
                expense: inMonth.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            )
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Income vs. expenses — last 6 months")
                .font(.headline)
                .foregroundStyle(Color.inkOnPink)

            Chart {
                ForEach(monthlyTotals) { m in
                    BarMark(x: .value("Month", m.label), y: .value("Amount", m.income))
                        .foregroundStyle(by: .value("Type", "Income"))
                        .position(by: .value("Type", "Income"))
                    BarMark(x: .value("Month", m.label), y: .value("Amount", m.expense))
                        .foregroundStyle(by: .value("Type", "Expense"))
                        .position(by: .value("Type", "Expense"))
                }
            }
            .chartForegroundStyleScale([
                "Income": Color.incomeGreen,
                "Expense": Color.expenseRose,
            ])
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Color.inkOnPink.opacity(0.1))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(shortMoney(amount))
                                .foregroundStyle(Color.inkOnPink.opacity(0.6))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.inkOnPink.opacity(0.8))
                }
            }
            .frame(height: 240)
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Helpers

    private func shortMoney(_ v: Double) -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return v.formatted(.currency(code: code).precision(.fractionLength(0)))
    }
}
