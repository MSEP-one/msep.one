## 
## This tool script helps find atom positions for a given
## carbon nanotube parameters
## 
## Based on:
##	https://github.com/cryos/avogadro/blob/1.2/libavogadro/src/extensions/swcntbuilder/tubegen/TubuleBasis.cpp
##	https://github.com/cryos/avogadro/blob/1.2/libavogadro/src/extensions/swcntbuilder/tubegen/CrystalCell.cpp
##	https://github.com/cryos/avogadro/blob/1.2/libavogadro/src/extensions/swcntbuilder/tubegen/Cell.cpp
# Copyright © 2001-2003, Doren Research Group*, University of Delaware
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Neither the names of the Doren Research Group* or the University
# of Delaware nor the names of the contributors may be used to endorse
# or promote products derived from this software without specific prior
# written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
## Additional code:
##	Bond generation
class_name CarbonTubuleBasis
extends RefCounted

const STD_BOND_LENGTH = 0.1421
const STD_GUTTER_LENGTH = 1.6735

var n: int = 3
var m: int = 3
var bond_length: float = STD_BOND_LENGTH
var bond_scale: float = 1.0

var _element: PackedInt32Array = [6, 6]
var _replicate: Vector3i
var _a1: Vector3
var _a2: Vector3
var _gutter: Vector3
var _Ch: Vector3; var _Ch_r: Vector3
var _T: Vector3; var _T_r: Vector3
var _Tprime: Vector3
var _nprime: int; var _mprime: int; var _d: int; var _dR: int
var _T_len:float; var _Ch_len: float; var _r: float; var _h: float


func _init(index_n: int = 3, index_m: int = 3) -> void:
	setup(index_n, index_m)


func setup(index_n: int = 3, index_m: int = 3) -> void:
	n = index_n
	m = index_m
	bond_length = STD_BOND_LENGTH
	bond_scale = 1.0
	_calculate_graphitic_basis_vectors()
	_calculate_translational_indices()
	_gutter = Vector3(STD_GUTTER_LENGTH, STD_GUTTER_LENGTH, 0)
	_replicate = Vector3i.ONE

func get_translational_vector_length() -> float:
	return _T_len

func get_estimated_circumference() -> float:
	return _Ch_len

func get_estimated_diameter() -> float:
	return _Ch_len / PI

func generate() -> CrystalCell:
	const FLT_EPSILON = 1e-10
	var a: float; var b: float; var c: float
	var len_v: float
	var i_min: int; var i_max: int
	var j_min: int; var j_max: int
	var v: Vector3
	var center: Vector3
	var p := Vector3()
	
	a = 2.0 * (_r + _gutter.x);
	b = 2.0 * (_r + _gutter.y);
	c = _T_len + 2.0 * _gutter.z;
	var cell := CrystalCell.new(a,b,c,90.0,90.0,120.0)
	center = cell.get_real_basis_vector1()
	center *= 0.5
	v = cell.get_real_basis_vector2()
	center += v * 0.5
	
	# Begin generating coordinates:
	i_min = min(_nprime, 0)
	i_min = min(i_min, n)
	i_max = max((n + _nprime), n)
	i_max = max(i_max, _nprime)
	
	j_min = min(-_mprime, 0)
	j_min = min(j_min, m)
	j_max = max((m - _mprime), m)
	j_max = max(j_max, -_mprime)
	
	for i: float in range(i_min, i_max + 1):
		for j: float in range(j_min, j_max + 1):
			# And finally, we loop over the two atoms in the
			# hexagonal graphite basis, giving us
			# i(a1) + j(a2)   and   i(a1) + j(a2) + <C-C,0,0>
			for k: int in 2:
		
				# Construct i(a1) + j(a2):
				v.x = i * _a1.x + j * _a2.x;
				v.y = i * _a1.y + j * _a2.y;
				v.z = 0.0;
				
				# Second time through we add a C-C bond displacement:
				if (k == 1):
					v.x += bond_length * bond_scale
				v = CarbonTubuleBasis._rezero(v, FLT_EPSILON)
				
				len_v = v.length()
				
				# Check v; if it's a zero vector that's really easy; otherwise
				# we need to project onto Ch and T to get fractional coordinates
				# along those axes.
				p.y = 0.5;
				if len_v < FLT_EPSILON:
					p.x = 0.0; p.z = 0.0
				else:
					p.x = v.dot(_Ch_r); #/ (lenCh * lenCh);
					p.z = v.dot(_T_r); #/ (lenT * lenT);
					if (abs(p.x) < FLT_EPSILON): p.x = 0.0;
					if (abs(p.z) < FLT_EPSILON): p.z = 0.0;
				# If point "p" is within [0,1) in x and z, we have a point:
				if ((p.x < 1.0) and (p.x >= 0.0) and (p.z < 1.0) and (p.z >= 0.0)):
					# Check if we're too close to 1.0:
					if ((1.0 - p.x > FLT_EPSILON) and (1.0 - p.z > FLT_EPSILON)):
					# Recalculate in terms of Ch and Tprime:
						p.x = v.dot(_Ch) / (_Ch_len * _Ch_len);
						p.z = v.dot(_Tprime) / (_h * _h);
					# This is the rolled- vs. flat-specific stuff:
					
					# theta = 2(pi) times displacement along chiral vector:
					var theta: float = 2 * PI * p.x;
					
					# Redefine the point as a polar coordinate in xy-plane:
					p.x = _r * cos(theta) + center.x;
					p.y = _r * sin(theta) + center.y;
					p.z *= _h;
					cell.did_add_atom_at_cartesian_point(_element[k],p);
	
	## Generate bond templates
	var bond_len_sqrd: float = (bond_length * bond_scale) ** 2
	for atom_a: int in cell.basis.size():
		for atom_b: int in cell.basis.size():
			var pos_a: Vector3 = cell.fractional_to_cartesian_position(cell.basis[atom_a].position)
			var pos_b: Vector3 = cell.fractional_to_cartesian_position(cell.basis[atom_b].position)
			# Non glue bonds
			const BOND_LEN_THRESSHOLD = 0.003
			if atom_b > atom_a: # This cheaper check avoids registering twice the same bond
				if abs(pos_a.distance_squared_to(pos_b) - bond_len_sqrd) < BOND_LEN_THRESSHOLD:
					cell.did_add_bond(atom_a, atom_b, false)
			# Glue bonds
			pos_b.z -= get_translational_vector_length()
			if abs(pos_a.distance_squared_to(pos_b) - bond_len_sqrd) < BOND_LEN_THRESSHOLD:
				cell.did_add_bond(atom_a, atom_b, true)
	return cell

func _calculate_graphitic_basis_vectors() -> void:
	var v: Vector2
	v.x = 1.5 * bond_length
	v.y = 0.5 * sqrt(3.0) * bond_length
	_a1 = Vector3(v.x, +v.y, 0.0)
	_a2 = Vector3(v.x, -v.y, 0.0)


func _calculate_translational_indices() -> void:
	_d = _get_greatest_common_divisor(n, m)
	if (((n - m) % (3 * _d)) == 0):
		_dR = 3 * _d
	else:
		_dR = _d
	
	#  Calculate nprime and mprime:
	_nprime = int((2.0 * m + n) / _dR)
	_mprime = int((2.0 * n + m) / _dR)
	
	_calculate_tubule_cell_vectors()


func _calculate_tubule_cell_vectors() -> void:
	_Ch = CarbonTubuleBasis._rezero(n * _a1 + _a2 * m)
	_T = CarbonTubuleBasis._rezero(_a1 * _nprime - _a2 * _mprime)
	_Ch_len = _Ch.length()
	_T_len = _T.length()
	_r = 0.5 * (1.0 / PI) * _Ch_len
	
	var one_over_v: float = _T.dot(_Ch) / (_Ch_len * _T_len)
	_Tprime = CarbonTubuleBasis._rezero(_T - one_over_v * _Ch)
	_h = _Tprime.length()
	
	one_over_v = 1.0 / ( _T.y * _Ch.x - _T.x * _Ch.y );  #  1 / V
	_Ch_r = Vector3(one_over_v * _T.y,-one_over_v * _T.x,0.0)
	_T_r = Vector3(-one_over_v * _Ch.y,one_over_v * _Ch.x,0.0)


func  _get_greatest_common_divisor(i: int, j: int) -> int:
	var max_d: int = max(i, j)
	var min_d: int = min(i, j)
	if (min_d == 0):
		return max_d
	
	var r: int = max_d % min_d
	while r != 0:
		max_d = min_d
		min_d = r
		r = max_d % min_d
	
	return min_d


static func _rezero(v: Vector3, epsilon: float = 1e-10) -> Vector3:
	for c in 3:
		if abs(v[c]) < epsilon:
			v[c] = 0
	return v

class AtomCoordinate:
	var element: int = 0
	var position := Vector3.ZERO
	
	func _init(in_element: int, in_position: Vector3) -> void:
		element = in_element
		position = in_position

class Bond:
	var from_coordinate: int
	var to_coordinate: int
	var is_glue: bool
	func _init(in_from_coordinate: int, in_to_coordinate: int, in_is_glue: bool) -> void:
		from_coordinate = in_from_coordinate
		to_coordinate = in_to_coordinate
		is_glue = in_is_glue
	func to_vec3i() -> Vector3i:
		return Vector3i(from_coordinate, to_coordinate, int(is_glue))


class CrystalCell:
	var a: float
	var b: float
	var c: float
	var alpha: float
	var beta: float
	var gamma: float
	
	var av: PackedVector3Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var bv: PackedVector3Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var volume: float
	var xy_center: Vector3
	
	var metric_tensor: PackedFloat64Array = [0, 0, 0, 0, 0, 0]
	
	var basis: Array[AtomCoordinate]
	var bonds: Array[Bond]
	var _registered_bonds: PackedVector3Array
	
	func _init(
		in_a: float, in_b: float, in_c: float,
		in_alpha: float, in_beta: float, in_gamma: float
	) -> void:
		a = in_a if in_a > 0.0 else 4.0
		b = in_b if in_b > 0.0 else 4.0
		c = in_c if in_c > 0.0 else 4.0
		alpha = in_alpha if (in_alpha > 0.0 and in_alpha < 180.0) else 90.0
		beta =  in_beta  if (in_beta  > 0.0 and in_beta  < 180.0) else 90.0
		gamma = in_gamma if (in_gamma > 0.0 and in_gamma < 180.0) else 90.0
		
		_generate_cell_vectors()
		
		basis = []
	
	func _to_string() -> String:
		var s := String()
		s = "CrystalCell { basisSize=%s\n" % basis.size();
		for coord: AtomCoordinate in basis:
			s += "\t%2d  %s\n" % [coord.element, str(coord.position)]
		s += "}\n";
		return s
	
	func get_real_basis_vector1() -> Vector3:
		return av[0]
	func get_real_basis_vector2() -> Vector3:
		return av[1]
	func get_real_basis_vector3() -> Vector3:
		return av[2]
	func get_reciprocal_basis_vector1() -> Vector3:
		return bv[0]
	func get_reciprocal_basis_vector2() -> Vector3:
		return bv[1]
	func get_reciprocal_basis_vector3() -> Vector3:
		return bv[2]
	func fractional_to_cartesian_position(in_fractional: Vector3) -> Vector3:
		var cartesian: Vector3 = (
			av[0] * in_fractional.x +
			av[1] * in_fractional.y +
			av[2] * in_fractional.z
		)
		return cartesian
	
	func did_add_atom_at_cartesian_point(in_element: int, in_cartesian: Vector3) -> int:
		return did_add_atom_at_fractional_point(in_element,_cartesian_to_fractional(in_cartesian))
	
	func did_add_atom_at_fractional_point(in_element: int, in_fractional: Vector3) -> int:
	# Remove any integer portion of the coordinates so that
	# they're truly fractional; if we're close enough to zero
	# then just go with zero, too:
		var pt := in_fractional
		var trunc: Callable = func (x: float) -> float:
			return ceil(x) if x < 0 else floor(x)
		pt.x -= trunc.call(pt.x)
		pt.y -= trunc.call(pt.y)
		pt.z -= trunc.call(pt.z)
		if (abs(pt.x) < 1e-4):
			pt.x = 0.0;
		elif (pt.x < 0.0):
			pt.x += 1.0;
			
		if (abs(pt.y) < 1e-4):
			pt.y = 0.0;
		elif (pt.y < 0.0):
			pt.y += 1.0;
			
		if (abs(pt.z) < 1e-4):
			pt.z = 0.0;
		elif (pt.z < 0.0):
			pt.z += 1.0;
			
		# Check to see if anything else is there:
		if _position_is_unoccupied(pt):
			# If the number of basis atoms matches the size of the array
			# we need to increase the size of our array of basis atoms:
			basis.push_back(AtomCoordinate.new(in_element, pt))
			return 1
		return 0
	
	## Register a bond between atoms, if is_glue is true, means "to_basis" corresponds to
	## an atom of the previous repeated array
	func did_add_bond(from_basis: int, to_basis: int, is_glue: bool) -> int:
		if from_basis < 0 or from_basis >= basis.size():
			return 0
		var bond := Bond.new(from_basis, to_basis, is_glue)
		if _registered_bonds.has(bond.to_vec3i()):
			return 0
		bonds.append(bond)
		_registered_bonds.append(bond.to_vec3i())
		return 1
	
	func _cartesian_to_fractional(in_cartesian: Vector3) -> Vector3:
		var p_f := Vector3.ZERO
		
		p_f.x = in_cartesian.dot(bv[0])
		p_f.y = in_cartesian.dot(bv[1])
		p_f.z = in_cartesian.dot(bv[2])
		
		p_f = CarbonTubuleBasis._rezero(p_f,1e-10)
		
		return p_f;
	
	func _position_is_unoccupied(pos: Vector3, search_radius: float = 1e-2) -> bool:
		for coord: AtomCoordinate in basis:
			if coord.position.distance_squared_to(pos) <= (search_radius**2):
				return false
		return true
	
	func _generate_cell_vectors() -> void:
		# The a axis is easy; project the "a" dimension
		# along the x-axis:
		av[0].x = a; av[0].y = 0.0; av[0].z = 0.0
		
		# The b axis is fairly easy, too; we keep it in
		# the xy-plane and simply rotate through gamma
		# degrees:
		var gammaRad: float = deg_to_rad(gamma)
		var cosGamma: float = cos(gammaRad)
		var sinGamma: float = sin(gammaRad)
		av[1].x = b * cosGamma; av[1].y = b * sinGamma; av[1].z = 0.0
		
		# Check for underflows:
		av[1] = CarbonTubuleBasis._rezero(av[1],1e-10)
		
		# The c axis is the toughy.  We need to rotate
		# relative to the two previously-defined vectors:
		var alphaRad: float = deg_to_rad(alpha)
		var betaRad: float = deg_to_rad(beta)
		var cosAlpha: float = cos(alphaRad)
		var cosBeta: float = cos(betaRad)
		var sinBeta: float = sin(betaRad)
		var sinPhi: float
		# (1) Rotate away from a1 (on the x-axis) by beta:
		av[2].x = c * cosBeta
		av[2].y = 0.0
		av[2].z = c * sinBeta
		# (2) Do a constrained rotation around the x-axis such that
		#     the angle between a3 and a2 becomes alpha:
		#
		#       c = [[|c| cos(beta)][0][|c| sin(beta)]]
		#				a3 = [[1 0 0][0 cos(phi) -sin(phi)][0 sin(phi) cos(phi)]].c = Phi.c
		#       a2(t).Phi.c = |b||c| cos(alpha)
		#
		#     Given the construction of a1 and a2 thus far, the equation
		#     is soluble and we find the angle phi and can perform the
		#     rotation in question.
		sinPhi = (cosGamma * cosBeta - cosAlpha) / (sinGamma * sinBeta)
		av[2].y = av[2].z * -sinPhi
		av[2].z = av[2].z * sqrt( 1.0 - sinPhi * sinPhi )
		
		# Check for underflows:
		av[2] = CarbonTubuleBasis._rezero(av[2],1e-10)
		
		# That gives us the real-space basis; construct the reciprocal
		# space basis:
		bv[0] = av[1].cross(av[2])
		bv[1] = av[2].cross(av[0])
		bv[2] = av[0].cross(av[1])
		# Each must be divided by the volume, too:
		volume = av[0].dot(bv[0])
		
		var recipVol: float = 1.0 / volume
		
		bv[0] *= recipVol
		bv[1] *= recipVol
		bv[2] *= recipVol
		
		# Check for underflows:
		bv[0] = CarbonTubuleBasis._rezero(bv[0],1e-10)
		bv[1] = CarbonTubuleBasis._rezero(bv[1],1e-10)
		bv[2] = CarbonTubuleBasis._rezero(bv[2],1e-10)
		
		# Create our metric:
		var idx: int = 0
		for i: int in 3:
			for j: int in i+1:
				metric_tensor[idx] = av[i].dot(av[j])
				idx += 1
		
		xy_center = Vector3(
			(av[0].x + av[1].x) * 0.5,
			(av[0].y + av[1].y) * 0.5,
			0.0
		)
