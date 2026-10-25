import SwiftUI

struct CalendarAccountsView: View {
    @Bindable var model: CalendarAccountsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Accounts & Calendars").appText(.title, weight: .semibold).accessibilityAddTraits(.isHeader)
            Picker("Calendar view", selection: $model.page) {
                Text("Connections").tag(CalendarAccountsPage.connections)
                Text("Visible calendars").tag(CalendarAccountsPage.calendars)
            }.pickerStyle(.segmented).labelsHidden().appText(.body)
            if model.page == .connections { ProviderConnectionsView(model: model) }
            else { CalendarSelectionView(model: model) }
        }.padding(AppSpacing.sm).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppColors.background).foregroundStyle(AppColors.primary).tint(AppColors.accent)
            .onAppear(perform: model.refresh)
    }
}
struct ProviderConnectionsView: View {
    @Bindable var model: CalendarAccountsViewModel
    @Environment(\.dynamicTypeSize) private var textSize
    private var iconColumn: CGFloat { AppLayout.providerIconColumn * AppTypography.scale(for: textSize) }
    private let columns = [GridItem(.flexible(), spacing: AppSpacing.xs, alignment: .top), GridItem(.flexible(), spacing: AppSpacing.xs, alignment: .top)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Calendars synchronized through macOS are available now.").appText(.caption).foregroundStyle(AppColors.secondary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(model.providers) { card in
                        Grid(alignment: .topLeading, horizontalSpacing: AppSpacing.xs, verticalSpacing: AppSpacing.xs) {
                            GridRow {
                                ProviderIcon(kind: card.kind).frame(width: iconColumn)
                                Text(card.kind.title).appText(.body, weight: .semibold)
                                    .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("provider-name-\(card.kind.rawValue)")
                            }.accessibilityElement(children: .contain)
                            GridRow {
                                Image(systemName: "checkmark.circle").appText(.caption).foregroundStyle(AppColors.secondary)
                                    .frame(width: iconColumn).opacity(card.state == .connected ? 1 : 0).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text(card.statusDescription).appText(.caption).foregroundStyle(AppColors.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("provider-status-\(card.kind.rawValue)")
                                    if card.canConnect {
                                        Button(card.state == .permissionDenied ? "Open Privacy Settings" : "Connect", action: { model.requestConnection(card.kind) })
                                            .appText(.body, weight: .medium).buttonStyle(MeetrailButtonStyle()).disabled(model.connecting)
                                            .accessibilityLabel(card.state == .permissionDenied ? "Open calendar privacy settings" : "Connect \(card.kind.title)")
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.accessibilityElement(children: .contain)
                        }.appText(.body, weight: .semibold).padding(AppSpacing.xs).frame(maxWidth: .infinity, minHeight: AppLayout.providerCardHeight, alignment: .topLeading)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
                            .overlay { RoundedRectangle(cornerRadius: AppLayout.cornerRadius).strokeBorder(AppColors.border, lineWidth: 1).allowsHitTesting(false) }
                            .accessibilityElement(children: .contain).accessibilityIdentifier("provider-card-\(card.kind.rawValue)")
                    }
                }
                if model.connecting { ProgressView("Waiting for macOS calendar permission…").appText(.body) }
                if let error = model.error { InlineMessage(text: error, isError: true) }
            }
        }
    }
}
struct CalendarSelectionView: View {
    @Bindable var model: CalendarAccountsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Text("Visible calendars").appText(.section, weight: .semibold).accessibilityAddTraits(.isHeader)
                Spacer(minLength: AppSpacing.xs)
                Text("\(model.selectedCount) selected").appText(.caption, weight: .medium).accessibilityIdentifier("selected-calendar-count")
            }
            TextField("Search calendars", text: $model.search).textFieldStyle(.roundedBorder).appText(.body).accessibilityLabel("Search calendars")
            if model.missingCount > 0 { InlineMessage(text: "\(model.missingCount) selected calendars are unavailable. Selections are retained.") }
            if !model.hasConnectedProvider {
                InlineMessage(text: "Connect system calendars to choose visible calendars.")
                Button("Connect Apple / System Calendars", action: model.requestSystemConnection).appText(.body).buttonStyle(MeetrailButtonStyle(prominent: true))
            } else if model.catalog.calendars.isEmpty { InlineMessage(text: "No calendars are currently exposed by macOS. Direct provider connections are coming soon.") }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(model.groups) { group in
                        DisclosureGroup(isExpanded: Binding(get: { group.expanded }, set: { model.setExpanded(group.id, expanded: $0) })) {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                HStack(spacing: AppSpacing.xs) {
                                    Button("Select All") { model.selectGroup(group.id, visible: true) }.accessibilityLabel("Select all calendars in \(group.account.name)")
                                    Button("Deselect All") { model.selectGroup(group.id, visible: false) }.accessibilityLabel("Deselect all calendars in \(group.account.name)")
                                }.appText(.caption).buttonStyle(MeetrailButtonStyle())
                                ForEach(group.calendars) { calendar in
                                    Toggle(isOn: Binding(get: { model.selectedIDs.contains(calendar.id) }, set: { model.setCalendar(calendar.id, visible: $0) })) {
                                        HStack(spacing: AppSpacing.xs) {
                                            Circle().fill(AppColors.calendar(calendar.color)).frame(width: AppSpacing.xs, height: AppSpacing.xs).accessibilityHidden(true)
                                            Text(calendar.name).appText(.body).lineLimit(2)
                                        }
                                    }.toggleStyle(.checkbox).frame(maxWidth: .infinity, alignment: .leading).disabled(!calendar.isAvailable).accessibilityLabel(calendar.name)
                                }
                            }.padding(.top, AppSpacing.xs).frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            HStack(spacing: AppSpacing.xs) { Text(group.account.name).appText(.body, weight: .semibold); Spacer(minLength: AppSpacing.xs); Text("\(group.selectedCount) selected").appText(.caption).foregroundStyle(AppColors.secondary) }
                        }.padding(AppSpacing.xs).background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
                            .overlay { RoundedRectangle(cornerRadius: AppLayout.cornerRadius).strokeBorder(AppColors.border, lineWidth: 1).allowsHitTesting(false) }
                    }
                    if model.groups.isEmpty && model.hasConnectedProvider && !model.search.isEmpty { Text("No matching calendars").appText(.body).foregroundStyle(AppColors.secondary) }
                }
            }.frame(maxHeight: .infinity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
