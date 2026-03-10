package com.smartview.glassai.data

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.util.Log
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.smartview.glassai.models.QuickVisionRecord
import java.io.File
import java.io.FileOutputStream

/**
 * Storage for Quick Vision records with thumbnail management
 */
class QuickVisionStorage(private val context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE
    )
    private val gson = Gson()
    private val thumbnailDir: File by lazy {
        File(context.filesDir, THUMBNAIL_DIR).also {
            if (!it.exists()) it.mkdirs()
        }
    }

    companion object {
        private const val TAG = "QuickVisionStorage"
        private const val PREFS_NAME = "turbometa_quick_vision"
        private const val KEY_RECORDS = "saved_records"
        private const val THUMBNAIL_DIR = "quick_vision_thumbnails"
        private const val MAX_RECORDS = 100

        @Volatile
        private var instance: QuickVisionStorage? = null

        fun getInstance(context: Context): QuickVisionStorage {
            return instance ?: synchronized(this) {
                instance ?: QuickVisionStorage(context.applicationContext).also { instance = it }
            }
        }
    }

    /**
     * Save a Quick Vision record with thumbnail
     */
    fun saveRecord(
        bitmap: Bitmap,
        prompt: String,
        result: String,
        mode: com.smartview.glassai.models.QuickVisionMode,
        visionModel: String
    ): Boolean {
        return try {
            val id = java.util.UUID.randomUUID().toString()
            val thumbnailPath = saveThumbnail(id, bitmap)

            if (thumbnailPath == null) {
                Log.e(TAG, "Failed to save thumbnail")
                return false
            }

            val record = QuickVisionRecord(
                id = id,
                thumbnailPath = thumbnailPath,
                prompt = prompt,
                result = result,
                mode = mode,
                visionModel = visionModel
            )

            val records = getAllRecords().toMutableList()
            records.add(0, record)

            // Trim to max records and clean up old thumbnails
            if (records.size > MAX_RECORDS) {
                val toRemove = records.subList(MAX_RECORDS, records.size)
                toRemove.forEach { deleteThumbnail(it.thumbnailPath) }
                records.removeAll(toRemove.toSet())
            }

            val json = gson.toJson(records)
            prefs.edit().putString(KEY_RECORDS, json).apply()
            Log.d(TAG, "Record saved: $id")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save record: ${e.message}", e)
            false
        }
    }

    /**
     * Get all Quick Vision records
     */
    fun getAllRecords(): List<QuickVisionRecord> {
        return try {
            val json = prefs.getString(KEY_RECORDS, null) ?: return emptyList()
            val type = object : TypeToken<List<QuickVisionRecord>>() {}.type
            gson.fromJson(json, type) ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load records: ${e.message}", e)
            emptyList()
        }
    }

    /**
     * Get a single record by ID
     */
    fun getRecord(id: String): QuickVisionRecord? {
        return getAllRecords().find { it.id == id }
    }

    /**
     * Delete a record and its thumbnail
     */
    fun deleteRecord(id: String): Boolean {
        return try {
            val records = getAllRecords().toMutableList()
            val record = records.find { it.id == id }

            if (record != null) {
                deleteThumbnail(record.thumbnailPath)
                records.removeAll { it.id == id }
                val json = gson.toJson(records)
                prefs.edit().putString(KEY_RECORDS, json).apply()
                Log.d(TAG, "Record deleted: $id")
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete record: ${e.message}", e)
            false
        }
    }

    /**
     * Delete all records and thumbnails
     */
    fun deleteAllRecords(): Boolean {
        return try {
            // Delete all thumbnail files
            thumbnailDir.listFiles()?.forEach { it.delete() }
            prefs.edit().remove(KEY_RECORDS).apply()
            Log.d(TAG, "All records deleted")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete all records: ${e.message}", e)
            false
        }
    }

    /**
     * Get record count
     */
    fun getRecordCount(): Int {
        return getAllRecords().size
    }

    /**
     * Save bitmap as thumbnail and return file path
     */
    private fun saveThumbnail(id: String, bitmap: Bitmap): String? {
        return try {
            val file = File(thumbnailDir, "${id}.jpg")
            FileOutputStream(file).use { out ->
                // Scale down for thumbnail (max 480px width)
                val scaledBitmap = if (bitmap.width > 480) {
                    val scale = 480f / bitmap.width
                    Bitmap.createScaledBitmap(
                        bitmap,
                        480,
                        (bitmap.height * scale).toInt(),
                        true
                    )
                } else {
                    bitmap
                }
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                if (scaledBitmap != bitmap) {
                    scaledBitmap.recycle()
                }
            }
            file.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save thumbnail: ${e.message}", e)
            null
        }
    }

    /**
     * Delete a thumbnail file
     */
    private fun deleteThumbnail(path: String) {
        try {
            File(path).delete()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete thumbnail: ${e.message}", e)
        }
    }
}
