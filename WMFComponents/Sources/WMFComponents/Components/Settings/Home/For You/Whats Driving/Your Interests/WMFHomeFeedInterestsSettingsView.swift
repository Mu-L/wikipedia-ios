// TODO: This is temporary UI — topic chips and article grid are placeholders pending final design.

import SwiftUI

public struct WMFHomeFeedInterestsSettingsView: View {

    @ObservedObject var viewModel: WMFHomeFeedInterestsSettingsViewModel
    @ObservedObject var appEnvironment = WMFAppEnvironment.current

    private let bottomContentInset: CGFloat

    var theme: WMFTheme { appEnvironment.theme }

    public init(viewModel: WMFHomeFeedInterestsSettingsViewModel, bottomContentInset: CGFloat = 0) {
        self.viewModel = viewModel
        self.bottomContentInset = bottomContentInset
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if viewModel.isSearchActive {
                    searchResults
                } else {
                    topicChips

                    if viewModel.isFetchingArticles {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else if !viewModel.gridViewModels.isEmpty {
                        WMFInterestArticleGridView(
                            viewModels: viewModel.gridViewModels,
                            theme: theme,
                            onTap: { vm in
                                viewModel.toggleArticleSelection(vm)
                            }
                        )
                    } else {
                        HStack {
                            Spacer()
                            Text(viewModel.emptyMessage)
                                .font(Font(WMFFont.for(.headline)))
                                .foregroundStyle(Color(uiColor: theme.secondaryText))
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding(.top, 80)
                    }
                }
            }
            .padding(.bottom, bottomContentInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: theme.paperBackground))
        .environment(\.colorScheme, theme.preferredColorScheme)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if viewModel.selectedCount == 0 {
            Text(viewModel.headerTitle)
                .font(Font(WMFFont.for(.boldTitle3)))
                .foregroundStyle(Color(uiColor: theme.text))
        } else {
            HStack {
                Text(viewModel.selectedCountTitle)
                    .font(Font(WMFFont.for(.boldTitle3)))
                    .foregroundStyle(Color(uiColor: theme.text))
                Spacer()
                Button(viewModel.deselectAllTitle) {
                    viewModel.deselectAll()
                }
                .font(Font(WMFFont.for(.subheadline)))
                .foregroundStyle(Color(uiColor: theme.link))
                .accessibilityIdentifier(AccessibilityIdentifiers.Interests.deselectAllButton)
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let magnifyingGlass = WMFSFSymbolIcon.for(symbol: .magnifyingGlass) {
                    Image(uiImage: magnifyingGlass)
                        .foregroundStyle(Color(uiColor: theme.secondaryText))
                }
                TextField(viewModel.searchPlaceholder, text: $viewModel.searchTerm)
                    .font(Font(WMFFont.for(.body)))
                    .foregroundStyle(Color(uiColor: theme.text))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier(AccessibilityIdentifiers.Interests.searchField)

                if viewModel.isSearchActive, let clearIcon = WMFSFSymbolIcon.for(symbol: .closeCircleFill) {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(uiImage: clearIcon)
                            .foregroundStyle(Color(uiColor: theme.secondaryText))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: theme.midBackground))
            )

            if viewModel.searchLanguages.count > 1 {
                Menu {
                    ForEach(viewModel.searchLanguages, id: \.languageCode) { language in
                        Button {
                            viewModel.selectSearchLanguage(language)
                        } label: {
                            if language == viewModel.searchLanguage {
                                Label(language.localizedName, systemImage: "checkmark")
                            } else {
                                Text(language.localizedName)
                            }
                        }
                    }
                } label: {
                    Text(viewModel.searchLanguage.languageCode.uppercased())
                        .font(Font(WMFFont.for(.boldSubheadline)))
                        .foregroundStyle(Color(uiColor: theme.link))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(uiColor: theme.border), lineWidth: 1)
                        )
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.Interests.searchLanguageButton)
            }
        }
    }

    private var searchResults: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if viewModel.isSearching && viewModel.searchRows.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                ForEach(viewModel.searchRows) { row in
                    WMFInterestSearchResultRow(row: row, theme: theme) {
                        viewModel.addSearchResult(row.result)
                    }
                    Divider()
                        .overlay(Color(uiColor: theme.border))
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Topic chips

    private var topicChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.topics, id: \.self) { topic in
                    TopicChipView(
                        title: topic.displayName,
                        isSelected: viewModel.selectedTopics.contains(topic),
                        theme: theme
                    )
                    .onTapGesture {
                        viewModel.toggleTopic(topic)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct WMFInterestSearchResultRow: View {

    let row: WMFHomeFeedInterestsSettingsViewModel.SearchRow
    let theme: WMFTheme
    let onTap: () -> Void

    @ObservedObject private var card: WMFInterestArticleCardViewModel

    init(row: WMFHomeFeedInterestsSettingsViewModel.SearchRow, theme: WMFTheme, onTap: @escaping () -> Void) {
        self.row = row
        self.theme = theme
        self.onTap = onTap
        self.card = row.card
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let uiImage = card.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(uiColor: theme.midBackground)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                WMFHtmlText(html: card.title, styles: HtmlUtils.Styles(font: WMFFont.for(.subheadline), boldFont: WMFFont.for(.boldSubheadline), italicsFont: WMFFont.for(.italicSubheadline), boldItalicsFont: WMFFont.for(.italicSubheadline), color: theme.text, linkColor: theme.link, lineSpacing: 1))
                if let description = card.description {
                    Text(description)
                        .font(Font(WMFFont.for(.caption1)))
                        .foregroundStyle(Color(uiColor: theme.secondaryText))
                        .lineLimit(2)
                }
            }

            Spacer()

            if let icon = WMFSFSymbolIcon.for(symbol: card.isSelected ? .checkmarkCircleFill : .plusCircle) {
                Image(uiImage: icon)
                    .foregroundStyle(Color(uiColor: theme.link))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            card.loadIfNeeded()
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.Interests.searchResultRow)
    }
}

private struct TopicChipView: View {
    let title: String
    let isSelected: Bool
    let theme: WMFTheme

    var body: some View {
        Text(title)
            .font(Font(WMFFont.for(.subheadline)))
            .foregroundStyle(isSelected ? Color(uiColor: theme.paperBackground) : Color(uiColor: theme.link))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(uiColor: theme.link) : Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(uiColor: theme.link), lineWidth: 1.5)
            )
    }
}
