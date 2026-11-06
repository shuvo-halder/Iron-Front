package com.example.game

enum class Faction {
    ALLIED,
    AXIS
}

enum class ArmorType {
    INFANTRY,
    VEHICLE,
    AIR
}

enum class DamageType {
    KINETIC,
    EXPLOSIVE,
    ARMOR_PIERCING
}

enum class ProjectileType {
    BULLET,
    ROCKET,
    TANK_SHELL
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
    val splashRadius: Float = 0f,
    val armorType: ArmorType = ArmorType.INFANTRY,
    val damageType: DamageType = DamageType.KINETIC,
    val projectileType: ProjectileType = ProjectileType.BULLET,
    val canTargetAir: Boolean = false,
    val cost: Int = 100
) {
    COMBAT_ENGINEER(
        displayName = "Combat Engineer",
        maxHp = 75f,
        armorFront = 4f,
        armorSide = 4f,
        armorRear = 4f,
        speed = 90f,
        attackRange = 160f,
        damage = 8f,
        armorPen = 6f,
        reloadTimeSec = 0.8f,
        radius = 12f,
        isHeavy = false,
        armorType = ArmorType.INFANTRY,
        damageType = DamageType.KINETIC,
        projectileType = ProjectileType.BULLET,
        canTargetAir = false
    ),
    INFANTRY(
        displayName = "Rifle Squad",
        maxHp = 90f,
        armorFront = 6f,
        armorSide = 6f,
        armorRear = 6f,
        speed = 95f,
        attackRange = 210f,
        damage = 14f,
        armorPen = 8f,
        reloadTimeSec = 0.65f,
        radius = 14f,
        isHeavy = false,
        armorType = ArmorType.INFANTRY,
        damageType = DamageType.KINETIC,
        projectileType = ProjectileType.BULLET,
        canTargetAir = false
    ),
    ROCKET_SOLDIER(
        displayName = "Anti-Tank Team (Rocket)",
        maxHp = 70f,
        armorFront = 6f,
        armorSide = 6f,
        armorRear = 6f,
        speed = 75f,
        attackRange = 280f,
        damage = 60f,
        armorPen = 65f,
        reloadTimeSec = 2.0f,
        radius = 15f,
        isHeavy = false,
        splashRadius = 45f,
        armorType = ArmorType.INFANTRY,
        damageType = DamageType.EXPLOSIVE,
        projectileType = ProjectileType.ROCKET,
        canTargetAir = true // Can hit Helicopter!
    ),
    SCOUT_CAR(
        displayName = "Scout Armored Car",
        maxHp = 150f,
        armorFront = 22f,
        armorSide = 14f,
        armorRear = 10f,
        speed = 150f,
        attackRange = 240f,
        damage = 20f,
        armorPen = 22f,
        reloadTimeSec = 0.95f,
        radius = 18f,
        isHeavy = false,
        armorType = ArmorType.VEHICLE,
        damageType = DamageType.KINETIC,
        projectileType = ProjectileType.BULLET,
        canTargetAir = false
    ),
    MEDIUM_TANK(
        displayName = "M4 Cruiser Medium Tank",
        maxHp = 240f,
        armorFront = 55f,
        armorSide = 32f,
        armorRear = 18f,
        speed = 105f,
        attackRange = 290f,
        damage = 45f,
        armorPen = 48f,
        reloadTimeSec = 1.6f,
        radius = 22f,
        isHeavy = true,
        splashRadius = 25f,
        armorType = ArmorType.VEHICLE,
        damageType = DamageType.ARMOR_PIERCING,
        projectileType = ProjectileType.TANK_SHELL,
        canTargetAir = false
    ),
    HEAVY_TANK(
        displayName = "Tiger Heavy Vanguard",
        maxHp = 420f,
        armorFront = 95f,
        armorSide = 60f,
        armorRear = 32f,
        speed = 65f,
        attackRange = 340f,
        damage = 95f,
        armorPen = 85f,
        reloadTimeSec = 2.6f,
        radius = 26f,
        isHeavy = true,
        splashRadius = 35f,
        armorType = ArmorType.VEHICLE,
        damageType = DamageType.ARMOR_PIERCING,
        projectileType = ProjectileType.TANK_SHELL,
        canTargetAir = false
    ),
    ATTACK_HELICOPTER(
        displayName = "Attack Helicopter",
        maxHp = 120f,
        armorFront = 12f,
        armorSide = 10f,
        armorRear = 8f,
        speed = 190f,
        attackRange = 280f,
        damage = 45f,
        armorPen = 35f,
        reloadTimeSec = 1.4f,
        radius = 24f,
        isHeavy = true,
        splashRadius = 45f,
        armorType = ArmorType.AIR,
        damageType = DamageType.EXPLOSIVE,
        projectileType = ProjectileType.ROCKET,
        canTargetAir = false
    ),
    DEFENSE_TURRET(
        displayName = "Anti-Air Defense Turret",
        maxHp = 300f,
        armorFront = 40f,
        armorSide = 40f,
        armorRear = 20f,
        speed = 0f,
        attackRange = 320f,
        damage = 50f,
        armorPen = 40f,
        reloadTimeSec = 1.2f,
        radius = 22f,
        isHeavy = true,
        splashRadius = 30f,
        armorType = ArmorType.VEHICLE,
        damageType = DamageType.EXPLOSIVE,
        projectileType = ProjectileType.ROCKET,
        canTargetAir = true
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
        splashRadius = 55f,
        armorType = ArmorType.VEHICLE,
        damageType = DamageType.EXPLOSIVE,
        projectileType = ProjectileType.TANK_SHELL,
        canTargetAir = false
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
    var projectileType: ProjectileType = ProjectileType.BULLET,
    var damageType: DamageType = DamageType.KINETIC,
    var isArtillery: Boolean = false
)

enum class ParticleKind {
    EXPLOSION,
    MUZZLE_FLASH,
    HIT_SPARK,
    DEATH_WRECKAGE
}

data class CombatParticle(
    var active: Boolean = false,
    var x: Float = 0f,
    var y: Float = 0f,
    var dirX: Float = 1f,
    var dirY: Float = 0f,
    var maxLife: Float = 0.4f,
    var life: Float = 0f,
    var radius: Float = 20f,
    var kind: ParticleKind = ParticleKind.EXPLOSION,
    var isHeavy: Boolean = false
)

enum class BuildingClass(
    val displayName: String,
    val maxHp: Float,
    val cost: Int,
    val buildTimeSec: Float,
    val radius: Float,
    val passiveSupplyRate: Float = 0f,
    val producibleUnits: List<UnitClass> = emptyList(),
    val isTurret: Boolean = false,
    val turretRange: Float = 0f,
    val turretDamage: Float = 0f
) {
    HQ(
        displayName = "Headquarters",
        maxHp = 1200f,
        cost = 450,
        buildTimeSec = 10f,
        radius = 45f,
        passiveSupplyRate = 10f,
        producibleUnits = listOf(UnitClass.COMBAT_ENGINEER)
    ),
    BARRACKS(
        displayName = "Barracks",
        maxHp = 650f,
        cost = 150,
        buildTimeSec = 6f,
        radius = 36f,
        producibleUnits = listOf(UnitClass.INFANTRY, UnitClass.ROCKET_SOLDIER)
    ),
    FACTORY(
        displayName = "Armor Factory",
        maxHp = 850f,
        cost = 280,
        buildTimeSec = 8f,
        radius = 42f,
        producibleUnits = listOf(UnitClass.SCOUT_CAR, UnitClass.MEDIUM_TANK, UnitClass.HEAVY_TANK, UnitClass.ATTACK_HELICOPTER)
    ),
    TURRET(
        displayName = "Defense Turret",
        maxHp = 500f,
        cost = 120,
        buildTimeSec = 4f,
        radius = 26f,
        isTurret = true,
        turretRange = 300f,
        turretDamage = 45f
    )
}

data class TacticalBuilding(
    val id: Int,
    val buildingClass: BuildingClass,
    val faction: Faction,
    var x: Float,
    var y: Float,
    var hp: Float = buildingClass.maxHp,
    var isUnderConstruction: Boolean = false,
    var buildTimer: Float = 0f,
    var rallyX: Float = x,
    var rallyY: Float = y + buildingClass.radius + 40f,
    val queue: MutableList<UnitClass> = mutableListOf(),
    var productionTimer: Float = 0f,
    var productionTotalTime: Float = 0f,
    var turretAngleRad: Float = 0f,
    var reloadTimer: Float = 0f,
    var isSelected: Boolean = false,
    var isDestroyed: Boolean = false
)

data class TacticalSupplyCrate(
    val id: Int,
    var x: Float,
    var y: Float,
    val value: Float = 75f,
    var collected: Boolean = false
)

enum class ObjectiveType(val label: String) {
    DESTROY_HQ("Destroy Axis HQ"),
    SURVIVE_TIME("Survive Onslaught"),
    DEFEND_BUILDING("Defend Allied HQ"),
    ELIMINATE_ALL("Eliminate All Hostiles")
}

data class MissionScenario(
    val id: String,
    val missionIndex: Int = 1,
    val title: String,
    val briefing: String,
    val objectiveType: ObjectiveType = ObjectiveType.DESTROY_HQ,
    val objectiveDescription: String,
    val surviveDurationSec: Float = 150f,
    val parTimeSec: Float = 180f,
    val maxCasualties3Star: Int = 4,
    val rewardMoney: Int = 150,
    val startingSupply: Float = 450f,
    val aiDifficulty: AiDifficulty = AiDifficulty.MEDIUM,
    val playerArmies: List<UnitClass>,
    val enemyArmies: List<UnitClass>
)

enum class AiDifficulty(
    val displayName: String,
    val incomeMult: Float,
    val waveIntervalSec: Float,
    val minWaveSize: Int,
    val retreatThreshold: Float
) {
    EASY("Easy", 0.75f, 45f, 3, 0.20f),
    MEDIUM("Medium", 1.0f, 30f, 5, 0.35f),
    HARD("Hard", 1.35f, 20f, 7, 0.45f)
}

enum class EnemyAiState(val label: String) {
    GATHERING("GATHERING"),
    ATTACKING("ATTACKING"),
    RETREATING("RETREATING"),
    DEFENDING("DEFENDING")
}


