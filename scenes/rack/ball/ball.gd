extends Node3D
class_name Ball

## One ball on the pool table. The rack owns where it sits; this scene owns what it
## is: a unit UV sphere scaled by the core radius and painted with the BCA texture
## for its number. Solids, stripes, the 8 and the cue all come from Blender-made
## equirectangular maps, so the number travels with the core's carried rotation.

@export var number: int = -1
@export var radius_m: float = 0.028575
@export var ball_materials: Array[Material] = []

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
	var index: int = clampi(number, 0, 15)
	if index < ball_materials.size():
		$Base.material_override = ball_materials[index]
