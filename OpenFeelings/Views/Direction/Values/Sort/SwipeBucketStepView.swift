import SwiftData
import SwiftUI
import UIKit

/// Tinder-style bucket step for the value sort. The user drags the front
/// card left (`.notForMe`) or right (`.veryImportant`). Past the commit
/// threshold, a color wash and a stamp overlay appear; releasing past the
/// threshold flies the card off-screen and advances to the next card.
/// Below threshold on release, the card springs back.
///
/// The middle `.important` bucket is no longer produced by this view —
/// the underlying `SortBucket` enum case stays for backward compatibility
/// with old `ValueSort` rows in the store.
struct SwipeBucketStepView: View {
    let session: SortSession
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @State private var showingAddCustom = false
    @State private var newCustomName = ""

    @State private var dragOffset: CGSize = .zero

    /// 30% of the card's width is the commit threshold.
    private static let thresholdFraction: CGFloat = 0.30
    private static let stampStartFraction: CGFloat = 0.15

    var body: some View {
        VStack(spacing: CGFloat.OF.md) {
            Text("\(session.index + 1) of \(session.deck.count)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.OF.textMuted)

            if session.currentRef != nil {
                GeometryReader { proxy in
                    cardStack(width: proxy.size.width)
                }
                .frame(maxWidth: .infinity, minHeight: 280)
                .padding(.horizontal, CGFloat.OF.md)
                swipeHints
            } else {
                advancePrompt
            }

            controls
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Sort values")
        .sheet(isPresented: $showingAddCustom) {
            AddCustomValueSheet(name: $newCustomName) { trimmed in
                let custom = CustomValue(name: trimmed)
                context.insert(custom)
                try? context.save()
                session.appendCustom(ValueRef.makeCustomRef(custom.id))
                showingAddCustom = false
            }
        }
    }

    // MARK: - Card stack

    @ViewBuilder
    private func cardStack(width: CGFloat) -> some View {
        ZStack {
            ForEach(visibleStack.reversed(), id: \.self) { ref in
                let depth = visibleStack.firstIndex(of: ref) ?? 0
                cardView(ref: ref, depth: depth, width: width)
            }
        }
    }

    /// The visible stack: current card on top, plus up to 2 cards peeking
    /// behind it. Reversed when rendered so the front card is drawn last
    /// (on top in the ZStack).
    private var visibleStack: [String] {
        let start = session.index
        let end = min(start + 3, session.deck.count)
        guard start < end else { return [] }
        return Array(session.deck[start..<end])
    }

    @ViewBuilder
    private func cardView(ref: String, depth: Int, width: CGFloat) -> some View {
        let isFront = depth == 0
        let translation = isFront ? dragOffset : .zero
        let progress = isFront ? horizontalProgress(width: width) : 0
        let tilt = isFront ? progress * 12 : 0
        let bucket = isFront ? committedBucket(progress: progress) : nil
        let stampOpacity = isFront ? stampAlpha(progress: progress) : 0

        cardContent(ref: ref)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .fill(Color.OF.surface)
                    if let bucket {
                        RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                            .fill(washColor(for: bucket).opacity(min(abs(progress), 1) * 0.35))
                    }
                }
            )
            .overlay(alignment: bucket == .veryImportant ? .topLeading : .topTrailing) {
                if let bucket {
                    stamp(for: bucket).opacity(stampOpacity)
                }
            }
            .scaleEffect(isFront ? 1 : 1 - CGFloat(depth) * 0.04)
            .offset(x: translation.width,
                    y: translation.height + CGFloat(depth) * 6)
            .opacity(isFront ? 1 : 0.45 - CGFloat(depth) * 0.15)
            .rotationEffect(.degrees(tilt))
            .zIndex(isFront ? 100 : Double(-depth))
            .gesture(isFront ? dragGesture(width: width, ref: ref) : nil)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: ref))
            .accessibilityActions {
                if isFront {
                    Button("Mark important") { commit(.veryImportant, ref: ref) }
                    Button("Mark not for me") { commit(.notForMe, ref: ref) }
                }
            }
    }

    @ViewBuilder
    private func cardContent(ref: String) -> some View {
        VStack(spacing: CGFloat.OF.xs) {
            Text(ValueRef.displayName(for: ref, customs: customs))
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.OF.text)
            if !ValueRef.isCustom(ref),
               let def = ValueTaxonomy.definition(id: ref) {
                Text(def.description)
                    .font(.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, CGFloat.OF.xl)
        .padding(.horizontal, CGFloat.OF.lg)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("value-sort.card")
    }

    @ViewBuilder
    private func stamp(for bucket: SortBucket) -> some View {
        let color = washColor(for: bucket)
        Text(bucket == .veryImportant ? "IMPORTANT" : "NOT FOR ME")
            .font(.headline.weight(.heavy))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, CGFloat.OF.sm)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.10))
            )
            .rotationEffect(.degrees(bucket == .veryImportant ? -15 : 15))
            .padding(CGFloat.OF.md)
    }

    @ViewBuilder
    private var swipeHints: some View {
        HStack {
            Text("← Not for me")
            Spacer()
            Text("Important →")
        }
        .font(.caption)
        .foregroundStyle(Color.OF.textMuted)
        .padding(.top, CGFloat.OF.xs)
        .padding(.horizontal, CGFloat.OF.md)
    }

    @ViewBuilder
    private var controls: some View {
        HStack {
            Button {
                session.undoLastBucket()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(session.history.isEmpty)
            Spacer()
            Button {
                newCustomName = ""
                showingAddCustom = true
            } label: {
                Label("Add your own value", systemImage: "plus")
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var advancePrompt: some View {
        VStack(spacing: CGFloat.OF.sm) {
            Text("All values sorted.")
                .font(.headline)
                .foregroundStyle(Color.OF.text)
            Button("Continue") { session.advancePhase() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, CGFloat.OF.xxl)
    }

    // MARK: - Drag math

    private func horizontalProgress(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        return dragOffset.width / width
    }

    private func committedBucket(progress: CGFloat) -> SortBucket? {
        if progress > Self.stampStartFraction { return .veryImportant }
        if progress < -Self.stampStartFraction { return .notForMe }
        return nil
    }

    private func stampAlpha(progress: CGFloat) -> Double {
        let mag = abs(progress)
        guard mag > Self.stampStartFraction else { return 0 }
        let range = Self.thresholdFraction - Self.stampStartFraction
        return min(1.0, Double((mag - Self.stampStartFraction) / range))
    }

    private func washColor(for bucket: SortBucket) -> Color {
        switch bucket {
        case .veryImportant: return .green
        case .notForMe:      return .red
        case .important:     return Color.OF.accent.color(for: .dark) // unused in new flow
        }
    }

    private func dragGesture(width: CGFloat, ref: String) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let progress = value.translation.width / width
                if progress > Self.thresholdFraction {
                    commit(.veryImportant, ref: ref)
                } else if progress < -Self.thresholdFraction {
                    commit(.notForMe, ref: ref)
                } else {
                    withAnimation(.OF.gentle) { dragOffset = .zero }
                }
            }
    }

    private func commit(_ bucket: SortBucket, ref: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if reduceMotion {
            session.bucket(ref, into: bucket)
            dragOffset = .zero
        } else {
            let flyAwayWidth: CGFloat = bucket == .veryImportant ? 800 : -800
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                dragOffset = CGSize(width: flyAwayWidth, height: dragOffset.height)
            } completion: {
                session.bucket(ref, into: bucket)
                dragOffset = .zero
            }
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for ref: String) -> String {
        let name = ValueRef.displayName(for: ref, customs: customs)
        if !ValueRef.isCustom(ref),
           let def = ValueTaxonomy.definition(id: ref) {
            return "\(name). \(def.description)"
        }
        return name
    }
}
