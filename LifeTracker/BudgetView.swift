import SwiftUI
import SwiftData

/// The Budget page: month-by-month income & expenses with running totals.
struct BudgetView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BudgetEntry.date, order: .reverse) private var entries: [BudgetEntry]

    @State private var visibleMonth: Date = .now
    @State private var showInsights = false

    // New-entry form state
    @State private var newTitle = ""
    @State private var newAmount: Double? = nil
    @State private var newIsIncome = false
    @State private var newCategory = ""

    private let categories = ["Food", "Rent", "Transport", "Shopping",
                              "Fun", "Bills", "Health", "Income", "Other"]

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            Divider().opacity(0.3)
            ScrollView {
                VStack(spacing: 16) {
                    totalBanner
                    summaryTiles
                    addForm
                    entryList
                }
                .padding()
            }
        }
        .background(Color.pagePink)
        .navigationTitle("Budget")
        .sheet(isPresented: $showInsights) {
            BudgetInsightsView(month: visibleMonth)
        }
    }

    // MARK: Header

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
            Spacer()
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
            Spacer()
            Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
            Button { showInsights = true } label: {
                Label("Insights", systemImage: "chart.bar.xaxis")
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.hoverPink, in: Capsule())
            }
            .buttonStyle(.plain)
            Button("This Month") { visibleMonth = .now }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.brandPink, in: Capsule())
        }
        .font(.title3)
        .foregroundStyle(Color.inkOnPink)
        .padding()
    }

    // MARK: Running total

    /// Your money on hand: every income minus every expense, up through the end
    /// of the month you're viewing (so leftover money carries over each month).
    private var runningTotal: Double {
        guard let monthEnd = cal.dateInterval(of: .month, for: visibleMonth)?.end else { return 0 }
        return entries
            .filter { $0.date < monthEnd }
            .reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }

    private var totalBanner: some View {
        VStack(spacing: 4) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(Color.inkOnPink.opacity(0.7))
            Text(money(runningTotal))
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(runningTotal >= 0 ? Color.incomeGreen : Color.expenseRose)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("carried through \(visibleMonth.formatted(.dateTime.month(.wide).year()))")
                .font(.caption)
                .foregroundStyle(Color.inkOnPink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Summary

    private var summaryTiles: some View {
        HStack(spacing: 12) {
            tile("Income", total: monthIncome, color: .incomeGreen)
            tile("Expenses", total: monthExpenses, color: .expenseRose)
            tile("Balance", total: monthBalance, color: monthBalance >= 0 ? .incomeGreen : .expenseRose)
        }
    }

    private func tile(_ label: String, total: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.inkOnPink.opacity(0.7))
            Text(money(total))
                .font(.title3.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Add form

    private var addForm: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Description", text: $newTitle)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
                TextField("Amount", value: $newAmount, format: .number)
                    .textFieldStyle(.plain)
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
                    .onSubmit(add)
            }
            .foregroundStyle(Color.inkOnPink)
            .padding(10)
            .background(Color.hoverPink, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Picker("", selection: $newIsIncome) {
                    Text("Expense").tag(false)
                    Text("Income").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)

                Picker("", selection: $newCategory) {
                    Text("Category").tag("")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()

                Spacer()

                Button(action: add) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color.brandPink, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.inkOnPink)
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.5)
            }
            .foregroundStyle(Color.inkOnPink)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Entry list

    private var entryList: some View {
        VStack(spacing: 6) {
            if monthEntries.isEmpty {
                Text("No entries this month. Add one above.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(monthEntries) { entry in
                    BudgetRow(entry: entry, onDelete: { context.delete(entry) })
                }
            }
        }
    }

    // MARK: Data

    private var monthEntries: [BudgetEntry] {
        entries.filter { cal.isDate($0.date, equalTo: visibleMonth, toGranularity: .month) }
    }
    private var monthIncome: Double {
        monthEntries.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    private var monthExpenses: Double {
        monthEntries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    private var monthBalance: Double { monthIncome - monthExpenses }

    private var canAdd: Bool {
        !newTitle.trimmingCharacters(in: .whitespaces).isEmpty && (newAmount ?? 0) > 0
    }

    private func add() {
        guard canAdd, let amount = newAmount else { return }
        let category = newCategory.isEmpty ? (newIsIncome ? "Income" : "Other") : newCategory
        context.insert(BudgetEntry(
            title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            isIncome: newIsIncome,
            category: category,
            date: monthAnchorDate()
        ))
        newTitle = ""
        newAmount = nil
        newCategory = ""
    }

    /// Dates new entries to today if viewing the current month, else to the 1st
    /// of the month being viewed.
    private func monthAnchorDate() -> Date {
        if cal.isDate(visibleMonth, equalTo: .now, toGranularity: .month) { return .now }
        return cal.dateInterval(of: .month, for: visibleMonth)?.start ?? visibleMonth
    }

    private func changeMonth(by months: Int) {
        if let d = cal.date(byAdding: .month, value: months, to: visibleMonth) {
            visibleMonth = d
        }
    }

    private func money(_ v: Double) -> String {
        v.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

/// One budget entry row: date, title, category chip, and signed amount.
struct BudgetRow: View {
    let entry: BudgetEntry
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.inkOnPink.opacity(0.6))
                .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.callout)
                    .foregroundStyle(Color.inkOnPink)
                Text(entry.category)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkOnPink.opacity(0.8))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color.hoverPink, in: Capsule())
            }

            Spacer()

            Text((entry.isIncome ? "+" : "−") + money(entry.amount))
                .font(.callout.bold().monospacedDigit())
                .foregroundStyle(entry.isIncome ? Color.incomeGreen : Color.expenseRose)

            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.caption)
                        .foregroundStyle(Color.inkOnPink.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(hovering ? Color.hoverPink : .white, in: RoundedRectangle(cornerRadius: 10))
        .onHover { hovering = $0 }
    }

    private func money(_ v: Double) -> String {
        v.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
