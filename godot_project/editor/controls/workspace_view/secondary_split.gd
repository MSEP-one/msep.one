extends HSplitContainer

## Makes the Docker view always takes as little horizontal space as possible when
## the docker UI is updated or if user has manually set the width of a panel per
## tab restore that.


func _ready() -> void:
	# Just force the initial tab width to be minimal.
	split_offset = 1000000


func adjust_split(in_split: int) -> void:
	split_offset = in_split
