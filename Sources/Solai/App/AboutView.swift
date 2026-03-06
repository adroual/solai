import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.dotted")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)

            Text("Solai")
                .font(.title.bold())

            Text("Session monitor for Claude Code")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()
                .padding(.horizontal, 40)

            Link("GitHub", destination: URL(string: "https://github.com/musicmi/solai")!)
                .font(.caption)
        }
        .padding(24)
        .frame(width: 260, height: 220)
    }
}
