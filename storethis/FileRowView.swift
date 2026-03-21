import SwiftUI

struct FileRowView: View {
    let object: GCSObject
    let onDelete: () -> Void
    var localization: LocalizationManager = .shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            Text(object.displayName)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !object.isFolder {
                Text(object.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            if !object.isFolder {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(localization.localized("file.delete"), systemImage: "trash")
                }
            }
        }
    }

    private var iconName: String {
        if object.isFolder {
            return "folder.fill"
        }
        switch object.contentType {
        case "image/png", "image/jpeg", "image/gif", "image/webp":
            return "photo"
        case "application/pdf":
            return "doc.richtext"
        case "text/plain":
            return "doc.text"
        case "application/json":
            return "curlybraces"
        default:
            return "doc"
        }
    }

    private var iconColor: Color {
        object.isFolder ? .accentColor : .secondary
    }
}
