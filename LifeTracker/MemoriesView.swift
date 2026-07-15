import SwiftUI

/// The Memories page: a clean VSCO-style grid collage of all your photos.
/// Tap any photo to view it large.
struct MemoriesView: View {
    @ObservedObject private var store = PhotoStore.shared
    @State private var zoomedIndex: Int?

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 6)]

    var body: some View {
        ZStack {
            Color.pagePink.ignoresSafeArea()

            if store.images.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(store.images.indices, id: \.self) { i in
                            tile(i)
                        }
                    }
                    .padding(16)
                }
            }

            // Tap-to-enlarge overlay
            if let i = zoomedIndex, store.images.indices.contains(i) {
                ZStack {
                    Color.black.opacity(0.9).ignoresSafeArea()
                    Image(nsImage: store.images[i])
                        .resizable()
                        .scaledToFit()
                        .padding(40)
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation { zoomedIndex = nil }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .padding(24)
                        }
                        Spacer()
                    }
                }
                .transition(.opacity)
                .onTapGesture { withAnimation { zoomedIndex = nil } }
            }
        }
        .navigationTitle("Memories")
        .toolbar {
            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload photos")
        }
        .onAppear { store.reload() }
    }

    // MARK: Grid tile

    private func tile(_ i: Int) -> some View {
        Color.hoverPink
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(nsImage: store.images[i])
                    .resizable()
                    .scaledToFill()
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture { withAnimation { zoomedIndex = i } }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52))
            Text("No photos yet")
                .font(.title2.bold())
            Text("Send some pictures and they'll fill this collage 💕")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.inkOnPink.opacity(0.7))
        .padding()
    }
}
