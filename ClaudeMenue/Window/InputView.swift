import SwiftUI

struct InputView: View {
    @State private var text = ""
    @State private var isLoading = false
    @State private var resultMessage: String? = nil

    var onSubmit: (String) async -> String
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let result = resultMessage {
                Text(result)
                    .font(.system(size: 15))
                    .foregroundColor(result.hasPrefix("✓") ? .green : .red)
                    .frame(height: 120, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                MarkdownTextEditor(
                    text: $text,
                    isDisabled: isLoading,
                    onSubmit: { Task { await submit() } },
                    onClose: onClose
                )
                .frame(height: 120)
            }

            Divider()
                .padding(.top, 12)

            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                    Text("Claude denkt…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !isLoading && resultMessage == nil {
                    Text("⌘↩")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button {
                        Task { await submit() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(
                                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color(nsColor: .placeholderTextColor)
                                    : .accentColor
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.top, 10)
        }
        .padding(20)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
    }

    private func submit() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        let result = await onSubmit(trimmed)
        isLoading = false
        text = ""
        resultMessage = result
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s anzeigen
        onClose()
    }
}
