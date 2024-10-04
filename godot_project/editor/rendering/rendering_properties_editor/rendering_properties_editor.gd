class_name RenderingPropertiesEditor extends MarginContainer
# Small tool that allows to quickly iterate on atom visual properties

@onready var _selected_atom_label: Label = $VBoxContainer/SelectedAtom
@onready var _base_color: ColorChooser = $VBoxContainer/BaseColor
@onready var _noise_color: ColorChooser = $"VBoxContainer/Noise Color"
@onready var _bond_color: ColorChooser = $"VBoxContainer/BondColor"
@onready var _noise_atlas_id: OptionButton = $VBoxContainer/NoiseAtlasID/AtlasNoiseOption

var _current_structure_context: StructureContext


func _ready() -> void:
	MolecularEditorContext.workspace_activated.connect(_on_molecular_editor_context_workspace_activated)
	if is_instance_valid(MolecularEditorContext.get_current_workspace()):
		_init_workspace(MolecularEditorContext.get_current_workspace())
	hide()
	

func _on_structure_context_selection_changed() -> void:
	var element_data: ElementData = _get_selected_element_data()
	if element_data == null:
		hide()
		return
	show()
	_selected_atom_label.text = element_data.name
	_base_color.set_color(element_data.color)
	_noise_color.set_color(element_data.noise_color)
	_bond_color.set_color(element_data.bond_color)
	_noise_atlas_id.selected = int(element_data.noise_atlas_id)


func _on_molecular_editor_context_workspace_activated(in_activated_workspace: Workspace) -> void:
	_init_workspace(in_activated_workspace)


func _init_workspace(in_workspace: Workspace) -> void:
	if is_instance_valid(_current_structure_context):
		_current_structure_context.atom_selection_changed.disconnect(_on_structure_context_selection_changed)
	
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_workspace)
	_current_structure_context = workspace_context.get_current_structure_context()
	_current_structure_context.atom_selection_changed.connect(_on_structure_context_selection_changed)


func _on_base_color_color_picked(in_color: Color) -> void:
	var selected_element_data: ElementData = _get_selected_element_data()
	if selected_element_data == null:
		return
	selected_element_data.color = in_color
	var rendering: Rendering = _current_structure_context.workspace_context.get_rendering()
	rendering.__debug_rebuild_nano_structure(_current_structure_context.nano_structure)


func _on_noise_color_color_picked(in_color: Color) -> void:
	var selected_element_data: ElementData = _get_selected_element_data()
	selected_element_data.noise_color = in_color
	var rendering: Rendering = _current_structure_context.workspace_context.get_rendering()
	rendering.__debug_rebuild_nano_structure(_current_structure_context.nano_structure)


func _on_atlas_noise_option_item_selected(index: int) -> void:
	var selected_element_data: ElementData = _get_selected_element_data()
	if selected_element_data == null:
		return
	selected_element_data.noise_atlas_id = index
	var rendering: Rendering = _current_structure_context.workspace_context.get_rendering()
	rendering.__debug_rebuild_nano_structure(_current_structure_context.nano_structure)


func _on_color_factor_value_value_changed(in_value: float) -> void:
	var selected_element_data: ElementData = _get_selected_element_data()
	if selected_element_data == null:
		return
	selected_element_data.bond_color_strength = in_value
	var rendering: Rendering = _current_structure_context.workspace_context.get_rendering()
	rendering.__debug_rebuild_nano_structure(_current_structure_context.nano_structure)


func _get_selected_element_data() -> ElementData:
	var selected_atoms: PackedInt32Array = _current_structure_context.get_selected_atoms()
	if selected_atoms.size() != 1:
		return null
	var selected_atom: int = selected_atoms[0]
	var atomic_nmb: int = _current_structure_context.nano_structure.atom_get_atomic_number(selected_atom)
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_nmb)
	return element_data


func _on_bond_color_color_picked(in_color: Color) -> void:
	var selected_element_data: ElementData = _get_selected_element_data()
	selected_element_data.bond_color = in_color
	var rendering: Rendering = _current_structure_context.workspace_context.get_rendering()
	rendering.__debug_rebuild_nano_structure(_current_structure_context.nano_structure)
