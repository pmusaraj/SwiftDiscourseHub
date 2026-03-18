import SwiftUI

struct SmallActionView: View {
    let post: Post

    private var iconName: String {
        switch post.actionCode {
        case "closed.enabled", "autoclosed.enabled":
            "lock.fill"
        case "closed.disabled", "autoclosed.disabled":
            "lock.open.fill"
        case "archived.enabled":
            "archivebox.fill"
        case "archived.disabled":
            "archivebox"
        case "pinned.enabled", "pinned_globally.enabled":
            "pin.fill"
        case "pinned.disabled", "pinned_globally.disabled":
            "pin.slash.fill"
        case "visible.enabled":
            "eye.fill"
        case "visible.disabled":
            "eye.slash.fill"
        case "split_topic":
            "arrow.branch"
        case "invited_user", "invited_group":
            "plus.circle.fill"
        case "removed_user", "removed_group", "user_left":
            "minus.circle.fill"
        case "tags_changed":
            "tag.fill"
        case "category_changed":
            "folder.fill"
        case "autobumped":
            "hand.point.right.fill"
        default:
            "info.circle.fill"
        }
    }

    private func descriptionText(who: String) -> String {
        switch post.actionCode {
        case "closed.enabled", "autoclosed.enabled":
            return "\(who) closed this topic"
        case "closed.disabled", "autoclosed.disabled":
            return "\(who) opened this topic"
        case "archived.enabled":
            return "\(who) archived this topic"
        case "archived.disabled":
            return "\(who) unarchived this topic"
        case "pinned.enabled", "pinned_globally.enabled":
            return "\(who) pinned this topic"
        case "pinned.disabled", "pinned_globally.disabled":
            return "\(who) unpinned this topic"
        case "visible.enabled":
            return "\(who) listed this topic"
        case "visible.disabled":
            return "\(who) unlisted this topic"
        case "split_topic":
            return "\(who) split this topic"
        case "invited_user":
            return "\(who) invited a user"
        case "invited_group":
            return "\(who) invited a group"
        case "removed_user":
            return "\(who) removed a user"
        case "removed_group":
            return "\(who) removed a group"
        case "user_left":
            return "\(who) left this topic"
        case "tags_changed":
            return "\(who) changed tags"
        case "category_changed":
            return "\(who) changed the category"
        case "autobumped":
            return "This topic was automatically bumped"
        default:
            return "\(who) performed an action"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Text(descriptionText(who: post.username ?? "System"))
                .font(Theme.Fonts.metadata)
                .foregroundStyle(.secondary)

            Spacer()

            if let createdAt = post.createdAt {
                RelativeTimeText(dateString: createdAt)
                    .font(Theme.Fonts.metadataSmall)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
    }
}
