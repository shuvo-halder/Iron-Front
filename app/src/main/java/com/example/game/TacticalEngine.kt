package com.example.game

import kotlin.math.*
import kotlin.random.Random

class TacticalEngine {

    val units = mutableListOf<TacticalUnit>()
    val buildings = mutableListOf<TacticalBuilding>()
    val supplyCrates = mutableListOf<TacticalSupplyCrate>()

    // Object pools for zero garbage collection
    private val maxProjectiles = 120
    val projectilePool = Array(maxProjectiles) { TacticalProjectile() }
    
    private val maxParticles = 100
    val particlePool = Array(maxParticles) { CombatParticle() }

    var nextUnitId = 1
    var nextBuildingId = 1
    var nextCrateId = 1

    var mapWidth = 2400f
    var mapHeight = 1500f

    // Live Economy
    var currentSupply: Float = 450f
    var passiveIncomeRate: Float = 16f
    val MAX_SUPPLY = 2000f

    // Enemy AI Manager (3 Difficulty Levels, Wave Timers, Build Order, 0.5s ticks)
    var aiDifficulty: AiDifficulty = AiDifficulty.MEDIUM
    var enemyAiState: EnemyAiState = EnemyAiState.GATHERING
    var enemySupply: Float = 450f
    var enemyWaveTimer: Float = 30f
    var enemyWaveNumber: Int = 0
    var enemyAiTickTimer: Float = 0f
    var aiNotificationText: String? = null
    var aiNotificationTimer: Float = 0f

    val enemyBuildOrder = listOf(
        UnitClass.INFANTRY,
        UnitClass.SCOUT_CAR,
        UnitClass.ROCKET_SOLDIER,
        UnitClass.MEDIUM_TANK,
        UnitClass.INFANTRY,
        UnitClass.HEAVY_TANK,
        UnitClass.ATTACK_HELICOPTER
    )
    var enemyBuildOrderIndex = 0

    // Building Placement Mode
    var pendingBuildingToPlace: BuildingClass? = null
    var ghostX: Float = 0f
    var ghostY: Float = 0f
    var isGhostPlacementValid: Boolean = false

    // Battle stats
    var playerUnitsLost = 0
    var enemyUnitsDestroyed = 0
    var shotsDeflected = 0
    var battleWon: Boolean? = null

    // Scenarios (matching Godot Mission catalog)
    val scenarios = listOf(
        MissionScenario(
            id = "mission_01_valley_vanguard",
            missionIndex = 1,
            title = "Mission 1: Valley Vanguard",
            briefing = "Axis recon forces have established a forward command base in the valley. Deploy your armor, secure supply crates, and obliterate the enemy HQ to open the frontline.",
            objectiveType = ObjectiveType.DESTROY_HQ,
            objectiveDescription = "Destroy enemy HQ in under 180 seconds",
            parTimeSec = 180f,
            maxCasualties3Star = 4,
            rewardMoney = 150,
            startingSupply = 450f,
            aiDifficulty = AiDifficulty.EASY,
            playerArmies = listOf(
                UnitClass.MEDIUM_TANK,
                UnitClass.ROCKET_SOLDIER, UnitClass.ROCKET_SOLDIER,
                UnitClass.INFANTRY, UnitClass.INFANTRY
            ),
            enemyArmies = listOf(
                UnitClass.MEDIUM_TANK,
                UnitClass.SCOUT_CAR,
                UnitClass.INFANTRY, UnitClass.ROCKET_SOLDIER
            )
        ),
        MissionScenario(
            id = "mission_02_bridgehead_defense",
            missionIndex = 2,
            title = "Mission 2: Bridgehead Defense",
            briefing = "Axis motorized spearhead is launching a counter-offensive across the river. Hold the bridgehead and protect Allied HQ for 150 seconds until reinforcements arrive.",
            objectiveType = ObjectiveType.SURVIVE_TIME,
            objectiveDescription = "Hold bridgehead & protect Allied HQ for 150 seconds",
            surviveDurationSec = 150f,
            parTimeSec = 180f,
            maxCasualties3Star = 6,
            rewardMoney = 250,
            startingSupply = 600f,
            aiDifficulty = AiDifficulty.MEDIUM,
            playerArmies = listOf(
                UnitClass.SCOUT_CAR,
                UnitClass.MEDIUM_TANK,
                UnitClass.ROCKET_SOLDIER,
                UnitClass.INFANTRY, UnitClass.INFANTRY
            ),
            enemyArmies = listOf(
                UnitClass.HEAVY_TANK,
                UnitClass.MEDIUM_TANK,
                UnitClass.ATTACK_HELICOPTER,
                UnitClass.INFANTRY, UnitClass.ROCKET_SOLDIER
            )
        ),
        MissionScenario(
            id = "mission_03_iron_sweep",
            missionIndex = 3,
            title = "Mission 3: Iron Sweep",
            briefing = "The enemy is entrenched in full combined-arms strength. Eliminate every single hostile unit and defense building to secure the sector.",
            objectiveType = ObjectiveType.ELIMINATE_ALL,
            objectiveDescription = "Eliminate all Axis units and structures",
            parTimeSec = 240f,
            maxCasualties3Star = 5,
            rewardMoney = 400,
            startingSupply = 800f,
            aiDifficulty = AiDifficulty.HARD,
            playerArmies = List(4) { UnitClass.INFANTRY } +
                    List(3) { UnitClass.ROCKET_SOLDIER } +
                    List(3) { UnitClass.MEDIUM_TANK } +
                    List(1) { UnitClass.HEAVY_TANK } +
                    List(1) { UnitClass.ATTACK_HELICOPTER },
            enemyArmies = List(5) { UnitClass.INFANTRY } +
                    List(4) { UnitClass.ROCKET_SOLDIER } +
                    List(4) { UnitClass.MEDIUM_TANK } +
                    List(2) { UnitClass.HEAVY_TANK } +
                    List(2) { UnitClass.ATTACK_HELICOPTER }
        )
    )

    var currentScenario: MissionScenario = scenarios[0]

    init {
        loadScenario(scenarios[0])
    }

    fun loadScenario(scenario: MissionScenario) {
        currentScenario = scenario
        units.clear()
        buildings.clear()
        supplyCrates.clear()

        nextUnitId = 1
        nextBuildingId = 1
        nextCrateId = 1
        currentSupply = 450f
        pendingBuildingToPlace = null

        playerUnitsLost = 0
        enemyUnitsDestroyed = 0
        shotsDeflected = 0
        battleWon = null

        // Reset pools
        projectilePool.forEach { it.active = false }
        particlePool.forEach { it.active = false }

        // Spawn Base Structures
        // Allied Base
        spawnBuilding(BuildingClass.HQ, Faction.ALLIED, 280f, mapHeight / 2f)
        spawnBuilding(BuildingClass.BARRACKS, Faction.ALLIED, 280f, mapHeight / 2f - 140f)
        spawnBuilding(BuildingClass.TURRET, Faction.ALLIED, 520f, mapHeight / 2f)

        // Axis Base
        spawnBuilding(BuildingClass.HQ, Faction.AXIS, mapWidth - 280f, mapHeight / 2f)
        spawnBuilding(BuildingClass.FACTORY, Faction.AXIS, mapWidth - 280f, mapHeight / 2f + 140f)
        spawnBuilding(BuildingClass.TURRET, Faction.AXIS, mapWidth - 520f, mapHeight / 2f)

        // Spawn Collectible Supply Crates
        val cratePositions = listOf(
            Pair(mapWidth * 0.5f, mapHeight * 0.5f), // Central bridge crate
            Pair(mapWidth * 0.35f, mapHeight * 0.25f),
            Pair(mapWidth * 0.65f, mapHeight * 0.25f),
            Pair(mapWidth * 0.35f, mapHeight * 0.75f),
            Pair(mapWidth * 0.65f, mapHeight * 0.75f),
            Pair(mapWidth * 0.5f, 150f)
        )
        cratePositions.forEach { (cx, cy) ->
            supplyCrates.add(TacticalSupplyCrate(id = nextCrateId++, x = cx, y = cy, value = 75f))
        }

        // Spawn player units
        val pStartX = 420f
        val pStartY = mapHeight / 2f
        val pSpacing = 60f
        val pCols = ceil(sqrt(scenario.playerArmies.size.toDouble())).toInt()

        scenario.playerArmies.forEachIndexed { index, uClass ->
            val col = index % pCols
            val row = index / pCols
            val x = pStartX + (col - pCols / 2f) * pSpacing + Random.nextFloat() * 15f
            val y = pStartY + (row - scenario.playerArmies.size / (pCols * 2f)) * pSpacing + Random.nextFloat() * 15f
            spawnUnit(uClass, Faction.ALLIED, x, y, 0f)
        }

        // Spawn enemy units
        val eStartX = mapWidth - 420f
        val eStartY = mapHeight / 2f
        val eSpacing = 60f
        val eCols = ceil(sqrt(scenario.enemyArmies.size.toDouble())).toInt()

        scenario.enemyArmies.forEachIndexed { index, uClass ->
            val col = index % eCols
            val row = index / eCols
            val x = eStartX + (col - eCols / 2f) * eSpacing + Random.nextFloat() * 15f
            val y = eStartY + (row - scenario.enemyArmies.size / (eCols * 2f)) * eSpacing + Random.nextFloat() * 15f
            spawnUnit(uClass, Faction.AXIS, x, y, Math.PI.toFloat())
        }
    }

    fun spawnBuilding(bClass: BuildingClass, faction: Faction, x: Float, y: Float, underConstruction: Boolean = false): TacticalBuilding {
        val b = TacticalBuilding(
            id = nextBuildingId++,
            buildingClass = bClass,
            faction = faction,
            x = x,
            y = y,
            hp = bClass.maxHp,
            isUnderConstruction = underConstruction,
            buildTimer = if (underConstruction) bClass.buildTimeSec else 0f,
            rallyX = if (faction == Faction.ALLIED) x + bClass.radius + 60f else x - bClass.radius - 60f,
            rallyY = y
        )
        buildings.add(b)
        return b
    }

    fun spawnUnit(uClass: UnitClass, faction: Faction, x: Float, y: Float, initialAngle: Float): TacticalUnit {
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

        // 1. Passive Supply Economy
        var currentRate = 6f
        for (b in buildings) {
            if (!b.isDestroyed && !b.isUnderConstruction && b.faction == Faction.ALLIED) {
                currentRate += b.buildingClass.passiveSupplyRate
            }
        }
        passiveIncomeRate = currentRate
        currentSupply = min(currentSupply + passiveIncomeRate * dt, MAX_SUPPLY)

        // Enemy AI Economy accumulation & Timers
        enemySupply = min(enemySupply + (16f * aiDifficulty.incomeMult) * dt, MAX_SUPPLY)
        if (aiNotificationTimer > 0f) {
            aiNotificationTimer -= dt
            if (aiNotificationTimer <= 0f) aiNotificationText = null
        }
        if (enemyAiState == EnemyAiState.GATHERING) {
            enemyWaveTimer -= dt
        }

        // 0.5s Enemy AI Decision Loop (2 Hz)
        enemyAiTickTimer += dt
        if (enemyAiTickTimer >= 0.5f) {
            enemyAiTickTimer -= 0.5f
            tickEnemyAi()
        }

        // 2. Supply Crate Collection
        for (crate in supplyCrates) {
            if (crate.collected) continue
            for (u in units) {
                if (u.faction == Faction.ALLIED && !u.isDestroyed) {
                    val d = hypot(u.x - crate.x, u.y - crate.y)
                    if (d <= 36f) {
                        crate.collected = true
                        currentSupply = min(currentSupply + crate.value, MAX_SUPPLY)
                        spawnExplosion(crate.x, crate.y, false)
                        TacticalAudio.playOrderBeep()
                        break
                    }
                }
            }
        }

        // 3. Update Buildings (Construction, Production Queues, Turrets)
        for (b in buildings) {
            if (b.isDestroyed) continue

            // Construction timer
            if (b.isUnderConstruction) {
                b.buildTimer -= dt
                if (b.buildTimer <= 0f) {
                    b.isUnderConstruction = false
                    spawnExplosion(b.x, b.y, false)
                }
                continue
            }

            // Production queue
            if (b.queue.isNotEmpty()) {
                b.productionTimer -= dt
                if (b.productionTimer <= 0f) {
                    val completedClass = b.queue.removeAt(0)
                    val spawnX = b.x + (if (b.faction == Faction.ALLIED) b.buildingClass.radius + 20f else -b.buildingClass.radius - 20f)
                    val spawnY = b.y
                    val newUnit = spawnUnit(completedClass, b.faction, spawnX, spawnY, if (b.faction == Faction.ALLIED) 0f else PI.toFloat())
                    
                    // March to rally point
                    if (b.rallyX != 0f) {
                        newUnit.targetX = b.rallyX
                        newUnit.targetY = b.rallyY
                        newUnit.state = UnitState.MOVE
                    }

                    if (b.queue.isNotEmpty()) {
                        b.productionTotalTime = max(b.queue[0].reloadTimeSec * 3.5f, 3.0f)
                        b.productionTimer = b.productionTotalTime
                    }
                }
            }

            // Automated Defense Turret
            if (b.buildingClass.isTurret) {
                if (b.reloadTimer > 0f) {
                    b.reloadTimer -= dt
                } else {
                    val enemyFaction = if (b.faction == Faction.ALLIED) Faction.AXIS else Faction.ALLIED
                    var closestEnemy: TacticalUnit? = null
                    var minDist = b.buildingClass.turretRange

                    for (u in units) {
                        if (u.isDestroyed || u.faction != enemyFaction) continue
                        val dist = hypot(u.x - b.x, u.y - b.y)
                        if (dist <= minDist) {
                            minDist = dist
                            closestEnemy = u
                        }
                    }

                    if (closestEnemy != null) {
                        b.reloadTimer = 1.2f
                        b.turretAngleRad = atan2(closestEnemy.y - b.y, closestEnemy.x - b.x)
                        spawnMuzzleFlash(b.x, b.y, cos(b.turretAngleRad), sin(b.turretAngleRad))
                        spawnProjectile(
                            startX = b.x + cos(b.turretAngleRad) * 20f,
                            startY = b.y + sin(b.turretAngleRad) * 20f,
                            targetX = closestEnemy.x,
                            targetY = closestEnemy.y,
                            speed = 500f,
                            damage = b.buildingClass.turretDamage,
                            armorPen = 40f,
                            splash = 35f,
                            faction = b.faction,
                            projType = ProjectileType.ROCKET,
                            dmgType = DamageType.EXPLOSIVE,
                            isArtillery = false
                        )
                    }
                }
            }
        }

        // 4. Update Projectiles
        for (i in 0 until maxProjectiles) {
            val proj = projectilePool[i]
            if (!proj.active) continue

            val moveDist = (proj.vx * proj.vx + proj.vy * proj.vy).let { sqrt(it) } * dt
            proj.x += proj.vx * dt
            proj.y += proj.vy * dt
            proj.distanceTraveled += moveDist

            // Check collision with units
            var hit = false
            for (u in units) {
                if (u.isDestroyed || u.faction == proj.faction) continue

                if (u.unitClass.armorType == ArmorType.AIR && proj.damageType != DamageType.EXPLOSIVE) {
                    continue
                }

                val dx = u.x - proj.x
                val dy = u.y - proj.y
                val distSq = dx * dx + dy * dy
                val hitRadius = u.unitClass.radius + 6f
                if (distSq <= hitRadius * hitRadius) {
                    applyDamageToUnit(u, proj.damage, proj.armorPen, proj.vx, proj.vy, proj.damageType)
                    hit = true
                    break
                }
            }

            // Check collision with buildings
            if (!hit) {
                for (b in buildings) {
                    if (b.isDestroyed || b.faction == proj.faction) continue
                    val dx = b.x - proj.x
                    val dy = b.y - proj.y
                    if (dx * dx + dy * dy <= b.buildingClass.radius * b.buildingClass.radius) {
                        b.hp -= proj.damage
                        spawnHitSpark(b.x, b.y, -proj.vx / 500f, -proj.vy / 500f)
                        if (b.hp <= 0f) {
                            b.isDestroyed = true
                            spawnDeathWreckage(b.x, b.y, true)
                        }
                        hit = true
                        break
                    }
                }
            }

            if (hit || proj.distanceTraveled >= proj.maxDistance) {
                proj.active = false
                spawnExplosion(proj.x, proj.y, proj.isArtillery || proj.projectileType == ProjectileType.TANK_SHELL)
                if (proj.splashRadius > 0f) {
                    applySplashDamage(proj.x, proj.y, proj.splashRadius, proj.damage * 0.75f, proj.armorPen * 0.6f, proj.faction, proj.damageType)
                }
            }
        }

        // 5. Update Particles
        for (i in 0 until maxParticles) {
            val p = particlePool[i]
            if (!p.active) continue
            p.life -= dt
            if (p.life <= 0f) {
                p.active = false
            }
        }

        // 6. Update Units
        var alliedCount = 0
        var axisCount = 0

        for (u in units) {
            if (u.isDestroyed) continue

            if (u.faction == Faction.ALLIED) alliedCount++ else axisCount++

            if (u.reloadTimer > 0f) {
                u.reloadTimer -= dt
            }

            u.targetScanTimer -= dt
            if (u.targetScanTimer <= 0f) {
                u.targetScanTimer = 0.18f + Random.nextFloat() * 0.06f
                evaluateUnitTargeting(u)
            }

            when (u.state) {
                UnitState.IDLE -> alignTurretToTarget(u, dt)
                UnitState.MOVE -> {
                    moveUnitToward(u, u.targetX, u.targetY, dt)
                    alignTurretToTarget(u, dt)
                }
                UnitState.ATTACK_MOVE -> {
                    val target = u.targetUnitId?.let { id -> units.firstOrNull { it.id == id && !it.isDestroyed } }
                    if (target != null && canUnitTarget(u, target)) {
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
                    if (target == null || !canUnitTarget(u, target)) {
                        u.targetUnitId = null
                        u.state = UnitState.IDLE
                    } else {
                        val dist = hypot(target.x - u.x, target.y - u.y)
                        if (dist > u.unitClass.attackRange * 1.2f) {
                            moveUnitToward(u, target.x, target.y, dt)
                        } else {
                            alignTurretToTarget(u, dt)
                            attemptFire(u, target)
                        }
                    }
                }
                UnitState.DESTROYED -> {}
            }
        }

        // Victory / Defeat check
        if (battleWon == null) {
            val axisHq = buildings.firstOrNull { it.buildingClass == BuildingClass.HQ && it.faction == Faction.AXIS && !it.isDestroyed }
            val alliedHq = buildings.firstOrNull { it.buildingClass == BuildingClass.HQ && it.faction == Faction.ALLIED && !it.isDestroyed }

            if (axisCount == 0 && (axisHq == null || axisHq.isDestroyed)) {
                battleWon = true
            } else if (alliedCount == 0 && (alliedHq == null || alliedHq.isDestroyed)) {
                battleWon = false
            }
        }
    }

    fun setDifficulty(diff: AiDifficulty) {
        aiDifficulty = diff
        enemyWaveTimer = diff.waveIntervalSec
        aiNotificationText = "AI DIFFICULTY: ${diff.displayName.uppercase()}"
        aiNotificationTimer = 3.0f
    }

    private fun tickEnemyAi() {
        val axisHq = buildings.firstOrNull { it.buildingClass == BuildingClass.HQ && it.faction == Faction.AXIS && !it.isDestroyed }
        val basePos = if (axisHq != null) Pair(axisHq.x, axisHq.y) else Pair(mapWidth * 0.75f, mapHeight * 0.5f)
        val stagingPos = Pair(mapWidth * 0.62f, mapHeight * 0.5f)

        // 1. Base Defense Check (Highest Priority)
        val invaders = units.filter { it.faction == Faction.ALLIED && !it.isDestroyed && hypot(it.x - basePos.first, it.y - basePos.second) <= 450f }
        if (invaders.isNotEmpty()) {
            if (enemyAiState != EnemyAiState.DEFENDING) {
                enemyAiState = EnemyAiState.DEFENDING
                aiNotificationText = "AXIS BASE PERIMETER BREACHED! (${invaders.size} Invaders)"
                aiNotificationTimer = 3.0f
            }
            val primaryTarget = invaders.minByOrNull { hypot(it.x - basePos.first, it.y - basePos.second) }
            if (primaryTarget != null) {
                for (u in units) {
                    if (u.faction == Faction.AXIS && !u.isDestroyed) {
                        u.targetUnitId = primaryTarget.id
                        u.state = UnitState.ATTACK_MOVE
                    }
                }
            }
            return
        } else if (enemyAiState == EnemyAiState.DEFENDING) {
            enemyAiState = EnemyAiState.GATHERING
        }

        // 2. Economy Management & Build Order Queue
        val nextUnitClass = enemyBuildOrder[enemyBuildOrderIndex]
        if (enemySupply >= nextUnitClass.cost) {
            val facility = buildings.firstOrNull {
                it.faction == Faction.AXIS && !it.isDestroyed && !it.isUnderConstruction &&
                it.buildingClass.producibleUnits.contains(nextUnitClass) && it.queue.size < 5
            }
            if (facility != null) {
                enemySupply -= nextUnitClass.cost
                facility.queue.add(nextUnitClass)
                facility.rallyX = stagingPos.first + Random.nextFloat() * 60f - 30f
                facility.rallyY = stagingPos.second + Random.nextFloat() * 60f - 30f
                enemyBuildOrderIndex = (enemyBuildOrderIndex + 1) % enemyBuildOrder.size
            }
        }

        // 3. Outnumbered & Damage Tactical Retreat
        for (u in units) {
            if (u.faction == Faction.AXIS && !u.isDestroyed) {
                // Health threshold retreat
                val hpRatio = u.hp / u.unitClass.maxHp
                if (hpRatio <= aiDifficulty.retreatThreshold) {
                    u.targetX = basePos.first + Random.nextFloat() * 80f - 40f
                    u.targetY = basePos.second + Random.nextFloat() * 80f - 40f
                    u.state = UnitState.MOVE
                    continue
                }

                // Local outnumbered check (300f radius)
                var localAllied = 0
                var localAxis = 0
                for (other in units) {
                    if (!other.isDestroyed && hypot(other.x - u.x, other.y - u.y) <= 300f) {
                        if (other.faction == Faction.ALLIED) localAllied++ else localAxis++
                    }
                }
                if (localAllied >= 2 && (localAxis.toFloat() / localAllied.toFloat()) < aiDifficulty.retreatThreshold) {
                    u.targetX = stagingPos.first + Random.nextFloat() * 80f - 40f
                    u.targetY = stagingPos.second + Random.nextFloat() * 80f - 40f
                    u.state = UnitState.MOVE
                }
            }
        }

        // 4. Wave Formation & Launch
        if (enemyAiState == EnemyAiState.GATHERING) {
            val idleAxis = units.filter { it.faction == Faction.AXIS && !it.isDestroyed }
            if (enemyWaveTimer <= 0f && idleAxis.size >= aiDifficulty.minWaveSize) {
                enemyWaveNumber++
                enemyWaveTimer = aiDifficulty.waveIntervalSec
                enemyAiState = EnemyAiState.ATTACKING
                aiNotificationText = "AXIS WAVE $enemyWaveNumber LAUNCHED! (${aiDifficulty.displayName})"
                aiNotificationTimer = 3.5f
            }
        }

        // 5. 4-Tier Target Priority when Attacking
        if (enemyAiState == EnemyAiState.ATTACKING) {
            val alliedTurret = buildings.firstOrNull { it.buildingClass == BuildingClass.TURRET && it.faction == Faction.ALLIED && !it.isDestroyed }
            val alliedProd = buildings.firstOrNull { (it.buildingClass == BuildingClass.BARRACKS || it.buildingClass == BuildingClass.FACTORY) && it.faction == Faction.ALLIED && !it.isDestroyed }
            val alliedHq = buildings.firstOrNull { it.buildingClass == BuildingClass.HQ && it.faction == Faction.ALLIED && !it.isDestroyed }

            val activeAxisAttackers = units.filter { it.faction == Faction.AXIS && !it.isDestroyed }
            if (activeAxisAttackers.isEmpty()) {
                enemyAiState = EnemyAiState.GATHERING
                enemyWaveTimer = aiDifficulty.waveIntervalSec
                return
            }

            for (u in activeAxisAttackers) {
                // Tier 1: Nearest Threat within 350f
                val nearestThreat = units.filter { it.faction == Faction.ALLIED && !it.isDestroyed && hypot(it.x - u.x, it.y - u.y) <= 350f }
                    .minByOrNull { hypot(it.x - u.x, it.y - u.y) }
                if (nearestThreat != null) {
                    u.targetUnitId = nearestThreat.id
                    u.state = UnitState.ATTACK_TARGET
                    continue
                }

                // Tier 2: Defensive Structures (Player Defense Turret)
                if (alliedTurret != null) {
                    u.targetX = alliedTurret.x
                    u.targetY = alliedTurret.y
                    u.state = UnitState.ATTACK_MOVE
                    continue
                }

                // Tier 3: Production Structures (Player Barracks / Factory)
                if (alliedProd != null) {
                    u.targetX = alliedProd.x
                    u.targetY = alliedProd.y
                    u.state = UnitState.ATTACK_MOVE
                    continue
                }

                // Tier 4: Player Headquarters (Allied HQ)
                if (alliedHq != null) {
                    u.targetX = alliedHq.x
                    u.targetY = alliedHq.y
                    u.state = UnitState.ATTACK_MOVE
                } else {
                    u.targetX = 250f
                    u.targetY = mapHeight * 0.5f
                    u.state = UnitState.ATTACK_MOVE
                }
            }
        }
    }

    fun startBuildingPlacement(bClass: BuildingClass) {
        pendingBuildingToPlace = bClass
    }

    fun updateGhostPosition(worldX: Float, worldY: Float) {
        val bClass = pendingBuildingToPlace ?: return
        // Snap to 32px
        ghostX = (round(worldX / 32f) * 32f).coerceIn(100f, mapWidth - 100f)
        ghostY = (round(worldY / 32f) * 32f).coerceIn(100f, mapHeight - 100f)

        // Validation
        var valid = currentSupply >= bClass.cost
        val riverX = mapWidth * 0.5f - 75f
        if (ghostX in riverX..(riverX + 150f)) {
            valid = false // Inside river
        }
        for (b in buildings) {
            if (!b.isDestroyed && hypot(b.x - ghostX, b.y - ghostY) < bClass.radius + b.buildingClass.radius + 15f) {
                valid = false
                break
            }
        }
        isGhostPlacementValid = valid
    }

    fun confirmBuildingPlacement(): Boolean {
        val bClass = pendingBuildingToPlace ?: return false
        if (!isGhostPlacementValid || currentSupply < bClass.cost) return false

        currentSupply -= bClass.cost
        spawnBuilding(bClass, Faction.ALLIED, ghostX, ghostY, underConstruction = true)
        TacticalAudio.playOrderBeep()
        pendingBuildingToPlace = null
        return true
    }

    fun cancelBuildingPlacement() {
        pendingBuildingToPlace = null
    }

    fun enqueueUnitProduction(b: TacticalBuilding, uClass: UnitClass): Boolean {
        if (b.isUnderConstruction || b.queue.size >= 5) return false
        val cost = (uClass.damage * 4f + uClass.maxHp * 0.5f).toInt()
        if (currentSupply < cost) return false

        currentSupply -= cost
        b.queue.add(uClass)
        if (b.queue.size == 1) {
            b.productionTotalTime = max(uClass.reloadTimeSec * 3.5f, 3.0f)
            b.productionTimer = b.productionTotalTime
        }
        TacticalAudio.playOrderBeep()
        return true
    }

    fun selectSingleBuildingAt(worldX: Float, worldY: Float): TacticalBuilding? {
        for (b in buildings) {
            if (b.isDestroyed) continue
            val dist = hypot(b.x - worldX, b.y - worldY)
            if (dist <= b.buildingClass.radius * 1.3f) {
                return b
            }
        }
        return null
    }

    private fun canUnitTarget(attacker: TacticalUnit, target: TacticalUnit): Boolean {
        if (target.isDestroyed || target.faction == attacker.faction) return false
        if (target.unitClass.armorType == ArmorType.AIR) {
            return attacker.unitClass.canTargetAir
        }
        return true
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
        val cur = u.targetUnitId?.let { id -> units.firstOrNull { it.id == id && !it.isDestroyed } }
        if (cur != null && canUnitTarget(u, cur)) {
            val dist = hypot(cur.x - u.x, cur.y - u.y)
            if (dist <= u.unitClass.attackRange * 1.3f) return
        }

        var closest: TacticalUnit? = null
        var minDist = Float.MAX_VALUE
        val enemyFaction = if (u.faction == Faction.ALLIED) Faction.AXIS else Faction.ALLIED

        for (other in units) {
            if (other.isDestroyed || other.faction != enemyFaction) continue
            if (!canUnitTarget(u, other)) continue

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
                u.targetUnitId = closest.id
                u.targetX = closest.x
                u.targetY = closest.y
                u.state = UnitState.ATTACK_MOVE
            }
        }
    }

    private fun attemptFire(u: TacticalUnit, target: TacticalUnit) {
        if (u.reloadTimer > 0f) return

        val aimAngle = atan2(target.y - u.y, target.x - u.x)
        val diff = abs(normalizeAngle(aimAngle - u.turretAngleRad))
        if (diff > 0.35f) return

        u.reloadTimer = u.unitClass.reloadTimeSec

        when (u.unitClass) {
            UnitClass.INFANTRY -> TacticalAudio.playRifleShot()
            UnitClass.ROCKET_SOLDIER, UnitClass.ATTACK_HELICOPTER -> TacticalAudio.playCannonFire()
            UnitClass.ARTILLERY -> TacticalAudio.playArtilleryBoom()
            else -> TacticalAudio.playCannonFire()
        }

        val startX = u.x + cos(u.turretAngleRad) * (u.unitClass.radius + 4f)
        val startY = u.y + sin(u.turretAngleRad) * (u.unitClass.radius + 4f)

        spawnMuzzleFlash(startX, startY, cos(u.turretAngleRad), sin(u.turretAngleRad))

        val projSpeed = when (u.unitClass.projectileType) {
            ProjectileType.BULLET -> 650f
            ProjectileType.ROCKET -> 480f
            ProjectileType.TANK_SHELL -> 600f
        }

        spawnProjectile(
            startX = startX,
            startY = startY,
            targetX = target.x + (Random.nextFloat() - 0.5f) * 16f,
            targetY = target.y + (Random.nextFloat() - 0.5f) * 16f,
            speed = projSpeed,
            damage = u.unitClass.damage,
            armorPen = u.unitClass.armorPen,
            splash = u.unitClass.splashRadius,
            faction = u.faction,
            projType = u.unitClass.projectileType,
            dmgType = u.unitClass.damageType,
            isArtillery = u.unitClass == UnitClass.ARTILLERY
        )
    }

    private fun spawnProjectile(
        startX: Float, startY: Float,
        targetX: Float, targetY: Float,
        speed: Float, damage: Float, armorPen: Float,
        splash: Float, faction: Faction,
        projType: ProjectileType, dmgType: DamageType,
        isArtillery: Boolean
    ) {
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
        proj.projectileType = projType
        proj.damageType = dmgType
        proj.isArtillery = isArtillery
    }

    private fun applyDamageToUnit(u: TacticalUnit, rawDamage: Float, armorPen: Float, vx: Float, vy: Float, dmgType: DamageType) {
        val typeMultiplier = when (u.unitClass.armorType) {
            ArmorType.INFANTRY -> when (dmgType) {
                DamageType.KINETIC -> 1.5f
                DamageType.EXPLOSIVE -> 1.1f
                DamageType.ARMOR_PIERCING -> 0.65f
            }
            ArmorType.VEHICLE -> when (dmgType) {
                DamageType.KINETIC -> 0.25f
                DamageType.EXPLOSIVE -> 1.35f
                DamageType.ARMOR_PIERCING -> 1.5f
            }
            ArmorType.AIR -> when (dmgType) {
                DamageType.EXPLOSIVE -> 1.6f
                else -> 0.0f
            }
        }

        if (typeMultiplier <= 0f) return

        val shotDirX = -vx
        val shotDirY = -vy
        val shotLen = hypot(shotDirX, shotDirY)
        val normShotX = if (shotLen > 0f) shotDirX / shotLen else 0f
        val normShotY = if (shotLen > 0f) shotDirY / shotLen else 0f

        val hullForwardX = cos(u.angleRad)
        val hullForwardY = sin(u.angleRad)
        val dot = normShotX * hullForwardX + normShotY * hullForwardY

        val effectiveArmor = if (u.unitClass.armorType == ArmorType.VEHICLE) {
            when {
                dot < -0.4f -> u.unitClass.armorRear
                abs(dot) <= 0.4f -> u.unitClass.armorSide
                else -> u.unitClass.armorFront
            }
        } else {
            u.unitClass.armorFront
        }

        val armorDelta = effectiveArmor - armorPen
        val damageMultiplier = if (armorDelta > 0) {
            shotsDeflected++
            (1f - (armorDelta / (effectiveArmor + 22f))).coerceIn(0.15f, 1f)
        } else {
            1f + (abs(armorDelta) / 60f).coerceIn(0f, 0.6f)
        }

        val finalDamage = max(rawDamage * typeMultiplier * damageMultiplier, 1f)
        u.hp -= finalDamage

        spawnHitSpark(u.x, u.y, normShotX, normShotY)

        if (u.hp <= 0f) {
            u.isDestroyed = true
            u.state = UnitState.DESTROYED
            spawnDeathWreckage(u.x, u.y, u.unitClass.isHeavy)
            if (u.faction == Faction.ALLIED) {
                playerUnitsLost++
            } else {
                enemyUnitsDestroyed++
            }
        }
    }

    private fun applySplashDamage(x: Float, y: Float, radius: Float, damage: Float, armorPen: Float, attackerFaction: Faction, dmgType: DamageType) {
        val rSq = radius * radius
        for (u in units) {
            if (u.isDestroyed || u.faction == attackerFaction) continue
            if (u.unitClass.armorType == ArmorType.AIR && dmgType != DamageType.EXPLOSIVE) continue

            val distSq = (u.x - x) * (u.x - x) + (u.y - y) * (u.y - y)
            if (distSq <= rSq) {
                val falloff = (1f - sqrt(distSq) / radius).coerceIn(0.25f, 1f)
                applyDamageToUnit(u, damage * falloff, armorPen * falloff, 1f, 0f, dmgType)
            }
        }
    }

    private fun spawnMuzzleFlash(x: Float, y: Float, dirX: Float, dirY: Float) {
        val p = particlePool.firstOrNull { !it.active } ?: return
        p.active = true
        p.x = x
        p.y = y
        p.dirX = dirX
        p.dirY = dirY
        p.maxLife = 0.08f
        p.life = p.maxLife
        p.radius = 14f
        p.kind = ParticleKind.MUZZLE_FLASH
    }

    private fun spawnHitSpark(x: Float, y: Float, normX: Float, normY: Float) {
        val p = particlePool.firstOrNull { !it.active } ?: return
        p.active = true
        p.x = x
        p.y = y
        p.dirX = normX
        p.dirY = normY
        p.maxLife = 0.16f
        p.life = p.maxLife
        p.radius = 12f
        p.kind = ParticleKind.HIT_SPARK
    }

    private fun spawnExplosion(x: Float, y: Float, isHeavy: Boolean) {
        val p = particlePool.firstOrNull { !it.active } ?: return
        p.active = true
        p.x = x
        p.y = y
        p.maxLife = if (isHeavy) 0.45f else 0.32f
        p.life = p.maxLife
        p.radius = if (isHeavy) 36f else 20f
        p.kind = ParticleKind.EXPLOSION
        p.isHeavy = isHeavy
    }

    private fun spawnDeathWreckage(x: Float, y: Float, isHeavy: Boolean) {
        val p = particlePool.firstOrNull { !it.active } ?: return
        p.active = true
        p.x = x
        p.y = y
        p.maxLife = 0.85f
        p.life = p.maxLife
        p.radius = if (isHeavy) 45f else 28f
        p.kind = ParticleKind.DEATH_WRECKAGE
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
        for (b in buildings) {
            b.isSelected = false
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
            for (u in selected) {
                if (canUnitTarget(u, targetUnit)) {
                    u.targetUnitId = targetUnit.id
                    u.state = UnitState.ATTACK_TARGET
                }
            }
            return
        }

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
