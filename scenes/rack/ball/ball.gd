extends Node3D
class_name Ball

## One ball on the pool table. The rack owns where it sits; this scene owns what it
## is: a unit sphere that the rack scales by the core radius, painted by its number.
## BCA paint: solids 1-7 one colour, stripes 9-15 a cream body with a coloured
## band, the 8 black, the cue cream.

@export var number: int = -1
@export var radius_m: float = 0.028575

const COLOURS := {
	0: Color("f2efe6"),
	1: Color("e8c112"), 2: Color("1648a8"), 3: Color("c33027"), 4: Color("5b2a86"),
	5: Color("e05f1e"), 6: Color("1d7a3c"), 7: Color("7e2024"), 8: Color("17171a"),
}

func _ready() -> void:
	_paint()

func place(position: Vector3, orientation: Vector3) -> void:
	# the carried orientation is an axis times an angle, exactly what Basis takes;
	# the uniform scale rides on the rotated basis, so a pose never shears the ball
	var pose := Transform3D()
	pose.origin = position
	if orientation != Vector3.ZERO:
		pose.basis = Basis(orientation.normalized(), orientation.length())
	pose.basis = pose.basis.scaled(Vector3(radius_m, radius_m, radius_m))
	transform = pose

func _paint() -> void:
	var stripe := number >= 9 and number <= 15
	$Stripe.visible = stripe
	if stripe:
		$Base.material_override = _material(COLOURS[0])
		$Stripe.material_override = _material(COLOURS[number - 8])
	else:
		$Base.material_override = _material(COLOURS.get(number, COLOURS[0]))

func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
