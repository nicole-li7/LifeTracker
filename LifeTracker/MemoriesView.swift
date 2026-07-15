import SwiftUI

/// The Memories page: a large featured photo that rotates, with a thumbnail
/// strip of the whole collection below.
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
                VStack(spacing: 22) {
                    featured
                    thumbnailStrip
                }
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            if index >= store.images.count { index = 0 }
        }
        .onReceive(timer) { _ in advance() }
    }

    // MARK: Featured photo (polaroid frame)

    private var featured: some View {
        VStack(spacing: 12) {
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
            .frame(maxWidth: 760, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 1.0), value: index)

            HStack(spacing: 6) {
                Image(systemName: "heart.fill").foregroundStyle(Color.brandPink)
                Text("Memories")
                    .font(.headline)
                    .foregroundStyle(Color.inkOnPink)
                Spacer()
                Text("\(index + 1) / \(store.images.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.inkOnPink.opacity(0.5))
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.brandPink.opacity(0.6), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        .frame(maxWidth: 800)
        .onTapGesture { advance() }
    }

    // MARK: Thumbnail strip

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.images.indices, id: \.self) { i in
                    Image(nsImage: store.images[i])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 62, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(i == index ? Color.brandPink : Color.white,
                                              lineWidth: i == index ? 3 : 2)
                        )
                        .opacity(i == index ? 1 : 0.6)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.6)) { index = i }
                        }
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 800)
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
