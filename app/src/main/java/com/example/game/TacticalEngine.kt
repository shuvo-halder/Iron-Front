package com.example.game

import kotlin.math.*
import kotlin.random.Random

class TacticalEngine {

    val units = mutableListOf<TacticalUnit>()
    
    // Object pools for zero garbage collection
    private val maxProjectiles = 100
    val projectilePool = Array(maxProjectiles) { TacticalProjectile() }
    
    private val maxParticles = 80
    val particlePool = Array(maxParticles) { CombatParticle() }

    var nextUnitId = 1
    var mapWidth = 2400f
    var mapHeight = 1500f

    // Battle stats
    var playerUnitsLost = 0
    var enemyUnitsDestroyed = 0
    var shotsDeflected = 0
    var battleWon: Boolean? = null

    // Scenarios
    val scenarios = listOf(
        MissionScenario(
            id = "iron_shield",
            title = "Operation Iron Shield",
            briefing = "An enemy armored division is advancing across the plains. Form a defensive line and eliminate the enemy armor.",
            playerArmies = listOf(
                UnitClass.MEDIUM_TANK, UnitClass.MEDIUM_TANK,
                UnitClass.HEAVY_TANK,
                UnitClass.ARTILLERY,
                UnitClass.INFANTRY, UnitClass.INFANTRY, UnitClass.INFANTRY
            ),
            enemyArmies = listOf(
                UnitClass.MEDIUM_TANK, UnitClass.MEDIUM_TANK,
                UnitClass.SCOUT_CAR, UnitClass.SCOUT_CAR,
                UnitClass.HEAVY_TANK,
                UnitClass.INFANTRY, UnitClass.INFANTRY
            ),
            objectiveDescription = "Destroy all Axis armor and recon forces"
        ),
        MissionScenario(
            id = "desert_hammer",
            title = "Operation Desert Hammer",
            briefing = "Axis motorized spearhead is refueling. Rapidly maneuver your mechanized platoon to flank their heavy position.",
            playerArmies = listOf(
                UnitClass.SCOUT_CAR, UnitClass.SCOUT_CAR,
                UnitClass.MEDIUM_TANK, UnitClass.MEDIUM_TANK,
                UnitClass.ARTILLERY, UnitClass.ARTILLERY
            ),
            enemyArmies = listOf(
                UnitClass.HEAVY_TANK, UnitClass.HEAVY_TANK,
                UnitClass.MEDIUM_TANK,
                UnitClass.INFANTRY, UnitClass.INFANTRY, UnitClass.INFANTRY, UnitClass.INFANTRY
            ),
            objectiveDescription = "Neutralize the enemy heavy tank strongpoint"
        ),
        MissionScenario(
            id = "skirmish_100",
            title = "Full Front Skirmish (100 Units)",
            briefing = "Massive combined arms battle testing 100 active units at 60 FPS on Android hardware.",
            playerArmies = List(15) { UnitClass.INFANTRY } +
                    List(12) { UnitClass.MEDIUM_TANK } +
                    List(6) { UnitClass.HEAVY_TANK } +
                    List(5) { UnitClass.ARTILLERY } +
                    List(12) { UnitClass.SCOUT_CAR },
            enemyArmies = List(15) { UnitClass.INFANTRY } +
                    List(12) { UnitClass.MEDIUM_TANK } +
                    List(6) { UnitClass.HEAVY_TANK } +
                    List(5) { UnitClass.ARTILLERY } +
                    List(12) { UnitClass.SCOUT_CAR },
            objectiveDescription = "Engage in full-scale combined arms tactical warfare"
        )
    )

    var currentScenario: MissionScenario = scenarios[0]

    init {
        loadScenario(scenarios[0])
    }

    fun loadScenario(scenario: MissionScenario) {
        currentScenario = scenario
        units.clear()
        nextUnitId = 1
        playerUnitsLost = 0
        enemyUnitsDestroyed = 0
        shotsDeflected = 0
        battleWon = null

        // Reset pools
        projectilePool.forEach { it.active = false }
        particlePool.forEach { it.active = false }

        // Spawn player units on left side
        val pStartX = 350f
        val pStartY = mapHeight / 2f
        val pSpacing = 65f
        val pCols = ceil(sqrt(scenario.playerArmies.size.toDouble())).toInt()

        scenario.playerArmies.forEachIndexed { index, uClass ->
            val col = index % pCols
            val row = index / pCols
            val x = pStartX + (col - pCols / 2f) * pSpacing + Random.nextFloat() * 15f
            val y = pStartY + (row - scenario.playerArmies.size / (pCols * 2f)) * pSpacing + Random.nextFloat() * 15f
            spawnUnit(uClass, Faction.ALLIED, x, y, 0f)
        }

        // Spawn enemy units on right side
        val eStartX = mapWidth - 450f
        val eStartY = mapHeight / 2f
        val eSpacing = 65f
        val eCols = ceil(sqrt(scenario.enemyArmies.size.toDouble())).toInt()

        scenario.enemyArmies.forEachIndexed { index, uClass ->
            val col = index % eCols
            val row = index / eCols
            val x = eStartX + (col - eCols / 2f) * eSpacing + Random.nextFloat() * 15f
            val y = eStartY + (row - scenario.enemyArmies.size / (eCols * 2f)) * eSpacing + Random.nextFloat() * 15f
            spawnUnit(uClass, Faction.AXIS, x, y, Math.PI.toFloat())
        }
    }

    private fun spawnUnit(uClass: UnitClass, faction: Faction, x: Float, y: Float, initialAngle: Float): TacticalUnit {
        val unit = TacticalUnit(
            id = nextUnitId++,
            unitClass = uClass,
            faction = faction,
            x = x.coerceIn(50f, mapWidth - 50f),
            y = y.coerceIn(50f, mapHeight - 50f),
            angleRad = initialAngle,
            turretAngleRad = initialAngle,
            targetScanTimer = Random.nextFloat() * 0.2f
        )
        units.add(unit)
        return unit
    }

    fun update(deltaSec: Float) {
        val dt = deltaSec.coerceIn(0.001f, 0.05f)

        // 1. Update Projectiles
        for (i in 0 until maxProjectiles) {
            val proj = projectilePool[i]
            if (!proj.active) continue

            val moveDist = (proj.vx * proj.vx + proj.vy * proj.vy).let { sqrt(it) } * dt
            proj.x += proj.vx * dt
            proj.y += proj.vy * dt
            proj.distanceTraveled += moveDist

            // Check collision with enemy units
            var hit = false
            for (u in units) {
                if (u.isDestroyed || u.faction == proj.faction) continue
                val dx = u.x - proj.x
                val dy = u.y - proj.y
                val distSq = dx * dx + dy * dy
                val hitRadius = u.unitClass.radius + 6f
                if (distSq <= hitRadius * hitRadius) {
                    applyDamageToUnit(u, proj.damage, proj.armorPen, proj.vx, proj.vy)
                    hit = true
                    break
                }
            }

            if (hit || proj.distanceTraveled >= proj.maxDistance) {
                proj.active = false
                spawnExplosion(proj.x, proj.y, proj.isArtillery)
                if (proj.splashRadius > 0f) {
                    applySplashDamage(proj.x, proj.y, proj.splashRadius, proj.damage * 0.7f, proj.armorPen * 0.6f, proj.faction)
                }
            }
        }

        // 2. Update Particles
        for (i in 0 until maxParticles) {
            val p = particlePool[i]
            if (!p.active) continue
            p.life -= dt
            if (p.life <= 0f) {
                p.active = false
            }
        }

        // 3. Update Units
        var alliedCount = 0
        var axisCount = 0

        for (u in units) {
            if (u.isDestroyed) continue

            if (u.faction == Faction.ALLIED) alliedCount++ else axisCount++

            if (u.reloadTimer > 0f) {
                u.reloadTimer -= dt
            }

            // Staggered AI target scan
            u.targetScanTimer -= dt
            if (u.targetScanTimer <= 0f) {
                u.targetScanTimer = 0.18f + Random.nextFloat() * 0.06f
                evaluateUnitTargeting(u)
            }

            // State Machine
            when (u.state) {
                UnitState.IDLE -> {
                    alignTurretToTarget(u, dt)
                }
                UnitState.MOVE -> {
                    moveUnitToward(u, u.targetX, u.targetY, dt)
                    alignTurretToTarget(u, dt)
                }
                UnitState.ATTACK_MOVE -> {
                    val target = u.targetUnitId?.let { id -> units.firstOrNull { it.id == id && !it.isDestroyed } }
                    if (target != null) {
                        val dist = hypot(target.x - u.x, target.y - u.y)
                        if (dist <= u.unitClass.attackRange) {
                            u.state = UnitState.ATTACK_TARGET
                        } else {
                            moveUnitToward(u, target.x, target.y, dt)
                        }
                    } else {
                        moveUnitToward(u, u.targetX, u.targetY, dt)
                    }
                    alignTurretToTarget(u, dt)
                }
                UnitState.ATTACK_TARGET -> {
                    val target = u.targetUnitId?.let { id -> units.firstOrNull { it.id == id && !it.isDestroyed } }
                    if (target == null) {
                        u.targetUnitId = null
                        u.state = UnitState.IDLE
                    } else {
                        val dist = hypot(target.x - u.x, target.y - u.y)
                        if (dist > u.unitClass.attackRange * 1.25f) {
                            // Pursue
                            moveUnitToward(u, target.x, target.y, dt)
                        } else {
                            // In firing range
                            alignTurretToTarget(u, dt)
                            attemptFire(u, target)
                        }
                    }
                }
                UnitState.DESTROYED -> {}
            }
        }

        // Check Victory
        if (battleWon == null) {
            if (axisCount == 0 && alliedCount > 0) {
                battleWon = true
            } else if (alliedCount == 0 && axisCount > 0) {
                battleWon = false
            }
        }
    }

    private fun moveUnitToward(u: TacticalUnit, destX: Float, destY: Float, dt: Float) {
        val dx = destX - u.x
        val dy = destY - u.y
        val dist = hypot(dx, dy)

        val stopDist = u.unitClass.radius * 1.2f
        if (dist <= stopDist) {
            if (u.state == UnitState.MOVE) {
                u.state = UnitState.IDLE
            }
            return
        }

        val targetAngle = atan2(dy, dx)
        val angleDiff = normalizeAngle(targetAngle - u.angleRad)
        val turnSpeed = 3.5f * dt
        u.angleRad += angleDiff.coerceIn(-turnSpeed, turnSpeed)

        // Separation steering against friendly and enemy units
        var sepX = 0f
        var sepY = 0f
        var neighbors = 0
        val avoidRadius = u.unitClass.radius * 2.5f

        for (other in units) {
            if (other.id == u.id || other.isDestroyed) continue
            val odx = u.x - other.x
            val ody = u.y - other.y
            val odist = hypot(odx, ody)
            if (odist in 0.1f..avoidRadius) {
                sepX += (odx / odist) * (1f - odist / avoidRadius)
                sepY += (ody / odist) * (1f - odist / avoidRadius)
                neighbors++
            }
        }

        var dirX = cos(u.angleRad)
        var dirY = sin(u.angleRad)

        if (neighbors > 0) {
            dirX += sepX * 0.7f
            dirY += sepY * 0.7f
            val len = hypot(dirX, dirY)
            if (len > 0.001f) {
                dirX /= len
                dirY /= len
            }
        }

        val speed = u.unitClass.speed
        u.x = (u.x + dirX * speed * dt).coerceIn(40f, mapWidth - 40f)
        u.y = (u.y + dirY * speed * dt).coerceIn(40f, mapHeight - 40f)
    }

    private fun alignTurretToTarget(u: TacticalUnit, dt: Float) {
        val target = u.targetUnitId?.let { id -> units.firstOrNull { it.id == id && !it.isDestroyed } }
        val targetAngle = if (target != null) {
            atan2(target.y - u.y, target.x - u.x)
        } else {
            u.angleRad
        }
        val diff = normalizeAngle(targetAngle - u.turretAngleRad)
        val turretSpeed = 4.2f * dt
        u.turretAngleRad += diff.coerceIn(-turretSpeed, turretSpeed)
    }

    private fun evaluateUnitTargeting(u: TacticalUnit) {
        // If already tracking valid target in range, stick with it
        val cur = u.targetUnitId?.let { id -> units.firstOrNull { it.id == id && !it.isDestroyed } }
        if (cur != null) {
            val dist = hypot(cur.x - u.x, cur.y - u.y)
            if (dist <= u.unitClass.attackRange * 1.3f) return
        }

        // Find closest enemy
        var closest: TacticalUnit? = null
        var minDist = Float.MAX_VALUE
        val enemyFaction = if (u.faction == Faction.ALLIED) Faction.AXIS else Faction.ALLIED

        for (other in units) {
            if (other.isDestroyed || other.faction != enemyFaction) continue
            val dist = hypot(other.x - u.x, other.y - u.y)
            if (dist < minDist) {
                minDist = dist
                closest = other
            }
        }

        if (closest != null) {
            if (minDist <= u.unitClass.attackRange * 1.15f) {
                u.targetUnitId = closest.id
                if (u.state == UnitState.IDLE) {
                    u.state = UnitState.ATTACK_TARGET
                }
            } else if (u.faction == Faction.AXIS && u.state == UnitState.IDLE) {
                // Enemy AI aggressive advance
                u.targetUnitId = closest.id
                u.targetX = closest.x
                u.targetY = closest.y
                u.state = UnitState.ATTACK_MOVE
            }
        }
    }

    private fun attemptFire(u: TacticalUnit, target: TacticalUnit) {
        if (u.reloadTimer > 0f) return

        // Check if turret is aligned with target
        val aimAngle = atan2(target.y - u.y, target.x - u.x)
        val diff = abs(normalizeAngle(aimAngle - u.turretAngleRad))
        if (diff > 0.35f) return // Turret still traversing

        u.reloadTimer = u.unitClass.reloadTimeSec

        // Fire sound
        when (u.unitClass) {
            UnitClass.INFANTRY -> TacticalAudio.playRifleShot()
            UnitClass.ARTILLERY -> TacticalAudio.playArtilleryBoom()
            else -> TacticalAudio.playCannonFire()
        }

        // Spawn pooled projectile
        spawnProjectile(
            startX = u.x + cos(u.turretAngleRad) * (u.unitClass.radius + 4f),
            startY = u.y + sin(u.turretAngleRad) * (u.unitClass.radius + 4f),
            targetX = target.x + (Random.nextFloat() - 0.5f) * 16f,
            targetY = target.y + (Random.nextFloat() - 0.5f) * 16f,
            speed = if (u.unitClass == UnitClass.ARTILLERY) 380f else 540f,
            damage = u.unitClass.damage,
            armorPen = u.unitClass.armorPen,
            splash = u.unitClass.splashRadius,
            faction = u.faction,
            isArtillery = u.unitClass == UnitClass.ARTILLERY
        )
    }

    private fun spawnProjectile(startX: Float, startY: Float, targetX: Float, targetY: Float, speed: Float, damage: Float, armorPen: Float, splash: Float, faction: Faction, isArtillery: Boolean) {
        val proj = projectilePool.firstOrNull { !it.active } ?: return
        val dx = targetX - startX
        val dy = targetY - startY
        val dist = hypot(dx, dy)
        val dirX = if (dist > 0f) dx / dist else 1f
        val dirY = if (dist > 0f) dy / dist else 0f

        proj.active = true
        proj.x = startX
        proj.y = startY
        proj.startX = startX
        proj.startY = startY
        proj.targetX = targetX
        proj.targetY = targetY
        proj.vx = dirX * speed
        proj.vy = dirY * speed
        proj.distanceTraveled = 0f
        proj.maxDistance = dist + 15f
        proj.damage = damage
        proj.armorPen = armorPen
        proj.splashRadius = splash
        proj.faction = faction
        proj.isArtillery = isArtillery
    }

    private fun applyDamageToUnit(u: TacticalUnit, rawDamage: Float, armorPen: Float, vx: Float, vy: Float) {
        // Calculate hit angle relative to unit hull
        val shotDirX = -vx
        val shotDirY = -vy
        val shotLen = hypot(shotDirX, shotDirY)
        val normShotX = if (shotLen > 0f) shotDirX / shotLen else 0f
        val normShotY = if (shotLen > 0f) shotDirY / shotLen else 0f

        val hullForwardX = cos(u.angleRad)
        val hullForwardY = sin(u.angleRad)
        val dot = normShotX * hullForwardX + normShotY * hullForwardY

        val effectiveArmor = when {
            dot < -0.5f -> u.unitClass.armorRear // Critical rear shot!
            abs(dot) <= 0.5f -> u.unitClass.armorSide // Flank shot
            else -> u.unitClass.armorFront // Head-on frontal armor
        }

        val armorDelta = effectiveArmor - armorPen
        val damageMultiplier = if (armorDelta > 0) {
            shotsDeflected++
            (1f - (armorDelta / (effectiveArmor + 25f))).coerceIn(0.12f, 1f)
        } else {
            1f + (abs(armorDelta) / 60f).coerceIn(0f, 0.6f)
        }

        val finalDamage = max(rawDamage * damageMultiplier, 1f)
        u.hp -= finalDamage

        if (u.hp <= 0f) {
            u.isDestroyed = true
            u.state = UnitState.DESTROYED
            spawnExplosion(u.x, u.y, u.unitClass.isHeavy)
            if (u.faction == Faction.ALLIED) {
                playerUnitsLost++
            } else {
                enemyUnitsDestroyed++
            }
        }
    }

    private fun applySplashDamage(x: Float, y: Float, radius: Float, damage: Float, armorPen: Float, attackerFaction: Faction) {
        val rSq = radius * radius
        for (u in units) {
            if (u.isDestroyed || u.faction == attackerFaction) continue
            val distSq = (u.x - x) * (u.x - x) + (u.y - y) * (u.y - y)
            if (distSq <= rSq) {
                val falloff = (1f - sqrt(distSq) / radius).coerceIn(0.2f, 1f)
                applyDamageToUnit(u, damage * falloff, armorPen * falloff, 1f, 0f)
            }
        }
    }

    private fun spawnExplosion(x: Float, y: Float, isHeavy: Boolean) {
        val p = particlePool.firstOrNull { !it.active } ?: return
        p.active = true
        p.x = x
        p.y = y
        p.maxLife = if (isHeavy) 0.55f else 0.35f
        p.life = p.maxLife
        p.radius = if (isHeavy) 32f else 18f
        p.isHeavy = isHeavy
    }

    private fun normalizeAngle(angle: Float): Float {
        var a = angle
        while (a > Math.PI) a -= (2.0 * Math.PI).toFloat()
        while (a < -Math.PI) a += (2.0 * Math.PI).toFloat()
        return a
    }

    fun selectUnitsInRect(left: Float, top: Float, right: Float, bottom: Float) {
        val minX = min(left, right)
        val maxX = max(left, right)
        val minY = min(top, bottom)
        val maxY = max(top, bottom)

        for (u in units) {
            if (u.faction == Faction.ALLIED && !u.isDestroyed) {
                u.isSelected = (u.x in minX..maxX && u.y in minY..maxY)
            }
        }
    }

    fun selectSingleUnitAt(worldX: Float, worldY: Float): TacticalUnit? {
        var found: TacticalUnit? = null
        for (u in units) {
            if (u.isDestroyed) continue
            val dist = hypot(u.x - worldX, u.y - worldY)
            if (dist <= u.unitClass.radius * 1.6f) {
                found = u
                break
            }
        }
        return found
    }

    fun clearSelection() {
        for (u in units) {
            u.isSelected = false
        }
    }

    fun selectAllAllied() {
        for (u in units) {
            if (u.faction == Faction.ALLIED && !u.isDestroyed) {
                u.isSelected = true
            }
        }
    }

    fun issueOrderToSelected(targetX: Float, targetY: Float, mode: OrderMode, targetUnit: TacticalUnit? = null) {
        val selected = units.filter { it.isSelected && !it.isDestroyed }
        if (selected.isEmpty()) return

        TacticalAudio.playOrderBeep()

        if (targetUnit != null && targetUnit.faction == Faction.AXIS) {
            // Focus fire order
            for (u in selected) {
                u.targetUnitId = targetUnit.id
                u.state = UnitState.ATTACK_TARGET
            }
            return
        }

        // Formation offset calculations
        val count = selected.size
        val cols = ceil(sqrt(count.toDouble())).toInt()
        val spacing = 38f

        selected.forEachIndexed { index, u ->
            val col = index % cols
            val row = index / cols
            val offsetX = (col - cols / 2f) * spacing
            val offsetY = (row - count / (cols * 2f)) * spacing
            val destX = (targetX + offsetX).coerceIn(40f, mapWidth - 40f)
            val destY = (targetY + offsetY).coerceIn(40f, mapHeight - 40f)

            u.targetX = destX
            u.targetY = destY
            u.targetUnitId = null

            when (mode) {
                OrderMode.MOVE -> u.state = UnitState.MOVE
                OrderMode.ATTACK_MOVE -> u.state = UnitState.ATTACK_MOVE
                OrderMode.STOP -> {
                    u.state = UnitState.IDLE
                    u.targetX = u.x
                    u.targetY = u.y
                }
            }
        }
    }
}
