package com.example.game

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.isActive
import kotlin.math.*

@Composable
fun IronFrontGameScreen() {
    val engine = remember { TacticalEngine() }

    // Camera viewport offset
    var camX by remember { mutableFloatStateOf(100f) }
    var camY by remember { mutableFloatStateOf(200f) }

    // Touch selection drag box
    var dragStart by remember { mutableStateOf<Offset?>(null) }
    var dragCurrent by remember { mutableStateOf<Offset?>(null) }
    var isPanningCamera by remember { mutableStateOf(false) }

    var currentOrderMode by remember { mutableStateOf(OrderMode.MOVE) }
    var showScenarioDialog by remember { mutableStateOf(false) }
    var showBriefingDialog by remember { mutableStateOf(false) }
    var showBuildCatalogDialog by remember { mutableStateOf(false) }
    var isSettingRallyPoint by remember { mutableStateOf(false) }

    var tickCounter by remember { mutableLongStateOf(0L) }
    var fps by remember { mutableIntStateOf(60) }

    // 60 FPS Game Loop
    LaunchedEffect(Unit) {
        var lastTime = System.nanoTime()
        var frameCount = 0
        var fpsTimer = 0L

        while (isActive) {
            withFrameNanos { now ->
                val deltaSec = ((now - lastTime) / 1_000_000_000.0).toFloat().coerceIn(0.005f, 0.033f)
                lastTime = now

                engine.update(deltaSec)
                tickCounter++

                frameCount++
                fpsTimer += (deltaSec * 1000).toLong()
                if (fpsTimer >= 1000) {
                    fps = frameCount
                    frameCount = 0
                    fpsTimer = 0
                }
            }
        }
    }

    // Active units stats
    val activeAllies = remember(tickCounter) { engine.units.count { it.faction == Faction.ALLIED && !it.isDestroyed } }
    val activeAxis = remember(tickCounter) { engine.units.count { it.faction == Faction.AXIS && !it.isDestroyed } }
    val selectedUnits = remember(tickCounter) { engine.units.filter { it.isSelected && !it.isDestroyed } }
    val selectedBuilding = remember(tickCounter) { engine.buildings.firstOrNull { it.isSelected && !it.isDestroyed } }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF14171A))
    ) {
        // Main Battlefield Canvas
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .testTag("battlefield_canvas")
                .pointerInput(Unit) {
                    detectTapGestures(
                        onTap = { tapOffset ->
                            val worldX = tapOffset.x + camX
                            val worldY = tapOffset.y + camY

                            // 1. If currently in Building Placement Mode
                            if (engine.pendingBuildingToPlace != null) {
                                engine.updateGhostPosition(worldX, worldY)
                                engine.confirmBuildingPlacement()
                                return@detectTapGestures
                            }

                            // 2. If setting rally point for building
                            if (isSettingRallyPoint && selectedBuilding != null) {
                                selectedBuilding.rallyX = worldX
                                selectedBuilding.rallyY = worldY
                                isSettingRallyPoint = false
                                TacticalAudio.playOrderBeep()
                                return@detectTapGestures
                            }

                            // 3. Check if tapped a Building
                            val tappedBuilding = engine.selectSingleBuildingAt(worldX, worldY)
                            if (tappedBuilding != null) {
                                if (tappedBuilding.faction == Faction.ALLIED) {
                                    engine.clearSelection()
                                    tappedBuilding.isSelected = true
                                    TacticalAudio.playOrderBeep()
                                    return@detectTapGestures
                                } else {
                                    if (selectedUnits.isNotEmpty()) {
                                        engine.issueOrderToSelected(worldX, worldY, OrderMode.ATTACK_MOVE)
                                        return@detectTapGestures
                                    }
                                }
                            }

                            // 4. Check if tapped a unit
                            val tappedUnit = engine.selectSingleUnitAt(worldX, worldY)
                            if (tappedUnit != null) {
                                if (tappedUnit.faction == Faction.ALLIED) {
                                    engine.clearSelection()
                                    tappedUnit.isSelected = true
                                    TacticalAudio.playOrderBeep()
                                } else {
                                    // Tapped enemy -> Issue attack order to currently selected
                                    if (selectedUnits.isNotEmpty()) {
                                        engine.issueOrderToSelected(worldX, worldY, OrderMode.ATTACK_MOVE, tappedUnit)
                                    }
                                }
                            } else {
                                // Tapped ground
                                if (selectedUnits.isNotEmpty()) {
                                    engine.issueOrderToSelected(worldX, worldY, currentOrderMode)
                                } else {
                                    engine.clearSelection()
                                }
                            }
                        },
                        onLongPress = { longPressOffset ->
                            val worldX = longPressOffset.x + camX
                            val worldY = longPressOffset.y + camY
                            if (selectedUnits.isNotEmpty()) {
                                engine.issueOrderToSelected(worldX, worldY, OrderMode.ATTACK_MOVE)
                                TacticalAudio.playOrderBeep()
                            }
                        }
                    )
                }
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { startOffset ->
                            // If user touches near edge or screen with 2 fingers or long drag, we distinguish
                            dragStart = startOffset
                            dragCurrent = startOffset
                            isPanningCamera = false
                        },
                        onDrag = { change, dragAmount ->
                            change.consume()
                            dragCurrent = (dragCurrent ?: change.position) + dragAmount

                            val dist = dragStart?.let { (dragCurrent!! - it).getDistance() } ?: 0f
                            // If dragging far with finger, enable either box select or map pan
                            if (isPanningCamera) {
                                camX = (camX - dragAmount.x).coerceIn(0f, engine.mapWidth - 1000f)
                                camY = (camY - dragAmount.y).coerceIn(0f, engine.mapHeight - 600f)
                            }
                        },
                        onDragEnd = {
                            val start = dragStart
                            val end = dragCurrent
                            if (start != null && end != null && !isPanningCamera) {
                                val dist = (end - start).getDistance()
                                if (dist > 25f) {
                                    // Box selection
                                    val left = min(start.x, end.x) + camX
                                    val top = min(start.y, end.y) + camY
                                    val right = max(start.x, end.x) + camX
                                    val bottom = max(start.y, end.y) + camY
                                    engine.selectUnitsInRect(left, top, right, bottom)
                                    if (engine.units.any { it.isSelected }) {
                                        TacticalAudio.playOrderBeep()
                                    }
                                }
                            }
                            dragStart = null
                            dragCurrent = null
                            isPanningCamera = false
                        },
                        onDragCancel = {
                            dragStart = null
                            dragCurrent = null
                            isPanningCamera = false
                        }
                    )
                }
        ) {
            // Draw Ground Terrain & Grid
            drawTacticalTerrain(engine.mapWidth, engine.mapHeight, camX, camY)

            // Draw Supply Crates
            for (crate in engine.supplyCrates) {
                if (!crate.collected) {
                    drawTacticalSupplyCrate(crate, camX, camY)
                }
            }

            // Draw Buildings
            for (b in engine.buildings) {
                if (!b.isDestroyed) {
                    drawTacticalBuilding(b, camX, camY)
                }
            }

            // Draw Placement Ghost
            if (engine.pendingBuildingToPlace != null) {
                drawBuildingGhost(engine.ghostX, engine.ghostY, engine.pendingBuildingToPlace!!.radius, engine.isGhostPlacementValid, camX, camY)
            }

            // Draw Units
            for (u in engine.units) {
                if (u.isDestroyed) {
                    // Draw destroyed wreck
                    drawUnitWreck(u, camX, camY)
                } else {
                    drawTacticalUnit(u, camX, camY)
                }
            }

            // Draw Projectiles
            for (i in 0 until engine.projectilePool.size) {
                val p = engine.projectilePool[i]
                if (!p.active) continue
                drawTacticalProjectile(p, camX, camY)
            }

            // Draw Explosions / Particles
            for (i in 0 until engine.particlePool.size) {
                val p = engine.particlePool[i]
                if (!p.active) continue
                drawCombatParticle(p, camX, camY)
            }

            // Draw Drag Selection Box
            val start = dragStart
            val cur = dragCurrent
            if (start != null && cur != null && !isPanningCamera) {
                val left = min(start.x, cur.x)
                val top = min(start.y, cur.y)
                val width = abs(cur.x - start.x)
                val height = abs(cur.y - start.y)
                if (width > 8f && height > 8f) {
                    drawRect(
                        color = Color(0x334CAF50),
                        topLeft = Offset(left, top),
                        size = Size(width, height)
                    )
                    drawRect(
                        color = Color(0xFF4CAF50),
                        topLeft = Offset(left, top),
                        size = Size(width, height),
                        style = Stroke(width = 2f)
                    )
                }
            }
        }

        // Top Tactical Control Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Faction Balance & Scenario title
            Surface(
                color = Color(0xDD1B2228),
                shape = RoundedCornerShape(10.dp),
                border = BorderStroke(1.dp, Color(0xFF37474F))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        text = "IRON FRONT",
                        fontWeight = FontWeight.Black,
                        color = Color(0xFFFFB300),
                        fontSize = 14.sp
                    )
                    Text(
                        text = "Supply: ${engine.currentSupply.toInt()} S (+${engine.passiveIncomeRate.toInt()}/s)",
                        color = Color(0xFFFFD54F),
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                    // Allies count
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(Color(0xFF4CAF50))
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "$activeAllies",
                            color = Color(0xFF81C784),
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp
                        )
                    }
                    // Axis count
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(Color(0xFFE53935))
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "$activeAxis",
                            color = Color(0xFFE57373),
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp
                        )
                    }
                    // FPS badge
                    Text(
                        text = "$fps FPS",
                        color = if (fps >= 55) Color(0xFF81C784) else Color(0xFFFFB74D),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                // AI Wave & State Indicator
                Surface(
                    color = when (engine.enemyAiState) {
                        EnemyAiState.ATTACKING -> Color(0x66E53935)
                        EnemyAiState.DEFENDING -> Color(0x66FFA000)
                        EnemyAiState.RETREATING -> Color(0x669E9D24)
                        EnemyAiState.GATHERING -> Color(0x66263238)
                    },
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, when (engine.enemyAiState) {
                        EnemyAiState.ATTACKING -> Color(0xFFEF5350)
                        EnemyAiState.DEFENDING -> Color(0xFFFFB300)
                        EnemyAiState.RETREATING -> Color(0xFFDCE775)
                        EnemyAiState.GATHERING -> Color(0xFF455A64)
                    }),
                    modifier = Modifier.padding(horizontal = 4.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = when (engine.enemyAiState) {
                                EnemyAiState.ATTACKING -> "WAVE ${engine.enemyWaveNumber} ATTACKING"
                                EnemyAiState.DEFENDING -> "BASE DEFENSE ACTIVE"
                                EnemyAiState.RETREATING -> "AXIS RETREATING..."
                                EnemyAiState.GATHERING -> "Next Wave: ${kotlin.math.max(0, engine.enemyWaveTimer.toInt())}s"
                            },
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp
                        )
                    }
                }

                // AI Difficulty Selectors
                Row(
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AiDifficulty.values().forEach { diff ->
                        val isSelected = engine.aiDifficulty == diff
                        FilledTonalButton(
                            onClick = { engine.setDifficulty(diff) },
                            colors = ButtonDefaults.filledTonalButtonColors(
                                containerColor = if (isSelected) Color(0xFFFFB300) else Color(0xFF263238),
                                contentColor = if (isSelected) Color.Black else Color.White
                            ),
                            contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                            modifier = Modifier.height(28.dp)
                        ) {
                            Text(diff.displayName.uppercase(), fontSize = 9.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // Top action buttons: Pan Toggle, Scenario Select, Briefing, Restart
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                // Map Pan Toggle Button
                FilledTonalButton(
                    onClick = { isPanningCamera = !isPanningCamera },
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = if (isPanningCamera) Color(0xFFFFB300) else Color(0xFF263238),
                        contentColor = if (isPanningCamera) Color.Black else Color.White
                    ),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    modifier = Modifier.testTag("toggle_pan_button")
                ) {
                    Icon(
                        imageVector = if (isPanningCamera) Icons.Default.PanTool else Icons.Default.CropFree,
                        contentDescription = "Pan or Select",
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(if (isPanningCamera) "PAN MODE" else "SELECT", fontSize = 11.sp)
                }

                // Briefing Button
                IconButton(
                    onClick = { showBriefingDialog = true },
                    modifier = Modifier
                        .size(36.dp)
                        .background(Color(0xFF263238), CircleShape)
                        .testTag("briefing_button")
                ) {
                    Icon(Icons.Default.Info, contentDescription = "Briefing", tint = Color.White, modifier = Modifier.size(18.dp))
                }

                // Scenario Selector
                FilledTonalButton(
                    onClick = { showScenarioDialog = true },
                    colors = ButtonDefaults.filledTonalButtonColors(containerColor = Color(0xFF263238)),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    modifier = Modifier.testTag("scenarios_button")
                ) {
                    Icon(Icons.Default.Layers, contentDescription = "Scenarios", tint = Color(0xFFFFB300), modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("MISSIONS", color = Color.White, fontSize = 11.sp)
                }

                // Restart Mission Button
                IconButton(
                    onClick = { engine.loadScenario(engine.currentScenario) },
                    modifier = Modifier
                        .size(36.dp)
                        .background(Color(0xFF37474F), CircleShape)
                        .testTag("restart_mission_button")
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = "Restart", tint = Color.White, modifier = Modifier.size(18.dp))
                }
            }
        }

        // Live AI Alert Notification Banner (Pops up on waves, retreats, or base breach)
        engine.aiNotificationText?.let { alertText ->
            Surface(
                color = Color(0xEE1E242B),
                shape = RoundedCornerShape(8.dp),
                border = BorderStroke(1.dp, Color(0xFFFF5252)),
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 54.dp)
                    .widthIn(max = 480.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Warning,
                        contentDescription = "Alert",
                        tint = Color(0xFFFF5252),
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = alertText,
                        color = Color(0xFFFF5252),
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                }
            }
        }

        // Minimap Radar (Top Right below header)
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 54.dp, end = 16.dp)
                .size(140.dp, 90.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xEE10161C))
                .border(1.dp, Color(0xFF37474F), RoundedCornerShape(8.dp))
                .testTag("minimap_radar")
        ) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val scaleX = size.width / engine.mapWidth
                val scaleY = size.height / engine.mapHeight

                // Draw units on minimap
                for (u in engine.units) {
                    if (u.isDestroyed) continue
                    val dotColor = if (u.faction == Faction.ALLIED) Color(0xFF4CAF50) else Color(0xFFE53935)
                    drawCircle(
                        color = dotColor,
                        radius = if (u.unitClass.isHeavy) 2.5f else 1.8f,
                        center = Offset(u.x * scaleX, u.y * scaleY)
                    )
                }

                // Viewport rectangle
                val viewW = 1000f * scaleX
                val viewH = 600f * scaleY
                drawRect(
                    color = Color(0x66FFB300),
                    topLeft = Offset(camX * scaleX, camY * scaleY),
                    size = Size(viewW, viewH),
                    style = Stroke(width = 1f)
                )
            }
            Text(
                text = "RADAR",
                fontSize = 8.sp,
                color = Color(0x88FFFFFF),
                modifier = Modifier.padding(4.dp)
            )
        }

        // Bottom Tactical Command Deck & Unit Inspection Card
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom
        ) {
            // Selected Unit Details Card
            if (selectedUnits.isNotEmpty()) {
                val primaryUnit = selectedUnits.first()
                Surface(
                    color = Color(0xF0182026),
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, Color(0xFF455A64)),
                    modifier = Modifier.widthIn(min = 280.dp, max = 360.dp)
                ) {
                    Column(modifier = Modifier.padding(10.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = if (selectedUnits.size > 1) "Platoon (${selectedUnits.size} Units)" else primaryUnit.unitClass.displayName,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFFFFB300),
                                fontSize = 13.sp
                            )
                            Text(
                                text = "ORDER: ${primaryUnit.state.name}",
                                color = Color(0xFF80CBC4),
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }

                        Spacer(modifier = Modifier.height(4.dp))

                        // Armor Rating display
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "ARMOR: F:${primaryUnit.unitClass.armorFront.toInt()}  S:${primaryUnit.unitClass.armorSide.toInt()}  R:${primaryUnit.unitClass.armorRear.toInt()}",
                                color = Color(0xFFB0BEC5),
                                fontSize = 10.sp
                            )
                            Text(
                                text = "PEN: ${primaryUnit.unitClass.armorPen.toInt()}",
                                color = Color(0xFFFF8A65),
                                fontSize = 10.sp
                            )
                        }

                        Spacer(modifier = Modifier.height(4.dp))

                        // HP Bar
                        val hpPercent = (primaryUnit.hp / primaryUnit.unitClass.maxHp).coerceIn(0f, 1f)
                        LinearProgressIndicator(
                            progress = { hpPercent },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(6.dp)
                                .clip(RoundedCornerShape(3.dp)),
                            color = if (hpPercent > 0.5f) Color(0xFF4CAF50) else if (hpPercent > 0.25f) Color(0xFFFFB74D) else Color(0xFFE53935),
                            trackColor = Color(0xFF263238),
                        )
                    }
                }
            } else {
                // Empty hint
                Surface(
                    color = Color(0x99182026),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = "Tap or drag box to select units | Tap ground to command",
                        color = Color(0xFF90A4AE),
                        fontSize = 11.sp,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                    )
                }
            }

            // Command Action Buttons
            Surface(
                color = Color(0xF0182026),
                shape = RoundedCornerShape(12.dp),
                border = BorderStroke(1.dp, Color(0xFF455A64))
            ) {
                Row(
                    modifier = Modifier.padding(6.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    // Move Order Button
                    CommandButton(
                        label = "MOVE",
                        icon = Icons.Default.DirectionsWalk,
                        isActive = currentOrderMode == OrderMode.MOVE,
                        testTag = "cmd_move_button"
                    ) {
                        currentOrderMode = OrderMode.MOVE
                    }

                    // Attack-Move Order Button
                    CommandButton(
                        label = "A-MOVE",
                        icon = Icons.Default.GpsFixed,
                        isActive = currentOrderMode == OrderMode.ATTACK_MOVE,
                        testTag = "cmd_attack_move_button"
                    ) {
                        currentOrderMode = OrderMode.ATTACK_MOVE
                    }

                    // Halt / Stop Button
                    CommandButton(
                        label = "HALT",
                        icon = Icons.Default.PanTool,
                        isActive = false,
                        testTag = "cmd_halt_button"
                    ) {
                        engine.issueOrderToSelected(0f, 0f, OrderMode.STOP)
                    }

                    // Select All Button
                    CommandButton(
                        label = "ALL ALLIES",
                        icon = Icons.Default.SelectAll,
                        isActive = false,
                        testTag = "cmd_select_all_button"
                    ) {
                        engine.selectAllAllied()
                        TacticalAudio.playOrderBeep()
                    }

                    // Build Structure Button
                    CommandButton(
                        label = "BUILD (+)",
                        icon = Icons.Default.AddBusiness,
                        isActive = showBuildCatalogDialog || engine.pendingBuildingToPlace != null,
                        testTag = "cmd_build_button"
                    ) {
                        showBuildCatalogDialog = true
                    }
                }
            }
        }

        // Victory / Defeat Modal
        engine.battleWon?.let { won ->
            AlertDialog(
                onDismissRequest = {},
                title = {
                    Text(
                        text = if (won) "TACTICAL VICTORY!" else "FRONT COMPROMISED",
                        color = if (won) Color(0xFF4CAF50) else Color(0xFFE53935),
                        fontWeight = FontWeight.Black
                    )
                },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(
                            text = if (won) "The frontline has held. Enemy armored elements routed!" else "Allied battlegroup neutralized. Fall back to secondary positions.",
                            color = Color.White,
                            fontSize = 13.sp
                        )
                        HorizontalDivider(color = Color(0xFF455A64))
                        Text("Enemy Destroyed: ${engine.enemyUnitsDestroyed}", color = Color(0xFFB0BEC5), fontSize = 12.sp)
                        Text("Allied Losses: ${engine.playerUnitsLost}", color = Color(0xFFB0BEC5), fontSize = 12.sp)
                        Text("Armor Deflections: ${engine.shotsDeflected}", color = Color(0xFFFFB300), fontSize = 12.sp)
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            val nextIdx = (engine.scenarios.indexOf(engine.currentScenario) + 1) % engine.scenarios.size
                            engine.loadScenario(engine.scenarios[nextIdx])
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFFB300), contentColor = Color.Black),
                        modifier = Modifier.testTag("next_mission_button")
                    ) {
                        Text("NEXT MISSION")
                    }
                },
                dismissButton = {
                    OutlinedButton(
                        onClick = { engine.loadScenario(engine.currentScenario) },
                        modifier = Modifier.testTag("retry_mission_button")
                    ) {
                        Text("RETRY", color = Color.White)
                    }
                },
                containerColor = Color(0xFF1E282D)
            )
        }

        // Scenario Selection Modal
        if (showScenarioDialog) {
            AlertDialog(
                onDismissRequest = { showScenarioDialog = false },
                title = { Text("SELECT OPERATION", fontWeight = FontWeight.Bold, color = Color(0xFFFFB300)) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        engine.scenarios.forEach { sc ->
                            Surface(
                                onClick = {
                                    engine.loadScenario(sc)
                                    showScenarioDialog = false
                                },
                                shape = RoundedCornerShape(8.dp),
                                color = if (engine.currentScenario.id == sc.id) Color(0xFF37474F) else Color(0xFF263238),
                                border = if (engine.currentScenario.id == sc.id) BorderStroke(1.dp, Color(0xFFFFB300)) else null,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text(sc.title, fontWeight = FontWeight.Bold, color = Color.White, fontSize = 13.sp)
                                    Text(sc.objectiveDescription, color = Color(0xFFB0BEC5), fontSize = 11.sp)
                                    Text("Forces: ${sc.playerArmies.size} Allies vs ${sc.enemyArmies.size} Axis", color = Color(0xFF80CBC4), fontSize = 10.sp)
                                }
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showScenarioDialog = false }) {
                        Text("CLOSE", color = Color(0xFFFFB300))
                    }
                },
                containerColor = Color(0xFF1E282D)
            )
        }

        // Mission Briefing Dialog
        if (showBriefingDialog) {
            AlertDialog(
                onDismissRequest = { showBriefingDialog = false },
                title = { Text(engine.currentScenario.title, fontWeight = FontWeight.Bold, color = Color(0xFFFFB300)) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("OPERATIONAL BRIEFING", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color(0xFF80CBC4))
                        Text(engine.currentScenario.briefing, color = Color.White, fontSize = 13.sp)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("TACTICAL RULES OF ENGAGEMENT", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color(0xFF80CBC4))
                        Text("• Hit armored vehicles in the flank or rear to bypass thick frontal armor.", color = Color(0xFFB0BEC5), fontSize = 12.sp)
                        Text("• Use Artillery to suppress groups; protect with infantry screens.", color = Color(0xFFB0BEC5), fontSize = 12.sp)
                        Text("• Drag box to command multi-unit platoons in formation.", color = Color(0xFFB0BEC5), fontSize = 12.sp)
                    }
                },
                confirmButton = {
                    Button(
                        onClick = { showBriefingDialog = false },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFFB300), contentColor = Color.Black)
                    ) {
                        Text("UNDERSTOOD")
                    }
                },
                containerColor = Color(0xFF1E282D)
            )
        }

        // Build Catalog Dialog
        if (showBuildCatalogDialog) {
            AlertDialog(
                onDismissRequest = { showBuildCatalogDialog = false },
                title = { Text("CONSTRUCTION BLUEPRINTS", fontWeight = FontWeight.Bold, color = Color(0xFFFFB300)) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("Select structure to position on battlefield:", fontSize = 12.sp, color = Color(0xFFB0BEC5))
                        val structures = listOf(BuildingClass.HQ, BuildingClass.BARRACKS, BuildingClass.FACTORY, BuildingClass.TURRET)
                        structures.forEach { bClass ->
                            val canAfford = engine.currentSupply >= bClass.cost
                            Surface(
                                onClick = {
                                    if (canAfford) {
                                        engine.startBuildingPlacement(bClass)
                                        showBuildCatalogDialog = false
                                    }
                                },
                                shape = RoundedCornerShape(8.dp),
                                color = if (canAfford) Color(0xFF263238) else Color(0xFF1B2228),
                                border = if (canAfford) BorderStroke(1.dp, Color(0xFF455A64)) else BorderStroke(1.dp, Color(0xFF37474F)),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier.padding(12.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text(bClass.displayName, fontWeight = FontWeight.Bold, color = if (canAfford) Color.White else Color.Gray, fontSize = 13.sp)
                                        val desc = when (bClass) {
                                            BuildingClass.HQ -> "+10 Supply/sec passive, Engineer training"
                                            BuildingClass.BARRACKS -> "Rifle Squads & Rocket Soldiers"
                                            BuildingClass.FACTORY -> "Scout Cars, Medium Tanks, Heavy Tanks"
                                            BuildingClass.TURRET -> "Automated anti-air & anti-armor missiles"
                                        }
                                        Text(desc, fontSize = 11.sp, color = Color(0xFF90A4AE))
                                    }
                                    Text(
                                        "${bClass.cost} S",
                                        fontWeight = FontWeight.Bold,
                                        color = if (canAfford) Color(0xFFFFD54F) else Color(0xFFE57373),
                                        fontSize = 13.sp
                                    )
                                }
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showBuildCatalogDialog = false }) {
                        Text("CANCEL", color = Color(0xFFFFB300))
                    }
                },
                containerColor = Color(0xFF1E282D)
            )
        }

        // Building Production Card (Shown when an Allied building is selected)
        if (selectedBuilding != null && selectedBuilding.faction == Faction.ALLIED) {
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 84.dp)
                    .widthIn(max = 550.dp),
                shape = RoundedCornerShape(12.dp),
                color = Color(0xF21A2228),
                border = BorderStroke(1.dp, Color(0xFF455A64))
            ) {
                Column(
                    modifier = Modifier.padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "${selectedBuilding.buildingClass.displayName} (HP: ${selectedBuilding.hp.toInt()}/${selectedBuilding.buildingClass.maxHp.toInt()})",
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF81C784),
                            fontSize = 13.sp
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilledTonalButton(
                                onClick = { isSettingRallyPoint = true },
                                colors = ButtonDefaults.filledTonalButtonColors(
                                    containerColor = if (isSettingRallyPoint) Color(0xFFFFB300) else Color(0xFF37474F),
                                    contentColor = if (isSettingRallyPoint) Color.Black else Color.White
                                ),
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp)
                            ) {
                                Text(if (isSettingRallyPoint) "TAP MAP FOR RALLY" else "RALLY POINT", fontSize = 10.sp)
                            }
                            IconButton(
                                onClick = { engine.clearSelection() },
                                modifier = Modifier.size(24.dp)
                            ) {
                                Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White)
                            }
                        }
                    }

                    // Queue status & progress
                    if (selectedBuilding.isUnderConstruction) {
                        Text("Under Construction (${selectedBuilding.buildTimer.toInt()}s remaining)", color = Color(0xFFFFB300), fontSize = 11.sp)
                    } else if (selectedBuilding.queue.isNotEmpty()) {
                        val prog = (1f - selectedBuilding.productionTimer / selectedBuilding.productionTotalTime).coerceIn(0f, 1f)
                        Text("Producing ${selectedBuilding.queue[0].displayName}... (${selectedBuilding.queue.size}/5 queued)", color = Color(0xFF80D8FF), fontSize = 11.sp)
                        LinearProgressIndicator(
                            progress = { prog },
                            modifier = Modifier.fillMaxWidth().height(4.dp),
                            color = Color(0xFF00E5FF),
                            trackColor = Color(0xFF263238)
                        )
                    } else {
                        Text("Production Queue: Idle (0/5)", color = Color(0xFFB0BEC5), fontSize = 11.sp)
                    }

                    // Unit Recruitment Buttons
                    if (!selectedBuilding.isUnderConstruction && selectedBuilding.buildingClass.producibleUnits.isNotEmpty()) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            selectedBuilding.buildingClass.producibleUnits.forEach { uClass ->
                                val cost = (uClass.damage * 4f + uClass.maxHp * 0.5f).toInt()
                                val canAfford = engine.currentSupply >= cost && selectedBuilding.queue.size < 5
                                Button(
                                    onClick = { engine.enqueueUnitProduction(selectedBuilding, uClass) },
                                    enabled = canAfford,
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = Color(0xFF263238),
                                        contentColor = Color.White,
                                        disabledContainerColor = Color(0xFF192024),
                                        disabledContentColor = Color.Gray
                                    ),
                                    shape = RoundedCornerShape(8.dp),
                                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(uClass.displayName, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                                        Text("$cost S", fontSize = 10.sp, color = if (canAfford) Color(0xFFFFD54F) else Color.Gray)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun CommandButton(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    isActive: Boolean,
    testTag: String,
    onClick: () -> Unit
) {
    FilledTonalButton(
        onClick = onClick,
        colors = ButtonDefaults.filledTonalButtonColors(
            containerColor = if (isActive) Color(0xFFFFB300) else Color(0xFF263238),
            contentColor = if (isActive) Color.Black else Color.White
        ),
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.testTag(testTag)
    ) {
        Icon(icon, contentDescription = label, modifier = Modifier.size(14.dp))
        Spacer(modifier = Modifier.width(4.dp))
        Text(label, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

// Canvas Drawing Helper Functions
private fun DrawScope.drawTacticalTerrain(mapW: Float, mapH: Float, camX: Float, camY: Float) {
    // Background battlefield dirt/grass
    drawRect(
        color = Color(0xFF232A24),
        topLeft = Offset(-camX, -camY),
        size = Size(mapW, mapH)
    )

    // 1. Central Road (Speed Boost)
    val roadY = mapH * 0.5f - 50f
    drawRect(
        color = Color(0xFF3E3B36),
        topLeft = Offset(-camX, roadY - camY),
        size = Size(mapW, 100f)
    )
    // Road center markings
    var rx = 0f
    while (rx < mapW) {
        drawLine(
            color = Color(0x66FFD54F),
            start = Offset(rx - camX, mapH * 0.5f - camY),
            end = Offset(rx + 40f - camX, mapH * 0.5f - camY),
            strokeWidth = 3f
        )
        rx += 80f
    }

    // 2. Vertical River (Water - Blocked)
    val riverX = mapW * 0.5f - 75f
    // River segment above road
    drawRect(
        color = Color(0xFF1B3A4B),
        topLeft = Offset(riverX - camX, -camY),
        size = Size(150f, roadY)
    )
    // River segment below road
    drawRect(
        color = Color(0xFF1B3A4B),
        topLeft = Offset(riverX - camX, roadY + 100f - camY),
        size = Size(150f, mapH - (roadY + 100f))
    )

    // Bridge crossing over the river
    drawRect(
        color = Color(0xFF4E473F),
        topLeft = Offset(riverX - 20f - camX, roadY - camY),
        size = Size(190f, 100f)
    )
    drawRect(
        color = Color(0xFF2E2721),
        topLeft = Offset(riverX - 20f - camX, roadY - camY),
        size = Size(190f, 100f),
        style = Stroke(width = 3f)
    )

    // 3. Forest Clusters (Slow speed, high cover)
    val forestColor = Color(0xFF182819)
    val forestCenters = listOf(
        Offset(mapW * 0.25f, mapH * 0.25f),
        Offset(mapW * 0.25f, mapH * 0.75f),
        Offset(mapW * 0.75f, mapH * 0.25f),
        Offset(mapW * 0.75f, mapH * 0.75f),
        Offset(mapW * 0.5f, mapH * 0.15f)
    )
    for (fc in forestCenters) {
        drawCircle(color = forestColor, radius = 95f, center = Offset(fc.x - camX, fc.y - camY))
        drawCircle(color = Color(0xFF122013), radius = 65f, center = Offset(fc.x - 10f - camX, fc.y - 10f - camY))
    }

    // Tactical Grid lines every 128px
    val step = 128f
    var gx = 0f
    while (gx <= mapW) {
        drawLine(
            color = Color(0x184CAF50),
            start = Offset(gx - camX, -camY),
            end = Offset(gx - camX, mapH - camY),
            strokeWidth = 1f
        )
        gx += step
    }

    var gy = 0f
    while (gy <= mapH) {
        drawLine(
            color = Color(0x184CAF50),
            start = Offset(-camX, gy - camY),
            end = Offset(mapW - camX, gy - camY),
            strokeWidth = 1f
        )
        gy += step
    }

    // Outer map boundary warning line
    drawRect(
        color = Color(0x44E53935),
        topLeft = Offset(-camX, -camY),
        size = Size(mapW, mapH),
        style = Stroke(width = 4f)
    )
}

private fun DrawScope.drawTacticalUnit(u: TacticalUnit, camX: Float, camY: Float) {
    val screenX = u.x - camX
    val screenY = u.y - camY
    val r = u.unitClass.radius

    // Cull offscreen units
    if (screenX < -r * 2 || screenX > size.width + r * 2 || screenY < -r * 2 || screenY > size.height + r * 2) {
        return
    }

    val factionColor = if (u.faction == Faction.ALLIED) Color(0xFF4CAF50) else Color(0xFFE53935)
    val darkHullColor = if (u.faction == Faction.ALLIED) Color(0xFF2E7D32) else Color(0xFFC62828)

    // Selection ring
    if (u.isSelected) {
        drawCircle(
            color = Color(0xFF69F0AE),
            radius = r + 7f,
            center = Offset(screenX, screenY),
            style = Stroke(width = 2f)
        )
    }

    rotate(degrees = Math.toDegrees(u.angleRad.toDouble()).toFloat(), pivot = Offset(screenX, screenY)) {
        when (u.unitClass) {
            UnitClass.COMBAT_ENGINEER -> {
                // Diamond engineering squad
                drawCircle(color = factionColor, radius = r * 0.5f, center = Offset(screenX, screenY))
                drawCircle(color = Color(0xFFFFD54F), radius = r * 0.25f, center = Offset(screenX, screenY))
            }
            UnitClass.INFANTRY -> {
                // Infantry squad (3 small soldiers)
                drawCircle(color = factionColor, radius = r * 0.45f, center = Offset(screenX + 5f, screenY))
                drawCircle(color = factionColor, radius = r * 0.45f, center = Offset(screenX - 4f, screenY - 4f))
                drawCircle(color = factionColor, radius = r * 0.45f, center = Offset(screenX - 4f, screenY + 4f))
            }
            UnitClass.ROCKET_SOLDIER -> {
                // Heavy soldier with prominent rocket launcher tube
                drawCircle(color = factionColor, radius = r * 0.6f, center = Offset(screenX, screenY))
                drawLine(
                    color = Color(0xFF1B2228),
                    start = Offset(screenX - 4f, screenY),
                    end = Offset(screenX + r * 1.5f, screenY),
                    strokeWidth = 4f
                )
                drawCircle(color = Color(0xFFE53935), radius = 2.5f, center = Offset(screenX + r * 1.5f, screenY))
            }
            UnitClass.ATTACK_HELICOPTER -> {
                // Helicopter airframe
                drawRoundRect(
                    color = darkHullColor,
                    topLeft = Offset(screenX - r * 0.9f, screenY - r * 0.45f),
                    size = Size(r * 1.8f, r * 0.9f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(6f, 6f)
                )
                // Canopy
                drawCircle(color = Color(0xFF80D8FF), radius = r * 0.35f, center = Offset(screenX + r * 0.5f, screenY))
                // Rocket pods
                drawRect(color = Color(0xFF263238), topLeft = Offset(screenX - 2f, screenY - r * 0.8f), size = Size(r * 0.7f, 4f))
                drawRect(color = Color(0xFF263238), topLeft = Offset(screenX - 2f, screenY + r * 0.7f), size = Size(r * 0.7f, 4f))
                // Tail boom
                drawLine(color = darkHullColor, start = Offset(screenX - r * 0.9f, screenY), end = Offset(screenX - r * 1.7f, screenY), strokeWidth = 3f)
                // Spinning rotor blades
                val rotorTime = (System.currentTimeMillis() % 1000) / 1000f * 6.28f
                val rx1 = cos(rotorTime) * r * 1.6f
                val ry1 = sin(rotorTime) * r * 1.6f
                drawLine(color = Color(0xCCFFFFFF), start = Offset(screenX - rx1, screenY - ry1), end = Offset(screenX + rx1, screenY + ry1), strokeWidth = 2.5f)
                drawLine(color = Color(0xCCFFFFFF), start = Offset(screenX - ry1, screenY + rx1), end = Offset(screenX + ry1, screenY - rx1), strokeWidth = 2.5f)
            }
            UnitClass.SCOUT_CAR -> {
                // Wheeled armored recon
                drawRoundRect(
                    color = Color(0xFF1B2228),
                    topLeft = Offset(screenX - r * 1.1f, screenY - r * 0.7f),
                    size = Size(r * 2.2f, r * 1.4f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(4f, 4f)
                )
                drawRoundRect(
                    color = darkHullColor,
                    topLeft = Offset(screenX - r * 0.9f, screenY - r * 0.55f),
                    size = Size(r * 1.8f, r * 1.1f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(3f, 3f)
                )
            }
            UnitClass.MEDIUM_TANK, UnitClass.HEAVY_TANK -> {
                // Tank Treads
                val treadColor = Color(0xFF1B2228)
                drawRect(
                    color = treadColor,
                    topLeft = Offset(screenX - r * 1.2f, screenY - r * 0.9f),
                    size = Size(r * 2.4f, r * 0.4f)
                )
                drawRect(
                    color = treadColor,
                    topLeft = Offset(screenX - r * 1.2f, screenY + r * 0.5f),
                    size = Size(r * 2.4f, r * 0.4f)
                )

                // Armored Chassis
                drawRoundRect(
                    color = darkHullColor,
                    topLeft = Offset(screenX - r * 1.0f, screenY - r * 0.65f),
                    size = Size(r * 2.0f, r * 1.3f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(4f, 4f)
                )
            }
            UnitClass.DEFENSE_TURRET -> {
                // Fortified bunker base
                drawCircle(color = Color(0xFF37474F), radius = r * 1.1f, center = Offset(screenX, screenY))
                drawCircle(color = darkHullColor, radius = r * 0.85f, center = Offset(screenX, screenY))
            }
            UnitClass.ARTILLERY -> {
                // Artillery Gun Carriage
                drawRect(
                    color = Color(0xFF263238),
                    topLeft = Offset(screenX - r * 1.1f, screenY - r * 0.8f),
                    size = Size(r * 1.6f, r * 1.6f)
                )
            }
        }
    }

    // Independent Turret & Gun Barrel
    if (u.unitClass != UnitClass.INFANTRY && u.unitClass != UnitClass.COMBAT_ENGINEER && u.unitClass != UnitClass.ATTACK_HELICOPTER && u.unitClass != UnitClass.ROCKET_SOLDIER) {
        rotate(degrees = Math.toDegrees(u.turretAngleRad.toDouble()).toFloat(), pivot = Offset(screenX, screenY)) {
            // Gun Barrel
            val barrelLen = if (u.unitClass == UnitClass.ARTILLERY) r * 2.2f else r * 1.6f
            val barrelWidth = if (u.unitClass == UnitClass.HEAVY_TANK) 5f else 3.5f
            drawLine(
                color = Color(0xFF37474F),
                start = Offset(screenX, screenY),
                end = Offset(screenX + barrelLen, screenY),
                strokeWidth = barrelWidth
            )

            // Turret Cupola
            drawCircle(
                color = factionColor,
                radius = r * 0.55f,
                center = Offset(screenX, screenY)
            )
            drawCircle(
                color = Color(0xFF1B2228),
                radius = r * 0.35f,
                center = Offset(screenX, screenY)
            )
        }
    }

    // Health Bar
    val barWidth = r * 2.4f
    val barHeight = 3.5f
    val barTop = screenY - r - 7f
    val hpRatio = (u.hp / u.unitClass.maxHp).coerceIn(0f, 1f)

    drawRect(
        color = Color(0xAA000000),
        topLeft = Offset(screenX - barWidth / 2f, barTop),
        size = Size(barWidth, barHeight)
    )
    drawRect(
        color = if (hpRatio > 0.5f) Color(0xFF4CAF50) else if (hpRatio > 0.25f) Color(0xFFFFB74D) else Color(0xFFE53935),
        topLeft = Offset(screenX - barWidth / 2f, barTop),
        size = Size(barWidth * hpRatio, barHeight)
    )
}

private fun DrawScope.drawUnitWreck(u: TacticalUnit, camX: Float, camY: Float) {
    val screenX = u.x - camX
    val screenY = u.y - camY
    val r = u.unitClass.radius

    drawCircle(
        color = Color(0xCC111111),
        radius = r * 0.9f,
        center = Offset(screenX, screenY)
    )
    drawLine(
        color = Color(0xFF3E2723),
        start = Offset(screenX - r * 0.6f, screenY - r * 0.6f),
        end = Offset(screenX + r * 0.6f, screenY + r * 0.6f),
        strokeWidth = 2.5f
    )
}

private fun DrawScope.drawTacticalProjectile(p: TacticalProjectile, camX: Float, camY: Float) {
    val sx = p.x - camX
    val sy = p.y - camY

    val hyp = hypot(p.vx, p.vy)
    val vxNorm = if (hyp > 0f) p.vx / hyp else 1f
    val vyNorm = if (hyp > 0f) p.vy / hyp else 0f

    when (p.projectileType) {
        ProjectileType.BULLET -> {
            drawLine(
                color = Color(0xFFFFEB3B),
                start = Offset(sx, sy),
                end = Offset(sx - vxNorm * 10f, sy - vyNorm * 10f),
                strokeWidth = 2f
            )
            drawCircle(color = Color.White, radius = 1.5f, center = Offset(sx, sy))
        }
        ProjectileType.ROCKET -> {
            // Rocket body
            drawLine(
                color = Color(0xFFFF5722),
                start = Offset(sx, sy),
                end = Offset(sx - vxNorm * 14f, sy - vyNorm * 14f),
                strokeWidth = 3.5f
            )
            // Smoke / exhaust plume
            drawCircle(color = Color(0xFFFFAB00), radius = 3.5f, center = Offset(sx - vxNorm * 14f, sy - vyNorm * 14f))
            drawCircle(color = Color(0x889E9E9E), radius = 5f, center = Offset(sx - vxNorm * 22f, sy - vyNorm * 22f))
        }
        ProjectileType.TANK_SHELL -> {
            val tailLen = if (p.isArtillery) 22f else 15f
            drawLine(
                color = Color(0xFFFF9800),
                start = Offset(sx, sy),
                end = Offset(sx - vxNorm * tailLen, sy - vyNorm * tailLen),
                strokeWidth = if (p.isArtillery) 4.5f else 3f
            )
            drawCircle(color = Color.White, radius = 2.5f, center = Offset(sx, sy))
        }
    }
}

private fun DrawScope.drawCombatParticle(p: CombatParticle, camX: Float, camY: Float) {
    val sx = p.x - camX
    val sy = p.y - camY
    val progress = (1f - p.life / p.maxLife).coerceIn(0f, 1f)
    val alpha = (1f - progress).coerceIn(0f, 1f)

    when (p.kind) {
        ParticleKind.MUZZLE_FLASH -> {
            val flashLen = p.radius * 1.5f * (1f - progress)
            drawLine(
                color = Color(1f, 0.95f, 0.5f, alpha),
                start = Offset(sx, sy),
                end = Offset(sx + p.dirX * flashLen, sy + p.dirY * flashLen),
                strokeWidth = 4f
            )
            drawCircle(color = Color.White, radius = 3.5f * alpha, center = Offset(sx, sy))
        }
        ParticleKind.HIT_SPARK -> {
            val sparkDist = p.radius * progress
            drawLine(
                color = Color(1f, 0.85f, 0.3f, alpha),
                start = Offset(sx, sy),
                end = Offset(sx + p.dirX * sparkDist, sy + p.dirY * sparkDist),
                strokeWidth = 2f
            )
            drawCircle(color = Color.White, radius = 2f * alpha, center = Offset(sx + p.dirX * sparkDist, sy + p.dirY * sparkDist))
        }
        ParticleKind.EXPLOSION -> {
            val currentRadius = p.radius * (0.4f + progress * 0.8f)
            // Shockwave ring
            drawCircle(
                color = Color(1f, 0.4f, 0.1f, alpha * 0.7f),
                radius = currentRadius,
                center = Offset(sx, sy),
                style = Stroke(width = 3f)
            )
            // Core fire flash
            drawCircle(
                color = Color(1f, 0.95f, 0.4f, alpha),
                radius = currentRadius * 0.45f,
                center = Offset(sx, sy)
            )
        }
        ParticleKind.DEATH_WRECKAGE -> {
            val scorchRadius = p.radius * 0.8f
            drawCircle(
                color = Color(0.12f, 0.12f, 0.12f, alpha * 0.6f),
                radius = scorchRadius,
                center = Offset(sx, sy)
            )
            val currentRadius = p.radius * (0.3f + progress * 0.9f)
            drawCircle(
                color = Color(1f, 0.5f, 0.1f, alpha * 0.8f),
                radius = currentRadius,
                center = Offset(sx, sy),
                style = Stroke(width = 4f)
            )
        }
    }
}

private fun DrawScope.drawTacticalSupplyCrate(crate: TacticalSupplyCrate, camX: Float, camY: Float) {
    val sx = crate.x - camX
    val sy = crate.y - camY
    val w = 24f
    val h = 20f

    // Crate body
    drawRect(
        color = Color(0xFF8D6E63),
        topLeft = Offset(sx - w * 0.5f, sy - h * 0.5f),
        size = Size(w, h)
    )
    drawRect(
        color = Color(0xFF3E2723),
        topLeft = Offset(sx - w * 0.5f, sy - h * 0.5f),
        size = Size(w, h),
        style = Stroke(width = 1.5f)
    )
    // Golden supply stencil star
    drawCircle(color = Color(0xFFFFD54F), radius = 4f, center = Offset(sx, sy))
}

private fun DrawScope.drawTacticalBuilding(b: TacticalBuilding, camX: Float, camY: Float) {
    val sx = b.x - camX
    val sy = b.y - camY
    val r = b.buildingClass.radius

    val factionColor = if (b.faction == Faction.ALLIED) Color(0xFF2E7D32) else Color(0xFFC62828)
    val accentColor = if (b.faction == Faction.ALLIED) Color(0xFF81C784) else Color(0xFFE57373)

    // Selection ring & Rally line
    if (b.isSelected) {
        drawCircle(
            color = Color(0xFF69F0AE),
            radius = r + 8f,
            center = Offset(sx, sy),
            style = Stroke(width = 2.5f)
        )
        if (b.rallyX != 0f) {
            val rx = b.rallyX - camX
            val ry = b.rallyY - camY
            drawLine(
                color = Color(0x9969F0AE),
                start = Offset(sx, sy),
                end = Offset(rx, ry),
                strokeWidth = 2f
            )
            drawCircle(color = Color(0xFF69F0AE), radius = 5f, center = Offset(rx, ry))
        }
    }

    // Base building shape
    drawCircle(color = factionColor, radius = r, center = Offset(sx, sy))
    drawCircle(color = Color(0xFF1B2228), radius = r, center = Offset(sx, sy), style = Stroke(width = 3f))

    when (b.buildingClass) {
        BuildingClass.HQ -> {
            // Fortified bunker + radar dish
            drawRect(
                color = Color(0xFF37474F),
                topLeft = Offset(sx - r * 0.55f, sy - r * 0.55f),
                size = Size(r * 1.1f, r * 1.1f)
            )
            drawCircle(color = Color.White, radius = r * 0.35f, center = Offset(sx, sy))
            drawCircle(color = accentColor, radius = r * 0.2f, center = Offset(sx, sy))
        }
        BuildingClass.BARRACKS -> {
            // Quonset hut with roof lines
            drawRoundRect(
                color = Color(0xFF334E35),
                topLeft = Offset(sx - r * 0.65f, sy - r * 0.45f),
                size = Size(r * 1.3f, r * 0.9f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(6f, 6f)
            )
            drawLine(
                color = Color.White,
                start = Offset(sx - r * 0.65f, sy),
                end = Offset(sx + r * 0.65f, sy),
                strokeWidth = 2f
            )
        }
        BuildingClass.FACTORY -> {
            // Industrial factory with smokestacks
            drawRect(
                color = Color(0xFF37474F),
                topLeft = Offset(sx - r * 0.7f, sy - r * 0.5f),
                size = Size(r * 1.4f, r * 1.0f)
            )
            drawCircle(color = Color(0xFF212121), radius = r * 0.2f, center = Offset(sx - r * 0.35f, sy - r * 0.25f))
            drawCircle(color = Color(0xFF212121), radius = r * 0.2f, center = Offset(sx + r * 0.35f, sy - r * 0.25f))
        }
        BuildingClass.TURRET -> {
            // Pillbox turret with rotating cannon
            drawCircle(color = Color(0xFF263238), radius = r * 0.75f, center = Offset(sx, sy))
            val dirX = cos(b.turretAngleRad)
            val dirY = sin(b.turretAngleRad)
            drawLine(
                color = Color(0xFFFFB300),
                start = Offset(sx, sy),
                end = Offset(sx + dirX * r * 1.2f, sy + dirY * r * 1.2f),
                strokeWidth = 4f
            )
        }
    }

    // Health / Construction Bar
    val barW = r * 2.2f
    val barH = 4f
    val barY = sy - r - 10f

    if (b.isUnderConstruction) {
        val prog = 1f - (b.buildTimer / b.buildingClass.buildTimeSec).coerceIn(0f, 1f)
        drawRect(color = Color(0xCC000000), topLeft = Offset(sx - barW / 2f, barY), size = Size(barW, barH))
        drawRect(color = Color(0xFFFFB300), topLeft = Offset(sx - barW / 2f, barY), size = Size(barW * prog, barH))
    } else {
        val hpRatio = (b.hp / b.buildingClass.maxHp).coerceIn(0f, 1f)
        drawRect(color = Color(0xCC000000), topLeft = Offset(sx - barW / 2f, barY), size = Size(barW, barH))
        drawRect(
            color = if (hpRatio > 0.5f) Color(0xFF4CAF50) else Color(0xFFE53935),
            topLeft = Offset(sx - barW / 2f, barY),
            size = Size(barW * hpRatio, barH)
        )
    }
}

private fun DrawScope.drawBuildingGhost(x: Float, y: Float, radius: Float, isValid: Boolean, camX: Float, camY: Float) {
    val sx = x - camX
    val sy = y - camY
    val tint = if (isValid) Color(0x774CAF50) else Color(0x77E53935)
    val strokeColor = if (isValid) Color(0xFF4CAF50) else Color(0xFFE53935)

    drawCircle(color = tint, radius = radius, center = Offset(sx, sy))
    drawCircle(color = strokeColor, radius = radius, center = Offset(sx, sy), style = Stroke(width = 2.5f))
    drawLine(color = strokeColor, start = Offset(sx - radius * 1.3f, sy), end = Offset(sx + radius * 1.3f, sy), strokeWidth = 1.5f)
    drawLine(color = strokeColor, start = Offset(sx, sy - radius * 1.3f), end = Offset(sx, sy + radius * 1.3f), strokeWidth = 1.5f)
}

