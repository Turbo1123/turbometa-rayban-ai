package com.smartview.glassai.data

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.smartview.glassai.models.ConversationRecord

class ConversationStorage(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE
    )
    private val gson = Gson()

    companion object {
        private const val PREFS_NAME = "turbometa_conversations"
        private const val KEY_CONVERSATIONS = "saved_conversations"
        private const val MAX_RECORDS = 100

        @Volatile
        private var instance: ConversationStorage? = null

        fun getInstance(context: Context): ConversationStorage {
            return instance ?: synchronized(this) {
                instance ?: ConversationStorage(context.applicationContext).also { instance = it }
            }
        }
    }

    fun saveConversation(record: ConversationRecord): Boolean {
        return try {
            val conversations = getAllConversations().toMutableList()

            // Check if exists and update, or add new
            val existingIndex = conversations.indexOfFirst { it.id == record.id }
            if (existingIndex >= 0) {
                conversations[existingIndex] = record
            } else {
                conversations.add(0, record)
            }

            // Trim to max records
            val trimmedList = if (conversations.size > MAX_RECORDS) {
                conversations.take(MAX_RECORDS)
            } else {
                conversations
            }

            val json = gson.toJson(trimmedList)
            prefs.edit().putString(KEY_CONVERSATIONS, json).apply()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun getAllConversations(): List<ConversationRecord> {
        return try {
            val json = prefs.getString(KEY_CONVERSATIONS, null) ?: return emptyList()
            val type = object : TypeToken<List<ConversationRecord>>() {}.type
            gson.fromJson(json, type) ?: emptyList()
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    fun getConversation(id: String): ConversationRecord? {
        return getAllConversations().find { it.id == id }
    }

    fun deleteConversation(id: String): Boolean {
        return try {
            val conversations = getAllConversations().toMutableList()
            conversations.removeAll { it.id == id }
            val json = gson.toJson(conversations)
            prefs.edit().putString(KEY_CONVERSATIONS, json).apply()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun deleteAllConversations(): Boolean {
        return try {
            prefs.edit().remove(KEY_CONVERSATIONS).apply()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun getConversationCount(): Int {
        return getAllConversations().size
    }
}
