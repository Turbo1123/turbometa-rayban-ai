/*
 * Conversation Storage Service
 * 对话记录持久化服务
 */

import Foundation

class ConversationStorage {
    static let shared = ConversationStorage()

    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "savedConversations"
    private let maxConversations = 100 // 最多保存100条对话

    private init() {}

    // MARK: - Save Conversation

    func saveConversation(_ record: ConversationRecord) {
        var conversations = loadAllConversations()

        // Add new conversation at the beginning
        conversations.insert(record, at: 0)

        // Keep only the most recent maxConversations
        if conversations.count > maxConversations {
            conversations = Array(conversations.prefix(maxConversations))
        }

        // Encode and save
        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: conversationsKey)
            print("💾 [Storage] 保存对话成功: \(record.id), 总数: \(conversations.count)")
        } else {
            print("❌ [Storage] 保存对话失败")
        }
    }

    // MARK: - Load Conversations

    func loadAllConversations() -> [ConversationRecord] {
        guard let data = userDefaults.data(forKey: conversationsKey),
              let conversations = try? JSONDecoder().decode([ConversationRecord].self, from: data) else {
            print("📂 [Storage] 无对话记录或解码失败")
            return []
        }

        print("📂 [Storage] 加载对话成功: \(conversations.count) 条")
        return conversations
    }

    func loadConversations(limit: Int = 20, offset: Int = 0) -> [ConversationRecord] {
        let allConversations = loadAllConversations()
        let endIndex = min(offset + limit, allConversations.count)

        guard offset < allConversations.count else {
            return []
        }

        return Array(allConversations[offset..<endIndex])
    }

    // MARK: - Delete Conversation

    func deleteConversation(_ id: UUID) {
        var conversations = loadAllConversations()
        conversations.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: conversationsKey)
            print("🗑️ [Storage] 删除对话成功: \(id)")
        }
    }

    func deleteAllConversations() {
        userDefaults.removeObject(forKey: conversationsKey)
        print("🗑️ [Storage] 清空所有对话")
    }

    // MARK: - Get Conversation

    func getConversation(by id: UUID) -> ConversationRecord? {
        return loadAllConversations().first { $0.id == id }
    }
}
