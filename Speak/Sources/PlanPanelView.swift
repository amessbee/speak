import SwiftUI

struct PlanPanelView: View {
    @Binding var plan: Plan
    @State private var showAddSheet = false
    @State private var editingAction: PlanAction?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PLAN")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.06))

            // Action list
            if plan.actions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.12))
                    Text("No actions yet.\nClick + to add PDF slides, videos, images, or conditional branches.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(plan.actions) { action in
                        ActionRow(action: action) {
                            editingAction = action
                        } onDelete: {
                            plan.actions.removeAll { $0.id == action.id }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onMove { source, dest in
                        plan.actions.move(fromOffsets: source, toOffset: dest)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ActionEditorSheet(plan: plan) { newAction in
                plan.actions.append(newAction)
            }
        }
        .sheet(item: $editingAction) { action in
            ActionEditorSheet(plan: plan, editing: action) { updated in
                if let idx = plan.actions.firstIndex(where: { $0.id == updated.id }) {
                    plan.actions[idx] = updated
                }
            }
        }
    }
}

// MARK: - Action Row

struct ActionRow: View {
    let action: PlanAction
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: action.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(actionColor(action))
                .frame(width: 20)

            Text(action.displayName)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)

            Spacer()

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(IconButtonStyle())

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(IconButtonStyle(tint: .red))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private func actionColor(_ action: PlanAction) -> Color {
        switch action {
        case .pdfSlides: return Color(hex: "#8b5cf6")
        case .video:     return Color(hex: "#f59e0b")
        case .image:     return Color(hex: "#34d399")
        }
    }
}
