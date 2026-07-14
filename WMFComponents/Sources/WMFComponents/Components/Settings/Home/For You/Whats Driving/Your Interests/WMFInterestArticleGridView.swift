import SwiftUI
import WMFData

struct WMFInterestArticleGridView: View {

    let viewModels: [WMFInterestArticleCardViewModel]
    let theme: WMFTheme
    let onTap: (WMFInterestArticleCardViewModel) -> Void

    private var columns: (left: [WMFInterestArticleCardViewModel], right: [WMFInterestArticleCardViewModel]) {
        var left: [WMFInterestArticleCardViewModel] = []
        var right: [WMFInterestArticleCardViewModel] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for vm in viewModels {
            if leftHeight <= rightHeight {
                left.append(vm)
                leftHeight += estimatedHeight(for: vm)
            } else {
                right.append(vm)
                rightHeight += estimatedHeight(for: vm)
            }
        }
        return (left, right)
    }

    private func estimatedHeight(for vm: WMFInterestArticleCardViewModel) -> CGFloat {
        let imageHeight: CGFloat = vm.thumbnailURL != nil ? 100 : 0
        let titleLines = max(1, Int(ceil(Double(vm.title.count) / 18.0)))
        let titleHeight = CGFloat(titleLines) * 20
        let descriptionHeight: CGFloat
        if let desc = vm.description {
            let lines = max(1, Int(ceil(Double(desc.count) / 20.0)))
            descriptionHeight = CGFloat(lines) * 16
        } else {
            descriptionHeight = 0
        }
        return imageHeight + titleHeight + descriptionHeight + 32
    }

    var body: some View {
        let cols = columns
        HStack(alignment: .top, spacing: 12) {
            column(cols.left)
            column(cols.right)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func column(_ items: [WMFInterestArticleCardViewModel]) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { vm in
                WMFInterestArticleCardView(viewModel: vm, theme: theme)
                    .onTapGesture {
                        onTap(vm)
                    }
            }
        }
    }
}

private struct WMFInterestArticleCardView: View {

    @ObservedObject var viewModel: WMFInterestArticleCardViewModel
    let theme: WMFTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let uiImage = viewModel.uiImage {
                // The container drives layout; scaledToFill images would otherwise report
                // their own width and inflate the card beyond its column width
                Color.clear
                    .frame(height: 100)
                    .overlay(
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
                    .contentShape(Rectangle())
            }
            VStack(alignment: .leading, spacing: 4) {
                WMFHtmlText(html: viewModel.title, styles: HtmlUtils.Styles(font: WMFFont.for(.semiboldHeadline), boldFont: WMFFont.for(.boldHeadline), italicsFont: WMFFont.for(.semiboldHeadline), boldItalicsFont: WMFFont.for(.boldHeadline), color: theme.text, linkColor: theme.link, lineSpacing: 1))
                if let description = viewModel.description {
                    Text(description)
                        .font(Font(WMFFont.for(.callout)))
                        .foregroundStyle(Color(uiColor: theme.secondaryText))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(viewModel.isSelected ? Color(uiColor: theme.addition) : Color.clear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: theme.paperBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(uiColor: theme.newBorder), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isSelected, let checkmark = WMFSFSymbolIcon.for(symbol: .checkmark, font: .subheadline) {
                Image(uiImage: checkmark)
                    .foregroundStyle(Color(uiColor: theme.link))
                    .padding(8)
            }
        }
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }
}
