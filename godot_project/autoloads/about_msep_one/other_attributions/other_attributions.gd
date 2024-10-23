extends AboutMsepAttributionPage


const LICENSES: Dictionary = {
	"SMALL_MOLECULES" =
"""Copyright 2006-2009 The Chemical Structures Project. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE CHEMICAL STRUCTURES PROJECT ``AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE CHEMICAL STRUCTURES PROJECT OR CONTRIBUTORS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""
}


func _ready() -> void:
	var small_molecules_info := LicenseInfo.new(
			"The Chemical Structures Project", "2.2.0", "https://chem-file.sourceforge.net/",
			"BSD", "Berkeley Software Distribution",
			LICENSES["SMALL_MOLECULES"])
	_create_software_tree_item(small_molecules_info)
	_create_custom_control_tree_item(tr("Audio Files"), preload("res://autoloads/about_msep_one/other_attributions/sfx_attribution_list.tscn"))
