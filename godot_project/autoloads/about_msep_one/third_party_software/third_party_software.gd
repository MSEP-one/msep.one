extends AboutMsepAttributionPage


const OTHERS_LICENSES: Dictionary = {
	"MIT" =
"""Copyright (c) <year> <copyright holders>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."""

}

func _ready() -> void:
	# Godot Engine
	var licences_texts: Dictionary = Engine.get_license_info()
	var conda_info := LicenseInfo.new(
			"Conda", "", "https://anaconda.org/",
			"BSD3", "Berkeley Software Distribution",
			licences_texts["BSD-3-clause"])
	_create_software_tree_item(conda_info)
	var openmm_info := LicenseInfo.new(
			"OpenMM", "8.0.0", "https://openmm.org/",
			"MIT", "Massachusetts Institute of Technology",
			_format_lisence(OTHERS_LICENSES["MIT"], "2017-2024", "OpenMM team"))
	var openff_info := LicenseInfo.new(
			"OpenFF", "openff-interchange 0.3.9; openff-toolkit 0.14.0", "https://openforcefield.org/",
			"MIT", "Massachusetts Institute of Technology",
			_format_lisence(OTHERS_LICENSES["MIT"], "2020", "Open Force Field Initiative"))
	_create_software_tree_item(openff_info)
	var rdkit_info := LicenseInfo.new(
			"RDKit", "2023.03.2", "https://www.rdkit.org/",
			"BSD3", "Berkeley Software Distribution",
			licences_texts["BSD-3-clause"])
	_create_software_tree_item(rdkit_info)
	var pyzmq_info := LicenseInfo.new(
			"pyzmq", "25.1.0", "https://zeromq.org/",
			"BSD3", "Berkeley Software Distribution",
			licences_texts["BSD-3-clause"])
	_create_software_tree_item(pyzmq_info)
	var zeromq_info := LicenseInfo.new(
			"zeromq", "4.3.5", "https://zeromq.org/",
			"MPL 2.0", "Mozilla Public License Version 2.0",
			licences_texts["BSD-3-clause"])
	_create_software_tree_item(zeromq_info)
	var godot_info := LicenseInfo.new(
			"Godot Engine", "4.2.3-(custom)", "https://godotengine.org/",
			"MIT", "Massachusetts Institute of Technology",
			Engine.get_license_text())
	_create_software_tree_item(godot_info)
	
