/*
 * Records View
 * 记录页面 - 包含各类记录的 Tab
 */

import SwiftUI

struct RecordsView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.lg) {
                        RecordTabButton(title: "Live AI", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }

                        RecordTabButton(title: "实时翻译", isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }

                        RecordTabButton(title: "LeanEat", isSelected: selectedTab == 2) {
                            selectedTab = 2
                        }

                        RecordTabButton(title: "WordLearn", isSelected: selectedTab == 3) {
                            selectedTab = 3
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                }
                .background(AppColors.tertiaryBackground)

                // Content
                TabView(selection: $selectedTab) {
                    LiveAIRecordsView()
                        .tag(0)

                    TranslationRecordsView()
                        .tag(1)

                    LeanEatRecordsView()
                        .tag(2)

                    WordLearnRecordsView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("记录")
        }
    }
}

// MARK: - Record Tab Button

struct RecordTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)

                if isSelected {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .cornerRadius(1.5)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 3)
                }
            }
        }
    }
}

// MARK: - Live AI Records

struct LiveAIRecordsView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var selectedConversation: ConversationRecord?
    @State private var showDetail = false

    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()

            if viewModel.conversations.isEmpty {
                // Empty state
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.liveAI.opacity(0.6))

                    Text("暂无 Live AI 对话记录")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.textPrimary)

                    Text("使用 Live AI 功能后记录将显示在这里")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
            } else {
                // Conversation list
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.conversations) { conversation in
                            ConversationCell(conversation: conversation)
                                .onTapGesture {
                                    selectedConversation = conversation
                                    showDetail = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteConversation(conversation.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(AppSpacing.md)
                }
                .refreshable {
                    viewModel.loadConversations()
                }
            }
        }
        .onAppear {
            viewModel.loadConversations()
        }
        .sheet(isPresented: $showDetail) {
            if let conversation = selectedConversation {
                ConversationDetailView(conversation: conversation)
            }
        }
    }
}

// MARK: - Conversation List ViewModel

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [ConversationRecord] = []

    func loadConversations() {
        conversations = ConversationStorage.shared.loadAllConversations()
        print("📱 [RecordsView] 加载对话: \(conversations.count) 条")
    }

    func deleteConversation(_ id: UUID) {
        ConversationStorage.shared.deleteConversation(id)
        loadConversations()
    }
}

// MARK: - Conversation Cell

struct ConversationCell: View {
    let conversation: ConversationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppColors.liveAI)
                    .font(AppTypography.headline)

                Text(conversation.title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            // Summary
            if !conversation.summary.isEmpty {
                Text(conversation.summary)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            // Footer
            HStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock")
                        .font(AppTypography.caption)
                    Text(conversation.formattedDate)
                        .font(AppTypography.caption)
                }
                .foregroundColor(AppColors.textSecondary)

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(AppTypography.caption)
                    Text("\(conversation.messageCount) 条消息")
                        .font(AppTypography.caption)
                }
                .foregroundColor(AppColors.textSecondary)

                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.tertiaryBackground)
        .cornerRadius(AppCornerRadius.lg)
        .shadow(color: AppShadow.small(), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Translation Records

struct TranslationRecordsView: View {
    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.translate.opacity(0.6))

                Text("暂无翻译记录")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text("功能即将上线")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - LeanEat Records

struct LeanEatRecordsView: View {
    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.leanEat.opacity(0.6))

                Text("暂无卡路里识别记录")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text("功能即将上线")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - WordLearn Records

struct WordLearnRecordsView: View {
    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.wordLearn.opacity(0.6))

                Text("暂无单词学习记录")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text("功能即将上线")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}
