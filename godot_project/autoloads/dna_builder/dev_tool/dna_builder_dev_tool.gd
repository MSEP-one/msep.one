extends Control

@onready var _template_filename: OptionButton = %TemplateFilename
@onready var _flip_x: Button = %FlipX
@onready var _flip_y: Button = %FlipY
@onready var _flip_z: Button = %FlipZ
@onready var _dump_template_button: Button = %DumpTemplateButton

func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled.unbind(2))
	_on_feature_flag_toggled()
	_dump_template_button.pressed.connect(_on_dump_template_button_pressed)


func _on_feature_flag_toggled() -> void:
	# Set wether to show the development tools for building templates or not
	visible = OS.is_debug_build() and DnaBuilder.is_dev_tool_enabled()


func _on_dump_template_button_pressed() -> void:
	var filename: String = _template_filename.text
	if filename.is_empty():
		_template_filename.grab_focus()
		DisplayServer.dialog_show("Failed", "Select the filename you are dumping to", ["OK"], Callable())
		return
	var flip := Vector3(
		-1 if _flip_x.button_pressed else 1,
		-1 if _flip_y.button_pressed else 1,
		-1 if _flip_z.button_pressed else 1)
	_dump_file("res://autoloads/dna_builder/templates/%s.tres" % filename, flip, false)
	_dump_file("res://autoloads/dna_builder/templates/%s_h.tres" % filename, flip, true)
	DisplayServer.dialog_show("Success", "File dumped successfully", ["OK"], Callable())
	


func _dump_file(in_full_path: String, in_flip: Vector3, in_include_hydrogens: bool) -> void:
	_template_filename.select(-1)
	var w: Workspace = MolecularEditorContext.get_current_workspace()
	var s: AtomicStructure = w.get_main_structure()
	var atoms: PackedVector4Array = []
	var bonds: Array[Vector3i] = []
	var atom_remap: Dictionary[int, int] = {}
	var i: int = 0
	for atom_id in s.get_valid_atoms():
		var n: int = s.atom_get_atomic_number(atom_id)
		if not in_include_hydrogens and n == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
			continue
		var p: Vector3 = s.atom_get_position(atom_id)
		p *= in_flip
		atoms.append(Vector4(p.x, p.y, p.z, n))
		atom_remap[atom_id] = i
		i += 1
	for bond_id in s.get_valid_bonds():
		var bond: Vector3i = s.get_bond(bond_id)
		if bond.x in atom_remap and bond.y in atom_remap:
			# Didn't skip an hydrogen
			var a: int = atom_remap[bond.x]
			var b: int = atom_remap[bond.y]
			bonds.append(Vector3i(a, b, bond.z))
	var new: DnaBuilder.PackedMolecule = DnaBuilder.PackedMolecule.new()
	new.atoms = atoms
	new.bonds = bonds
	if ResourceLoader.exists(in_full_path):
		# Transfer manual configuration between files
		var old: DnaBuilder.PackedMolecule = load(in_full_path)
		new.previous_backbone_atom_id = old.previous_backbone_atom_id
		new.next_backbone_atom_id = old.next_backbone_atom_id
		new.base_to_backbone_atom_id = old.base_to_backbone_atom_id
	ResourceSaver.save(new, in_full_path)
