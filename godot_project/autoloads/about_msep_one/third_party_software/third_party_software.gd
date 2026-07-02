extends AboutMsepAttributionPage


const OTHERS_LICENSES: Dictionary = {
	"MIT" =
"""Copyright (c) <year> <copyright holders>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.""",
	
	"TUBEGEN_BSD" =
"""Copyright © 2001-2003, Doren Research Group*, University of Delaware
All rights reserved.

· Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

· Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

· Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

Neither the names of the Doren Research Group* or the University of Delaware nor the names of the contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

TubeGen 3.2, J. T. Frey and D. J. Doren, University of Delaware, Newark DE, 2003."""

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
	_create_software_tree_item(openmm_info)
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
	
	var tubegen_info := LicenseInfo.new(
			"TubeGen - SWCNT Structure Generator", "3.1",
			"https://github.com/cryos/avogadro/blob/1.2/libavogadro/src/extensions/swcntbuilder/tubegen/TubeGen.cpp",
			"BSD", "Berkeley Software Distribution",
			OTHERS_LICENSES["TUBEGEN_BSD"]
	)		
	_create_software_tree_item(tubegen_info)
	
	var godot_info := LicenseInfo.new(
			"Godot Engine", Engine.get_version_info().string, "https://godotengine.org/",
			"MIT", "Massachusetts Institute of Technology",
			Engine.get_license_text())
	_create_software_tree_item(godot_info)
	
