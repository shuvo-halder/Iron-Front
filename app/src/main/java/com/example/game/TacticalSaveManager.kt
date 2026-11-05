package com.example.game

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Android local persistent save manager matching Godot's user://save.json structure.
 */
class TacticalSaveManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("iron_front_save", Context.MODE_PRIVATE)

    var money: Int
        get() = prefs.getInt("money", 250)
        set(value) = prefs.edit().putInt("money", value).apply()

    var highestMissionUnlocked: Int
        get() = prefs.getInt("highest_mission", 1)
        set(value) = prefs.edit().putInt("highest_mission", value).apply()

    var musicVolume: Float
        get() = prefs.getFloat("music_volume", 0.75f)
        set(value) = prefs.edit().putFloat("music_volume", value).apply()

    var sfxVolume: Float
        get() = prefs.getFloat("sfx_volume", 0.85f)
        set(value) = prefs.edit().putFloat("sfx_volume", value).apply()

    var hapticsEnabled: Boolean
        get() = prefs.getBoolean("haptics_enabled", true)
        set(value) = prefs.edit().putBoolean("haptics_enabled", value).apply()

    fun getUnlockedUpgrades(): Set<String> {
        val set = prefs.getStringSet("upgrades", null)
        return set ?: emptySet()
    }

    fun buyUpgrade(upgradeId: String, cost: Int): Boolean {
        if (money >= cost && !hasUpgrade(upgradeId)) {
            money -= cost
            val set = getUnlockedUpgrades().toMutableSet()
            set.add(upgradeId)
            prefs.edit().putStringSet("upgrades", set).apply()
            return true
        }
        return false
    }

    fun hasUpgrade(upgradeId: String): Boolean {
        return getUnlockedUpgrades().contains(upgradeId)
    }

    fun unlockMission(missionIdx: Int) {
        if (missionIdx > highestMissionUnlocked) {
            highestMissionUnlocked = missionIdx.coerceAtMost(10)
        }
    }

    fun resetToDefaults() {
        prefs.edit().clear().apply()
    }
}
