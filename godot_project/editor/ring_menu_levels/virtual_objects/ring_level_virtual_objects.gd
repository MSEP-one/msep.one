class_name RingLevelVirtualObjects extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Virtual Objects"),
		tr("Manage virtual objects.")
	)
	
	add_action(preload("ring_action_groups.gd").new(in_workspace_context, in_menu))
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_VIRTUAL_MOTORS):
		add_action(RingActionCreateMotor.new(in_workspace_context, in_menu, NanoVirtualMotorParameters.Type.ROTARY))
		add_action(RingActionCreateMotor.new(in_workspace_context, in_menu, NanoVirtualMotorParameters.Type.LINEAR))
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_VIRTUAL_SPRINGS):
		add_action(RingActionCreateAnchorsAndSprings.new(in_workspace_context, in_menu))
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_PARTICLE_EMITTERS):
		add_action(RingActionCreateParticleEmitters.new(in_workspace_context, in_menu))
