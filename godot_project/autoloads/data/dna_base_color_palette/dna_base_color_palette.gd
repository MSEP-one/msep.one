class_name DnaBaseColorPalette

enum Schema {
	STANDARD = 0,
	BIOMODEL_DRUMS = 1,
	RCSB_PDB = 2,
	STANDARD_BASE_PAIR = 3,
	PURINE_PYRIMIDINE_BASE_PAIR = 4,
	CUSTOM = 5
}

const DEFAULT_A_STRAND_COLOR := Color.RED
const DEFAULT_B_STRAND_COLOR := Color.BLUE
const DEFAULT_MAJOR_GROOVE := Color8(213,   6, 114)
const DEFAULT_MINOR_GROOVE := Color8( 17, 125, 226)
static func get_schema_colors(in_schema: Schema) -> Dictionary:
	return _SCHEMA_TO_COLORS[in_schema].duplicate()


const _SCHEMA_TO_COLORS: Dictionary[Schema, Dictionary] = {
	Schema.STANDARD : {
		&"A": Color.GREEN,
		&"T": Color.RED,
		&"C": Color.BLUE,
		&"G": Color.ORANGE,
	},
	Schema.BIOMODEL_DRUMS : {
		&"A": Color8( 80,  80, 255),
		&"T": Color8(230, 230,   0),
		&"C": Color8(224,   0,   0),
		&"G": Color8(  0, 192,   0),
	},
	Schema.RCSB_PDB : {
		&"A": Color.MAGENTA,
		&"T": Color.ORANGE,
		&"C": Color.RED,
		&"G": Color.GREEN,
	},
	Schema.STANDARD_BASE_PAIR : {
		&"A": Color8(  0, 147, 255),
		&"T": Color8(  0, 147, 255),
		&"C": Color8(253,   1,   1),
		&"G": Color8(253,   1,   1),
	},
	Schema.PURINE_PYRIMIDINE_BASE_PAIR : {
		&"A": Color8(255,   5, 255),
		&"T": Color8( 51,  38, 255),
		&"C": Color8( 51,  38, 255),
		&"G": Color8(255,   5, 255),
	},
}


