package com.example.ui

import android.app.Activity
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.IronFrontGameScreen
import com.example.game.TacticalAudio
import com.example.game.TacticalSaveManager
import kotlinx.coroutines.launch

enum class ScreenState {
    MAIN_MENU,
    IN_GAME,
    CAMPAIGN_SELECT,
    UPGRADES_SHOP,
    SETTINGS
}

@Composable
fun IronFrontApp() {
    val context = LocalContext.current
    val saveManager = remember { TacticalSaveManager(context) }
    var currentScreen by remember { mutableStateOf(ScreenState.MAIN_MENU) }
    var selectedMissionIndex by remember { mutableIntStateOf(1) }

    // Fade Transition Animatable
    val fadeAlpha = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()

    fun navigateTo(target: ScreenState) {
        scope.launch {
            TacticalAudio.playOrderBeep()
            fadeAlpha.animateTo(1f, tween(250))
            currentScreen = target
            fadeAlpha.animateTo(0f, tween(250))
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color(0xFF101418))) {
        when (currentScreen) {
            ScreenState.MAIN_MENU -> {
                MainMenuContent(
                    saveManager = saveManager,
                    onPlay = { navigateTo(ScreenState.IN_GAME) },
                    onCampaign = { navigateTo(ScreenState.CAMPAIGN_SELECT) },
                    onUpgrades = { navigateTo(ScreenState.UPGRADES_SHOP) },
                    onSettings = { navigateTo(ScreenState.SETTINGS) },
                    onQuit = { (context as? Activity)?.finish() }
                )
            }
            ScreenState.IN_GAME -> {
                Box(modifier = Modifier.fillMaxSize()) {
                    IronFrontGameScreen()
                    // Top Exit/Return to Menu Button
                    IconButton(
                        onClick = { navigateTo(ScreenState.MAIN_MENU) },
                        modifier = Modifier
                            .padding(top = 10.dp, start = 16.dp)
                            .size(36.dp)
                            .background(Color(0xCC263238), RoundedCornerShape(8.dp))
                            .testTag("exit_to_menu_button")
                    ) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Exit to Menu", tint = Color.White)
                    }
                }
            }
            ScreenState.CAMPAIGN_SELECT -> {
                CampaignSelectContent(
                    saveManager = saveManager,
                    onBack = { navigateTo(ScreenState.MAIN_MENU) },
                    onSelectMission = { mIndex ->
                        selectedMissionIndex = mIndex
                        navigateTo(ScreenState.IN_GAME)
                    }
                )
            }
            ScreenState.UPGRADES_SHOP -> {
                UpgradeShopContent(
                    saveManager = saveManager,
                    onBack = { navigateTo(ScreenState.MAIN_MENU) }
                )
            }
            ScreenState.SETTINGS -> {
                SettingsContent(
                    saveManager = saveManager,
                    onBack = { navigateTo(ScreenState.MAIN_MENU) }
                )
            }
        }

        // Full Screen Black Fade Transition Overlay
        if (fadeAlpha.value > 0.01f) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = fadeAlpha.value))
            )
        }
    }
}

@Composable
fun MainMenuContent(
    saveManager: TacticalSaveManager,
    onPlay: () -> Unit,
    onCampaign: () -> Unit,
    onUpgrades: () -> Unit,
    onSettings: () -> Unit,
    onQuit: () -> Unit
) {
    var warBonds by remember { mutableIntStateOf(saveManager.money) }

    Row(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Left Column: Game Title & Lore
        Column(
            modifier = Modifier.weight(1.2f),
            verticalArrangement = Arrangement.Center
        ) {
            Surface(
                color = Color(0x33FFB300),
                shape = RoundedCornerShape(4.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFFFB300))
            ) {
                Text(
                    text = "OFFLINE TACTICAL WARFARE",
                    color = Color(0xFFFFB300),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "IRON FRONT",
                fontSize = 42.sp,
                fontWeight = FontWeight.Black,
                color = Color.White,
                letterSpacing = 2.sp
            )

            Text(
                text = "2D Top-Down Real-Time Tactics • Mobile Landscape",
                fontSize = 14.sp,
                color = Color(0xFF90A4AE)
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Profile War Bonds Badge
            Surface(
                color = Color(0xFF1E282D),
                shape = RoundedCornerShape(8.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF37474F))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.MonetizationOn, contentDescription = "War Bonds", tint = Color(0xFFFFB300), modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "WAR BONDS: $warBonds WB",
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        fontSize = 13.sp
                    )
                    Spacer(modifier = Modifier.width(16.dp))
                    Text(
                        text = "MISSION: ${saveManager.highestMissionUnlocked} / 10",
                        color = Color(0xFF80CBC4),
                        fontSize = 12.sp
                    )
                }
            }
        }

        // Right Column: Tactical Menu Buttons
        Column(
            modifier = Modifier
                .weight(0.8f)
                .padding(start = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalAlignment = Alignment.End
        ) {
            MenuButton(label = "PLAY SKIRMISH", icon = Icons.Default.PlayArrow, isPrimary = true, testTag = "menu_play_button", onClick = onPlay)
            MenuButton(label = "CAMPAIGN", icon = Icons.Default.Map, testTag = "menu_campaign_button", onClick = onCampaign)
            MenuButton(label = "UPGRADES", icon = Icons.Default.Upgrade, testTag = "menu_upgrades_button", onClick = onUpgrades)
            MenuButton(label = "SETTINGS", icon = Icons.Default.Settings, testTag = "menu_settings_button", onClick = onSettings)
            MenuButton(label = "QUIT", icon = Icons.Default.ExitToApp, testTag = "menu_quit_button", onClick = onQuit)
        }
    }
}

@Composable
fun MenuButton(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    isPrimary: Boolean = false,
    testTag: String,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isPrimary) Color(0xFFFFB300) else Color(0xFF263238),
            contentColor = if (isPrimary) Color.Black else Color.White
        ),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .testTag(testTag)
    ) {
        Icon(icon, contentDescription = label, modifier = Modifier.size(18.dp))
        Spacer(modifier = Modifier.width(8.dp))
        Text(label, fontWeight = FontWeight.Bold, fontSize = 13.sp)
    }
}

@Composable
fun SettingsContent(
    saveManager: TacticalSaveManager,
    onBack: () -> Unit
) {
    var musicVol by remember { mutableFloatStateOf(saveManager.musicVolume) }
    var sfxVol by remember { mutableFloatStateOf(saveManager.sfxVolume) }
    var haptics by remember { mutableStateOf(saveManager.hapticsEnabled) }
    var showResetDialog by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack, modifier = Modifier.testTag("settings_back_button")) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
                Spacer(modifier = Modifier.width(8.dp))
                Text("SETTINGS", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Surface(
            color = Color(0xFF1E282D),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth().weight(1f)
        ) {
            Column(
                modifier = Modifier
                    .padding(20.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Music Volume Slider
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Music Volume", color = Color.White, fontSize = 14.sp)
                        Text("${(musicVol * 100).toInt()}%", color = Color(0xFFFFB300), fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    }
                    Slider(
                        value = musicVol,
                        onValueChange = {
                            musicVol = it
                            saveManager.musicVolume = it
                        },
                        colors = SliderDefaults.colors(thumbColor = Color(0xFFFFB300), activeTrackColor = Color(0xFFFFB300)),
                        modifier = Modifier.testTag("music_slider")
                    )
                }

                // SFX Volume Slider
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Sound Effects (SFX)", color = Color.White, fontSize = 14.sp)
                        Text("${(sfxVol * 100).toInt()}%", color = Color(0xFFFFB300), fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    }
                    Slider(
                        value = sfxVol,
                        onValueChange = {
                            sfxVol = it
                            saveManager.sfxVolume = it
                        },
                        colors = SliderDefaults.colors(thumbColor = Color(0xFFFFB300), activeTrackColor = Color(0xFFFFB300)),
                        modifier = Modifier.testTag("sfx_slider")
                    )
                }

                // Haptics Switch
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Android Tactile Haptics (Vibration)", color = Color.White, fontSize = 14.sp)
                    Switch(
                        checked = haptics,
                        onCheckedChange = {
                            haptics = it
                            saveManager.hapticsEnabled = it
                        },
                        colors = SwitchDefaults.colors(checkedThumbColor = Color(0xFFFFB300), checkedTrackColor = Color(0x66FFB300)),
                        modifier = Modifier.testTag("haptics_switch")
                    )
                }

                HorizontalDivider(color = Color(0xFF37474F))

                // Reset Progress Button
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Reset Campaign & Progress", color = Color(0xFFE57373), fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text("Restores default save at user://save.json", color = Color(0xFF90A4AE), fontSize = 12.sp)
                    }
                    OutlinedButton(
                        onClick = { showResetDialog = true },
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFE57373)),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFE57373)),
                        modifier = Modifier.testTag("reset_save_button")
                    ) {
                        Text("RESET")
                    }
                }
            }
        }
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = { Text("RESET ALL DATA?", color = Color(0xFFE53935), fontWeight = FontWeight.Bold) },
            text = { Text("This will delete your campaign progress, war bonds, and upgrades. This action cannot be undone.", color = Color.White) },
            confirmButton = {
                Button(
                    onClick = {
                        saveManager.resetToDefaults()
                        musicVol = saveManager.musicVolume
                        sfxVol = saveManager.sfxVolume
                        haptics = saveManager.hapticsEnabled
                        showResetDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE53935), contentColor = Color.White)
                ) {
                    Text("CONFIRM RESET")
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("CANCEL", color = Color.White)
                }
            },
            containerColor = Color(0xFF1E282D)
        )
    }
}

@Composable
fun CampaignSelectContent(
    saveManager: TacticalSaveManager,
    onBack: () -> Unit,
    onSelectMission: (Int) -> Unit
) {
    val missions = listOf(
        "M01: Operation Beachhead" to "Capture 2 Supply Depots on the coastline.",
        "M02: Convoy Ambush" to "Intercept 4 enemy supply halftracks.",
        "M03: Iron Valley" to "Destroy Forward Motor Pool before reinforcements.",
        "M04: St. Claire Outskirts" to "Defend Allied HQ against 4 assault waves.",
        "M05: The Redoubt" to "Crack 3 concrete bunker positions with artillery.",
        "M06: Panzer Flank" to "Encircle enemy heavy tank patrol.",
        "M07: Crossroads Defense" to "Hold northern and southern bridges for 4m.",
        "M08: Night Bastion" to "Infiltrate radar perimeter and sabotage generators.",
        "M09: Steel Ridge" to "50v50 Armored clash across open valley.",
        "M10: Fortress Eisen" to "Final combined-arms siege against the Citadel."
    )

    Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack, modifier = Modifier.testTag("campaign_back_button")) {
                Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text("CAMPAIGN THEATRE", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Color.White)
        }

        Spacer(modifier = Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth().weight(1f),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Missions List (Scrollable)
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                missions.forEachIndexed { index, (title, desc) ->
                    val missionNum = index + 1
                    val isUnlocked = missionNum <= saveManager.highestMissionUnlocked

                    Surface(
                        onClick = { if (isUnlocked) onSelectMission(missionNum) },
                        shape = RoundedCornerShape(8.dp),
                        color = if (isUnlocked) Color(0xFF1E282D) else Color(0x66182026),
                        border = if (isUnlocked) androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF37474F)) else null,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = title,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isUnlocked) Color.White else Color(0xFF607D8B),
                                    fontSize = 14.sp
                                )
                                Text(
                                    text = desc,
                                    color = if (isUnlocked) Color(0xFF90A4AE) else Color(0xFF455A64),
                                    fontSize = 12.sp
                                )
                            }
                            if (isUnlocked) {
                                Button(
                                    onClick = { onSelectMission(missionNum) },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFFB300), contentColor = Color.Black),
                                    shape = RoundedCornerShape(6.dp)
                                ) {
                                    Text("DEPLOY")
                                }
                            } else {
                                Icon(Icons.Default.Lock, contentDescription = "Locked", tint = Color(0xFF607D8B))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun UpgradeShopContent(
    saveManager: TacticalSaveManager,
    onBack: () -> Unit
) {
    var warBonds by remember { mutableIntStateOf(saveManager.money) }

    val upgrades = listOf(
        Triple("armor_sloped", "Sloped Plating", "Increases vehicle frontal armor by +15%." to 75),
        Triple("armor_spall", "Spall Liners", "Reduces explosive shrapnel damage by -25%." to 150),
        Triple("firepower_apcr", "Tungsten APCR", "+20% armor penetration on all tank guns." to 75),
        Triple("firepower_he", "High-Explosive Shells", "Tank shells gain 24px infantry splash radius." to 150),
        Triple("logistics_engine", "High-Torque Gearbox", "Increases vehicle speed and acceleration by +15%." to 75),
        Triple("logistics_salvage", "Automated Salvage", "Engineers recover 60% of wrecked unit supply." to 250)
    )

    Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack, modifier = Modifier.testTag("upgrades_back_button")) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
                Spacer(modifier = Modifier.width(8.dp))
                Text("TACTICAL UPGRADES", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Color.White)
            }
            Surface(
                color = Color(0xFF1E282D),
                shape = RoundedCornerShape(8.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF37474F))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.MonetizationOn, contentDescription = null, tint = Color(0xFFFFB300), modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("FUNDS: $warBonds WB", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 13.sp)
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            upgrades.forEach { (id, name, pair) ->
                val (desc, cost) = pair
                val isPurchased = saveManager.hasUpgrade(id)
                val canAfford = warBonds >= cost

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = if (isPurchased) Color(0x334CAF50) else Color(0xFF1E282D),
                    border = androidx.compose.foundation.BorderStroke(1.dp, if (isPurchased) Color(0xFF4CAF50) else Color(0xFF37474F)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(14.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(name, fontWeight = FontWeight.Bold, color = Color.White, fontSize = 14.sp)
                            Text(desc, color = Color(0xFF90A4AE), fontSize = 12.sp)
                        }
                        if (isPurchased) {
                            Surface(color = Color(0xFF2E7D32), shape = RoundedCornerShape(4.dp)) {
                                Text("ACTIVE", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 11.sp, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                            }
                        } else {
                            Button(
                                onClick = {
                                    if (saveManager.buyUpgrade(id, cost)) {
                                        warBonds = saveManager.money
                                        TacticalAudio.playOrderBeep()
                                    }
                                },
                                enabled = canAfford,
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFFB300), contentColor = Color.Black),
                                shape = RoundedCornerShape(6.dp)
                            ) {
                                Text("BUY $cost WB")
                            }
                        }
                    }
                }
            }
        }
    }
}
