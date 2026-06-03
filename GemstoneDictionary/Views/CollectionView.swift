import SwiftUI

private let collectionStorageKey = "gemstone.collection.v1"

struct CollectionView: View {
    @State private var items: [CollectionItem] = []
    @State private var showingAdd = false
    @State private var editingItem: CollectionItem? = nil
    @State private var selectedStone: Gemstone? = nil
    private let en = isEnglish()

    private var totalValue: Double {
        items.compactMap(\.purchasePrice).reduce(0, +)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerCard
                if items.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    collectionGrid
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 26)
        }
        .background(AppStyle.background.ignoresSafeArea())
        .navigationTitle(en ? "My Collection" : "マイコレクション")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                AddCollectionItemView(onSave: { item in
                    items.append(item)
                    saveItems()
                })
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                EditCollectionItemView(item: item, onSave: { updated in
                    if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                        items[idx] = updated
                        saveItems()
                    }
                }, onDelete: { id in
                    items.removeAll { $0.id == id }
                    saveItems()
                })
            }
        }
        .sheet(item: $selectedStone) { stone in
            NavigationStack {
                StoneDetailSheet(stone: stone)
            }
        }
        .onAppear { loadItems() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MY COLLECTION")
                .font(.caption.weight(.black))
                .foregroundStyle(AppStyle.turquoise)
            Text(en ? "My Collection" : "マイコレクション")
                .font(.system(size: 28, weight: .black, design: .serif))
                .foregroundStyle(AppStyle.ink)
            Text(en
                ? "Record your stones with notes, purchase date and price."
                : "購入した石を記録。メモ、購入日、価格を管理できます。")
                .font(.body)
                .foregroundStyle(AppStyle.muted)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppStyle.muted.opacity(0.5))
            Text(en ? "No stones yet" : "まだ石がありません")
                .font(.headline)
                .foregroundStyle(AppStyle.muted)
            Text(en ? "Tap + to add your first stone." : "+ をタップして最初の石を追加してください。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted.opacity(0.7))
                .multilineTextAlignment(.center)
            Button {
                showingAdd = true
            } label: {
                Label(en ? "Add Stone" : "石を追加", systemImage: "plus")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryCell(
                label: en ? "Total Stones" : "合計",
                value: "\(items.count)",
                unit: en ? "stones" : "個"
            )
            Divider().frame(height: 40)
            summaryCell(
                label: en ? "Total Value" : "合計金額",
                value: totalValue > 0 ? formattedPrice(totalValue) : "—",
                unit: totalValue > 0 ? (en ? "JPY" : "円") : ""
            )
        }
        .padding(16)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }

    private func summaryCell(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.black))
                .foregroundStyle(AppStyle.turquoise)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppStyle.ink)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var collectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items) { item in
                CollectionItemCard(item: item, onTapStone: { stone in
                    selectedStone = stone
                }, onTapEdit: {
                    editingItem = item
                })
            }
        }
    }

    private func formattedPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: collectionStorageKey)
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: collectionStorageKey),
              let decoded = try? JSONDecoder().decode([CollectionItem].self, from: data) else { return }
        items = decoded
    }
}

private struct CollectionItemCard: View {
    let item: CollectionItem
    let onTapStone: (Gemstone) -> Void
    let onTapEdit: () -> Void
    private let en = isEnglish()

    private var stone: Gemstone? {
        GemstoneDatabase.stones.first { $0.id == item.gemstoneID }
    }

    private var dateText: String {
        guard let date = item.purchaseDate else { return "" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let stone {
                Button { onTapStone(stone) } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(hueColor(stone.hueCenter, sat: stone.saturationCenter))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(AppStyle.line, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(en ? stone.englishName : stone.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppStyle.ink)
                                .lineLimit(1)
                            Text(en ? stone.name : stone.kana)
                                .font(.caption2)
                                .foregroundStyle(AppStyle.muted)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(item.gemstoneID)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppStyle.ink)
            }

            if let price = item.purchasePrice {
                let fmt = NumberFormatter()
                let _ = { fmt.numberStyle = .decimal; fmt.maximumFractionDigits = 0 }()
                Text("¥\(fmt.string(from: NSNumber(value: price)) ?? "\(Int(price))")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppStyle.gold)
            }

            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
                    .lineLimit(2)
            }

            if !dateText.isEmpty {
                Text(dateText)
                    .font(.caption2)
                    .foregroundStyle(AppStyle.muted.opacity(0.7))
            }

            Spacer(minLength: 0)

            Button(action: onTapEdit) {
                Label(en ? "Edit" : "編集", systemImage: "pencil")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppStyle.turquoise)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppStyle.line))
    }
}

// MARK: - Add Item View

struct AddCollectionItemView: View {
    let onSave: (CollectionItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStoneID: String = GemstoneDatabase.stones[0].id
    @State private var notes: String = ""
    @State private var hasPurchaseDate = false
    @State private var purchaseDate = Date()
    @State private var hasPurchasePrice = false
    @State private var purchasePriceText = ""
    private let en = isEnglish()

    private var sortedStones: [Gemstone] {
        GemstoneDatabase.stones.sorted { $0.kana.localizedStandardCompare($1.kana) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section(en ? "Stone" : "石の種類") {
                Picker(en ? "Select Stone" : "石を選択", selection: $selectedStoneID) {
                    ForEach(sortedStones) { s in
                        Text(en ? s.englishName : s.name).tag(s.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            Section(en ? "Notes" : "メモ") {
                TextField(en ? "Optional notes..." : "メモを入力...", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }
            Section(en ? "Purchase Date" : "購入日") {
                Toggle(en ? "Record purchase date" : "購入日を記録", isOn: $hasPurchaseDate)
                if hasPurchaseDate {
                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            Section(en ? "Purchase Price (JPY)" : "購入価格（円）") {
                Toggle(en ? "Record price" : "価格を記録", isOn: $hasPurchasePrice)
                if hasPurchasePrice {
                    TextField(en ? "e.g. 3000" : "例: 3000", text: $purchasePriceText)
                        .keyboardType(.numberPad)
                }
            }
        }
        .navigationTitle(en ? "Add Stone" : "石を追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(en ? "Cancel" : "キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(en ? "Save" : "保存") { save() }
            }
        }
    }

    private func save() {
        let price = hasPurchasePrice ? Double(purchasePriceText) : nil
        let date = hasPurchaseDate ? purchaseDate : nil
        let item = CollectionItem(
            gemstoneID: selectedStoneID,
            notes: notes,
            purchaseDate: date,
            purchasePrice: price
        )
        onSave(item)
        dismiss()
    }
}

// MARK: - Edit Item View

struct EditCollectionItemView: View {
    let item: CollectionItem
    let onSave: (CollectionItem) -> Void
    let onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStoneID: String
    @State private var notes: String
    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var hasPurchasePrice: Bool
    @State private var purchasePriceText: String
    @State private var showDeleteConfirm = false
    private let en = isEnglish()

    init(item: CollectionItem, onSave: @escaping (CollectionItem) -> Void, onDelete: @escaping (UUID) -> Void) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        _selectedStoneID = State(initialValue: item.gemstoneID)
        _notes = State(initialValue: item.notes)
        _hasPurchaseDate = State(initialValue: item.purchaseDate != nil)
        _purchaseDate = State(initialValue: item.purchaseDate ?? Date())
        _hasPurchasePrice = State(initialValue: item.purchasePrice != nil)
        _purchasePriceText = State(initialValue: item.purchasePrice.map { "\(Int($0))" } ?? "")
    }

    private var sortedStones: [Gemstone] {
        GemstoneDatabase.stones.sorted { $0.kana.localizedStandardCompare($1.kana) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section(en ? "Stone" : "石の種類") {
                Picker(en ? "Select Stone" : "石を選択", selection: $selectedStoneID) {
                    ForEach(sortedStones) { s in
                        Text(en ? s.englishName : s.name).tag(s.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            Section(en ? "Notes" : "メモ") {
                TextField(en ? "Optional notes..." : "メモを入力...", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }
            Section(en ? "Purchase Date" : "購入日") {
                Toggle(en ? "Record purchase date" : "購入日を記録", isOn: $hasPurchaseDate)
                if hasPurchaseDate {
                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            Section(en ? "Purchase Price (JPY)" : "購入価格（円）") {
                Toggle(en ? "Record price" : "価格を記録", isOn: $hasPurchasePrice)
                if hasPurchasePrice {
                    TextField(en ? "e.g. 3000" : "例: 3000", text: $purchasePriceText)
                        .keyboardType(.numberPad)
                }
            }
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(en ? "Delete" : "削除", systemImage: "trash")
                }
            }
        }
        .navigationTitle(en ? "Edit Stone" : "石を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(en ? "Cancel" : "キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(en ? "Save" : "保存") { save() }
            }
        }
        .confirmationDialog(
            en ? "Delete this stone from your collection?" : "コレクションから削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(en ? "Delete" : "削除", role: .destructive) {
                onDelete(item.id)
                dismiss()
            }
            Button(en ? "Cancel" : "キャンセル", role: .cancel) {}
        }
    }

    private func save() {
        let price = hasPurchasePrice ? Double(purchasePriceText) : nil
        let date = hasPurchaseDate ? purchaseDate : nil
        var updated = item
        updated = CollectionItem(
            id: item.id,
            gemstoneID: selectedStoneID,
            notes: notes,
            purchaseDate: date,
            purchasePrice: price
        )
        onSave(updated)
        dismiss()
    }
}
