import SwiftUI
import SwiftData
import Charts

/// Charts for the Gym page: track how your weight on an exercise changes over
/// time.
struct GymProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    @State private var selectedName = ""

    var body: some View {
        NavigationStack {
            Group {
                if exerciseNames.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Color.pagePink)
            .navigationTitle("Gym Progress")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .frame(minWidth: 580, minHeight: 560)
        .onAppear {
            if selectedName.isEmpty { selectedName = defaultName }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Exercise", selection: $selectedName) {
                ForEach(exerciseNames, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Color.inkOnPink)

            if points.isEmpty {
                Text("Log some sets with weights for this exercise to see progress.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                statsRow
                chartCard
                Spacer(minLength: 0)
            }
        }
        .padding()
    }

    // MARK: Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heaviest set over time")
                .font(.headline)
                .foregroundStyle(Color.inkOnPink)

            Chart(points, id: \.date) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Weight", p.maxWeight)
                )
                .foregroundStyle(Color.brandPink)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Weight", p.maxWeight)
                )
                .foregroundStyle(Color.brandPink)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Color.inkOnPink.opacity(0.1))
                    AxisValueLabel {
                        if let w = value.as(Double.self) {
                            Text("\(Int(w)) lb").foregroundStyle(Color.inkOnPink.opacity(0.6))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.month().day())
                        .foregroundStyle(Color.inkOnPink.opacity(0.8))
                }
            }
            .frame(height: 300)
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat("Current", value: points.last?.maxWeight ?? 0)
            stat("Best", value: points.map { $0.maxWeight }.max() ?? 0)
            stat("Change", value: (points.last?.maxWeight ?? 0) - (points.first?.maxWeight ?? 0), signed: true)
        }
    }

    private func stat(_ label: String, value: Double, signed: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Color.inkOnPink.opacity(0.7))
            Text((signed && value > 0 ? "+" : "") + "\(Int(value)) lb")
                .font(.title3.bold())
                .foregroundStyle(signed
                                 ? (value >= 0 ? Color.incomeGreen : Color.expenseRose)
                                 : Color.inkOnPink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 44))
            Text("No exercises yet").font(.title3)
            Text("Log some workouts and their sets to see your progress.")
                .font(.subheadline).opacity(0.7).multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.inkOnPink.opacity(0.7))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: Data

    private var exerciseNames: [String] {
        Set(exercises.map { $0.name.trimmingCharacters(in: .whitespaces) })
            .filter { !$0.isEmpty }
            .sorted()
    }

    /// The exercise name that appears in the most workouts (a good default).
    private var defaultName: String {
        Dictionary(grouping: exercises, by: { $0.name })
            .max { $0.value.count < $1.value.count }?.key
            ?? exerciseNames.first ?? ""
    }

    /// One point per workout: the heaviest set of the selected exercise that day.
    private var points: [(date: Date, maxWeight: Double)] {
        exercises
            .filter { $0.name == selectedName }
            .compactMap { ex -> (Date, Double)? in
                guard let date = ex.workout?.date,
                      let maxW = ex.sets.map({ $0.weight }).max() else { return nil }
                return (date, maxW)
            }
            .sorted { $0.0 < $1.0 }
            .map { (date: $0.0, maxWeight: $0.1) }
    }
}
