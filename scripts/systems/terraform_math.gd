class_name TerraformMath
extends RefCounted
## Pure mapping from terraform % to readouts and colours.


static func stage_name(def: TerraformDef, t: float) -> String:
	if t >= 100.0:
		return def.complete_name
	for i in def.stage_limits.size():
		if t < def.stage_limits[i]:
			return def.stage_names[i]
	return def.stage_names[def.stage_names.size() - 1]


static func pressure_kpa(def: TerraformDef, t: float) -> float:
	return def.pressure_base + def.pressure_gain * pow(t / 100.0, def.pressure_power)


static func temperature_c(def: TerraformDef, t: float) -> float:
	return def.temperature_base + def.temperature_gain * t / 100.0


## "0.6 kPa · −63 °C", formatted like the prototype.
static func atmosphere_text(def: TerraformDef, t: float) -> String:
	var kpa := pressure_kpa(def, t)
	var temp := roundi(temperature_c(def, t))
	var kpa_s := ("%.1f" % kpa) if kpa < 10.0 else str(roundi(kpa))
	return "%s kPa · %s%d °C" % [kpa_s, "−" if temp < 0 else "", absi(temp)]


static func sky_color(def: TerraformDef, planet: PlanetDef, t: float) -> Color:
	if t < def.sky_mid_at:
		return planet.sky_start.lerp(planet.sky_mid, t / def.sky_mid_at)
	return planet.sky_mid.lerp(planet.sky_end, (t - def.sky_mid_at) / (100.0 - def.sky_mid_at))


static func lake_scale(def: TerraformDef, t: float) -> float:
	return clampf((t - def.lake_start) / def.lake_span, 0.0, 1.0)
