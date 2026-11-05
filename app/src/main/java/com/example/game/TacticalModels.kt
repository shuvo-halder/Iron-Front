package com.example.game

enum class Faction {
    ALLIED,
    AXIS
}

enum class UnitClass(
    val displayName: String,
    val maxHp: Float,
    val armorFront: Float,
    val armorSide: Float,
    val armorRear: Float,
    val speed: Float,
    val attackRange: Float,
    val damage: Float,
    val armorPen: Float,
    val reloadTimeSec: Float,
    val radius: Float,
    val isHeavy: Boolean,
    val splashRadius: Float = 0f
) {
    INFANTRY(
        displayName = "Rifle Squad",
        maxHp = 60f,
        armorFront = 4f,
        armorSide = 4f,
        armorRear = 4f,
        speed = 80f,
        attackRange = 200f,
        damage = 12f,
        armorPen = 8f,
        reloadTimeSec = 0.7f,
        radius = 12f,
        isHeavy = false
    ),
    SCOUT_CAR(
        displayName = "Recon Armored Car",
        maxHp = 120f,
        armorFront = 20f,
        armorSide = 12f,
        armorRear = 8f,
        speed = 145f,
        attackRange = 240f,
        damage = 22f,
        armorPen = 24f,
        reloadTimeSec = 1.0f,
        radius = 16f,
        isHeavy = false
    ),
    MEDIUM_TANK(
        displayName = "M4 Cruiser Tank",
        maxHp = 220f,
        armorFront = 50f,
        armorSide = 30f,
        armorRear = 18f,
        speed = 95f,
        attackRange = 290f,
        damage = 45f,
        armorPen = 48f,
        reloadTimeSec = 1.6f,
        radius = 20f,
        isHeavy = true,
        splashRadius = 14f
    ),
    HEAVY_TANK(
        displayName = "Tiger Heavy Vanguard",
        maxHp = 380f,
        armorFront = 90f,
        armorSide = 55f,
        armorRear = 30f,
        speed = 65f,
        attackRange = 340f,
        damage = 90f,
        armorPen = 85f,
        reloadTimeSec = 2.6f,
        radius = 24f,
        isHeavy = true,
        splashRadius = 22f
    ),
    ARTILLERY(
        displayName = "155mm Howitzer",
        maxHp = 95f,
        armorFront = 12f,
        armorSide = 8f,
        armorRear = 6f,
        speed = 45f,
        attackRange = 620f,
        damage = 120f,
        armorPen = 65f,
        reloadTimeSec = 4.2f,
        radius = 18f,
        isHeavy = true,
        splashRadius = 48f
    )
}

enum class UnitState {
    IDLE,
    MOVE,
    ATTACK_MOVE,
    ATTACK_TARGET,
    DESTROYED
}

enum class OrderMode {
    MOVE,
    ATTACK_MOVE,
    STOP
}

data class TacticalUnit(
    val id: Int,
    val unitClass: UnitClass,
    val faction: Faction,
    var x: Float,
    var y: Float,
    var angleRad: Float = 0f,
    var turretAngleRad: Float = 0f,
    var hp: Float = unitClass.maxHp,
    var state: UnitState = UnitState.IDLE,
    var targetX: Float = x,
    var targetY: Float = y,
    var targetUnitId: Int? = null,
    var reloadTimer: Float = 0f,
    var targetScanTimer: Float = 0f,
    var isSelected: Boolean = false,
    var isDestroyed: Boolean = false
)

data class TacticalProjectile(
    var active: Boolean = false,
    var x: Float = 0f,
    var y: Float = 0f,
    var startX: Float = 0f,
    var startY: Float = 0f,
    var targetX: Float = 0f,
    var targetY: Float = 0f,
    var vx: Float = 0f,
    var vy: Float = 0f,
    var distanceTraveled: Float = 0f,
    var maxDistance: Float = 0f,
    var damage: Float = 0f,
    var armorPen: Float = 0f,
    var splashRadius: Float = 0f,
    var faction: Faction = Faction.ALLIED,
    var isArtillery: Boolean = false
)

data class CombatParticle(
    var active: Boolean = false,
    var x: Float = 0f,
    var y: Float = 0f,
    var maxLife: Float = 0.4f,
    var life: Float = 0f,
    var radius: Float = 20f,
    var isHeavy: Boolean = false
)

data class MissionScenario(
    val id: String,
    val title: String,
    val briefing: String,
    val playerArmies: List<UnitClass>,
    val enemyArmies: List<UnitClass>,
    val objectiveDescription: String
)
