import AppKit
import SwiftUI

struct LibrarySearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OpenMyChrome.muted)
            TextField("搜索字幕", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(isFocused)
                .onSubmit {
                    isFocused.wrappedValue = false
                    PlaybackWindowFocusController.resign(in: NSApp.keyWindow)
                }
                .onExitCommand(perform: resignSearchFocus)
            if !query.isEmpty {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(OpenMyChrome.faint)
                }
                .buttonStyle(.plain)
                .help("清空搜索")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30)
        .background(OpenMyChrome.raise, in: RoundedRectangle(cornerRadius: OpenMyChrome.radiusMd, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OpenMyChrome.radiusMd, style: .continuous)
                .strokeBorder(
                    isFocused.wrappedValue ? OpenMyChrome.ink : OpenMyChrome.fieldBorder,
                    lineWidth: isFocused.wrappedValue ? 2 : 1
                )
        }
        .help("搜索全部视频的字幕（⌘F）")
    }

    private func clear() {
        query = ""
        isFocused.wrappedValue = true
    }

    private func resignSearchFocus() {
        query = ""
        isFocused.wrappedValue = false
        PlaybackWindowFocusController.resign(in: NSApp.keyWindow)
    }
}

struct LibrarySearchResults: View {
    let query: String
    let isIndexReady: Bool
    let groups: [LibrarySubtitleSearch.Group]
    let selectedHitID: String?
    let onSelect: (LibrarySubtitleSearch.Hit) -> Void

    var body: some View {
        if !isIndexReady {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("正在读取字幕…")
                    .font(.system(size: 12))
                    .foregroundStyle(OpenMyChrome.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groups.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(OpenMyChrome.muted)
                Text("没有找到「\(query)」")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OpenMyChrome.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("试试别的词，或清空搜索回到队列。")
                    .font(.system(size: 11))
                    .foregroundStyle(OpenMyChrome.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(groups) { group in
                        groupBlock(group)
                    }
                }
                .padding(.horizontal, SidebarQueueLayout.listHorizontalPadding)
                .padding(.bottom, SidebarQueueLayout.listBottomPadding)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func groupBlock(_ group: LibrarySubtitleSearch.Group) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(QueueRowMeta.displayTitle(title: group.item.title, author: group.item.author))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OpenMyChrome.muted)
                    .lineLimit(1)
                Text("\(group.hits.count)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(OpenMyChrome.faint)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            ForEach(Array(group.hits.prefix(40))) { hit in
                Button {
                    onSelect(hit)
                } label: {
                    hitRow(hit, isSelected: selectedHitID == hit.id)
                }
                .buttonStyle(.plain)
            }
            if group.hits.count > 40 {
                Text("其余 \(group.hits.count - 40) 处未列出")
                    .font(.system(size: 11))
                    .foregroundStyle(OpenMyChrome.faint)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
        }
    }

    private func hitRow(_ hit: LibrarySubtitleSearch.Hit, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LibrarySubtitleSearch.formatTimecode(hit.startTime))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(isSelected ? OpenMyChrome.ink : OpenMyChrome.muted)
                    .frame(width: 52, alignment: .trailing)
                Text(SubtitleSentenceBlocks.withCJKLatinSpacing(LibrarySubtitleSearch.previewText(hit.text)))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(OpenMyChrome.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let context = contextLine(hit) {
                Text(context)
                    .font(.system(size: 11))
                    .foregroundStyle(OpenMyChrome.faint)
                    .lineLimit(1)
                    .padding(.leading, 60)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: OpenMyChrome.radiusMd, style: .continuous)
                    .fill(OpenMyChrome.rowSelected)
            }
        }
        .contentShape(Rectangle())
    }

    private func contextLine(_ hit: LibrarySubtitleSearch.Hit) -> String? {
        let parts = [hit.contextBefore, hit.contextAfter].compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  ·  ")
    }
}
