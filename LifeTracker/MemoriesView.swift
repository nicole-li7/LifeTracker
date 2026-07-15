import SwiftUI

/// The Memories page: a rotating slideshow of your photos in a cute frame.
struct MemoriesView: View {
    @ObservedObject private var store = PhotoStore.shared
    @State private var index = 0

    // Advance every 4 seconds.
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.pagePink.ignoresSafeArea()
            if store.images.isEmpty {
                emptyState
            } else {
                polaroid
            }
        }
        .navigationTitle("Memories")
        .toolbar {
            Button {
                store.reload()
                index = 0
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload photos")
        }
        .onAppear {
            store.reload()
            index = 0
        }
        .onReceive(timer) { _ in advance() }
    }

    // MARK: Slideshow frame

    private var polaroid: some View {
        VStack(spacing: 14) {
            ZStack {
                Color.hoverPink
                ForEach(store.images.indices, id: \.self) { i in
                    if i == index {
                        Image(nsImage: store.images[i])
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    }
                }
            }
            .frame(width: 520, height: 520)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 1.0), value: index)

            // Polaroid caption
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.brandPink)
                Text("Memories")
                    .font(.headline)
                    .foregroundStyle(Color.inkOnPink)
                Spacer()
                if store.images.count > 1 {
                    Text("\(index + 1) / \(store.images.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.inkOnPink.opacity(0.5))
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.brandPink.opacity(0.6), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        .onTapGesture { advance() }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52))
            Text("No photos yet")
                .font(.title2.bold())
            Text("Send some pictures and they'll rotate here in a cute frame 💕")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.inkOnPink.opacity(0.7))
        .padding()
    }

    private func advance() {
        guard !store.images.isEmpty else { return }
        index = (index + 1) % store.images.count
    }
}
