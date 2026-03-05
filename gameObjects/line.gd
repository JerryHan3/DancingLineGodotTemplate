extends CharacterBody3D

@export var material: Material

@export var SPEED: float = 5.0
var move_direction: Vector2 = Vector2(0,0)
@onready var mesh: MeshInstance3D = $Mesh
@onready var music: AudioStreamPlayer = $Music 

@onready var camera: Camera3D = $CameraOrigin/Camera
@onready var camera_pos: Marker3D = $CameraOrigin/CameraPos
@onready var detector: Area3D = $Detector

var current_track: MeshInstance3D = null
var track_from_pos: Vector2 = Vector2(0,0)
var trail_group: Node3D = null

var last_frame_on_floor: bool = false
@onready var land_particle: GPUParticles3D = $LandParticle

var dead: bool = false
const DEATH_PARTICLE = preload("res://gameObjects/DeathParticle.tscn")
@onready var death_sound: AudioStreamPlayer = $Death
# Death sound from: https://pixabay.com/sound-effects/break-a-clay-pot-456377/

func _ready() -> void:
	#TODO: Set music clip on start
	if material != null:
		mesh.material_override = material
	trail_group = Node3D.new()
	trail_group.name = "TrailGroup"
	get_parent().add_child.call_deferred(trail_group)
	print(trail_group)

	detector.area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:

	# Restart hotkey
	if Input.is_action_just_pressed("replay"):
		get_tree().reload_current_scene()
		
	# Alive process
	if !dead:
		if not is_on_floor():
			velocity += get_gravity() * delta

		# Landing particle
		if !last_frame_on_floor and is_on_floor():
			new_track()
			land_particle.emitting = true
		last_frame_on_floor = is_on_floor()
		
		# Turn
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			if move_direction.length() == 0: # Start game
				move_direction.x = 1
				music.play()
			elif move_direction.x != 0:
				move_direction.x = 0
				move_direction.y = 1
			elif move_direction.y != 0:
				move_direction.x = 1
				move_direction.y = 0
			new_track()
		
		var direction := (transform.basis * Vector3(move_direction.x, 0, move_direction.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

		move_and_slide()
	
		# Extend current track
		if current_track != null:
			if is_on_floor():
				if move_direction.x != 0:
					current_track.mesh.size.x = global_position.x - track_from_pos.x
					current_track.position.x = current_track.mesh.size.x / 2 + track_from_pos.x - 0.5
					current_track.mesh.size.z = 1
				else:
					current_track.mesh.size.z = global_position.z - track_from_pos.y
					current_track.position.z = current_track.mesh.size.z / 2 + track_from_pos.y - 0.5
					current_track.mesh.size.x = 1
			else:
				current_track = null
	
		# Death trigger for Collider3D
		# DONE: Only trigger death when hitting tagged objects
		# if is_on_wall():
		# 	death()
		for i in range(get_slide_collision_count()):
			var collider = get_slide_collision(i).get_collider()
			if collider == null:
				continue
			elif collider.is_in_group("wall"):
				death()
	
	# TODO: Switch to Phantom Camera addon	
	camera.global_position = lerp(camera.global_position, camera_pos.global_position, 0.05)
	
func new_track() -> void:
	track_from_pos.x = global_position.x
	track_from_pos.y = global_position.z
	var track: MeshInstance3D = MeshInstance3D.new()
	var track_mesh: BoxMesh = BoxMesh.new()
	track_mesh.size.y = 1
	track_mesh.material = mesh.material_override
	track.mesh = track_mesh
	trail_group.add_child(track)
	current_track = track
	track.global_position = global_position

# Trigger handler
func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("wall"):
		death() # Area3D wall
	elif area.is_in_group("void"):
		death(true) # DONE: Void death trigger
	# TODO: Success trigger

func death(void_death: bool = false) -> void:
	dead = true
	music.stop()

	# These are for collision death
	if !void_death:
		move_direction = Vector2(0,0)
		death_sound.play(0.1)
		for i in 20:
			var death_particle_instance: RigidBody3D = DEATH_PARTICLE.instantiate()
			get_parent().add_child(death_particle_instance)
			death_particle_instance.mesh.material_override = mesh.material_override
			death_particle_instance.global_position = global_position
			death_particle_instance.apply_impulse(Vector3(rand_dir(),rand_dir(),rand_dir()))
			death_particle_instance.apply_torque(Vector3(rand_dir(),rand_dir(),rand_dir()))

func rand_dir() -> float:
	return randf_range(-SPEED,SPEED)
