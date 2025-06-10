from collections import defaultdict, deque
from pathlib import Path
from enum import IntEnum
from datetime import datetime
import concurrent.futures
import threading
import traceback
import tempfile
import struct
import json
import sys
import zmq
import os
import subprocess
import re
from sys import platform
import time
import logging

DETAILED_LOGS = False

try:
	os.mkdir(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "logs" ))
except Exception as e:
	pass
log_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "logs", "msep.log" )

logging.basicConfig(
	filename=log_path,   # The log file to write to
	level=logging.INFO,   # The logging level
	format='%(asctime)s - %(message)s',  # Add a timestamp to each log entry
	datefmt='%Y-%m-%d %H:%M:%S'  # Format of the timestamp

)

# OpenMM imports
from openmm.app import *
from openmm import *
from openmm.unit import *

# OpenFF imports
from openff.toolkit import ForceField, Molecule, Topology
from openff.toolkit.utils.toolkits import RDKitToolkitWrapper
	# from openff.toolkit.utils.toolkits import AmberToolsToolkitWrapper
	# from openff.toolkit.utils.toolkits import BuiltInToolkitWrapper
from simtk.openmm.app import PDBxReporter,PDBReporter,CheckpointReporter,DCDReporter,StateDataReporter
from openff.interchange import Interchange
from openff.toolkit.utils.utils import get_data_file_path

from patches import apply_all_patches


class bcolors:
	HEADER = '\033[95m'
	OKBLUE = '\033[94m'
	OKCYAN = '\033[96m'
	OKGREEN = '\033[92m'
	WARNING = '\033[93m'
	FAIL = '\033[91m'
	ENDC = '\033[0m'
	BOLD = '\033[1m'
	UNDERLINE = '\033[4m'

periodic_table_symbols = [
	"N/A", "H", "HE", "LI", "BE", "B", "C", "N", "O", "F", "NE", "NA", "MG", "AL",
	"SI", "P", "S", "CL", "K", "AR", "CA", "SC", "TI", "V", "CR", "MN", "FE", "NI",
	"CO", "CU", "ZN", "GA", "GE", "AS", "SE", "BR", "KR", "RB", "SR", "Y", "ZR", "NB",
	"MO", "TC", "RU", "RH", "PD", "AG", "CD", "IN", "SN", "SB", "TE", "I", "XE", "CS",
	"BA", "LA", "CE", "PR", "ND", "PM", "SM", "EU", "GD", "TB", "DY", "HO", "ER", "TM",
	"YB", "LU", "HF", "TA", "W", "RE", "OS", "IR", "PT", "AU", "HG", "TL", "PB", "BI",
	"TH", "PA", "U", "NP", "PU", "AM", "CM", "BK", "CF", "ES", "FM", "MD", "NO", "LR",
	"RF", "DB", "SG", "BH", "HS", "MT", "DS", "RG", "CN", "NH", "FL", "MC", "LV", "TS",
	"OG"
]

def dot_Vec3(v1, v2) -> float:
	return v1.x*v2.x + v1.y*v2.y + v1.z*v2.z

def length_Vec3(vec: Vec3) -> float:
	return sqrt(vec.x**2+vec.y**2+vec.z**2)

def normalize_Vec3(vec: Vec3) -> Vec3:
	l = length_Vec3(vec)
	return Vec3(vec.x/l, vec.y/l, vec.z/l) * vec.unit

def closest_point_in_rect_to_other(rect_pos: Vec3, rect_dir: Vec3, other: Vec3) -> Vec3:
	w: Vec3 = other - rect_pos
	point_in_rect: Vec3 = rect_pos + (rect_dir * dot_Vec3(w, rect_dir) * rect_pos.unit)
	return point_in_rect

def cross_Vec3(a: Vec3, b: Vec3) -> Vec3:
	c: Vec3 = Vec3(a[1]*b[2] - a[2]*b[1],
					a[2]*b[0] - a[0]*b[2],
					a[0]*b[1] - a[1]*b[0])
	return c

class PayloadChunkReader:
	chunk: bytes = b''
	seek: int = 0
	def __init__(self, chunk):
		self.chunk = chunk
	
	def read_uint8(self) -> int:
		byte: int = self.chunk[self.seek]
		self.seek += 1
		return byte
	
	def read_signed_int8(self) -> int:
		byte: int = self.chunk[self.seek]
		is_negative = (byte & 0b10000000)
		if is_negative:
			byte = -(byte & 0b01111111)
		self.seek += 1
		return byte
	
	def read_uint32(self) -> int:
		pack: bytes = self.chunk[self.seek:self.seek+4]
		uint32_value = struct.unpack('<I', pack)[0]
		self.seek += 4
		return uint32_value
	
	def read_float(self) -> float:
		pack: bytes = self.chunk[self.seek:self.seek+8]
		decoded_float = struct.unpack('d', pack)[0]
		self.seek += 8
		return decoded_float

	def read_utf8_string(self) -> str:
		pack: bytes = self.chunk[self.seek:self.seek+2]
		decoded_length = struct.unpack('<h', pack)[0]
		self.seek += 2
		pack = self.chunk[self.seek:self.seek+decoded_length]
		decoded_string: str = pack.decode('utf-8')
		self.seek += decoded_length
		return decoded_string

class PayloadSimulationParameters(PayloadChunkReader):
	def __init__(self, chunk):
		super().__init__(chunk)
		self.temperature_in_kelvins: float = self.read_float()
		self.time_step_in_femtoseconds: float = self.read_float()
		self.steps_per_report: int = self.read_uint32()
		self.total_step_count: int = self.read_uint32()
		assert(self.seek == len(self.chunk))

class PayloadHeaderReader(PayloadChunkReader):
	def __init__(self, chunk):
		super().__init__(chunk)
		self.molecules_count: int = self.read_uint32()
		self.atoms_count: int = self.read_uint32()
		self.bonds_count: int = self.read_uint32()
		self.passivated_atoms_count: int = self.read_uint32()
		self.virtual_objects_count: int = self.read_uint32()
		self.periodic_box_size: float[3] = [self.read_float(), self.read_float(), self.read_float()]
		self.integrator: str = self.read_utf8_string()
		assert(self.passivated_atoms_count <= self.atoms_count, "There are more passivated atoms than total atoms. That doesn't sound about right")
		assert(self.seek == len(self.chunk))

class AtomData:
	def __init__(self, element, hybridization, charge=0, molecule_id=0, is_locked=False, is_passivation_atom=False):
		self.element: int = element
		self.hybridization: int = hybridization
		self.charge: float = charge
		self.molecule_id: int = molecule_id
		self.is_locked: bool = is_locked
		self.is_passivation_atom: bool = is_passivation_atom
	
	def __str__(self):
		if self.hybridization == 0:
			return self.symbol
		return f"{self.symbol}{self.hybridization}"



class PayloadTopologyReader(PayloadChunkReader):
	def __init__(self, chunk, molecules_count, atoms_count, bonds_count, forcefield_list):
		super().__init__(chunk)
		self.atoms_count: int = atoms_count
		self.bonds_count: int = bonds_count
		self.forcefields: list[str] = str(forcefield_list).split(";")
		self.atoms: list[AtomData] = []
		self.bonds: list[tuple[int, int, int]] = []
		self.molecule_ids: list[int] = []
		self.motors_forces: list[MotorForce] = []
		self.emitters: list[ParticleEmitter] = []
		self.anchors: dict = {}
		self._openff_molecules: list[Molecule] = []
		self.payload_to_openff_atom: dict = {}
		self.openff_atom_to_payload: dict = {}
		atoms_molecule_id: list[int] = []
		passivation_atom_molecule_id: list[int] = []
		total_passivation_atoms_count: int = 0
		for i in range(molecules_count):
			molecule_id: int = self.read_uint32()
			atoms_count_in_molecule: int = self.read_uint32()
			passivation_atoms_count_in_molecule: int = self.read_uint32()
			total_passivation_atoms_count += passivation_atoms_count_in_molecule
			for _ in range(atoms_count_in_molecule):
				atoms_molecule_id.append(molecule_id)
			for _ in range(passivation_atoms_count_in_molecule):
				passivation_atom_molecule_id.append(molecule_id)
		for i in range(self.atoms_count):
			element = self.read_uint8()
			hybridization = self.read_uint8()
			charge = self.read_signed_int8()
			locked = self.read_uint8() != 0
			atom_molecule_id = atoms_molecule_id[i]
			atom = AtomData(element, hybridization, charge, atom_molecule_id, locked)
			self.atoms.append(atom)
		for i in range(self.bonds_count):
			atom1 = self.read_uint32()
			atom2 = self.read_uint32()
			order = self.read_uint8()
			self.bonds.append((atom1, atom2, order))
		# All atoms tracked by MSEP are loaded, now let's add "ghost/passivation" atoms
		for i in range(total_passivation_atoms_count):
			passivated_atom_id = self.read_uint32()
			# Create Atom
			element = 1 # Hydrogen
			hybridization = 0
			charge = 0
			locked = False
			atom_molecule_id = passivation_atom_molecule_id[i]
			atom = AtomData(element, hybridization, charge, atom_molecule_id, locked, is_passivation_atom=True)
			self.atoms.append(atom)
			new_atom_id = len(self.atoms) - 1
			# Create Bond
			order = 1
			self.bonds.append((passivated_atom_id, new_atom_id, order))
		assert(self.seek == len(self.chunk))
	
	def add_virtual_object(self, json_object: dict):
		type = json_object["is"]
		if type == "shape":
			# TODO: handle Shapes
			logging.warning(f"TODO: Handle shape data: {str(json_object)}")
		elif type == "motor":
			self.motors_forces.append(MotorForce(json_object, topology, state))
		elif type == "emitter":
			self.emitters.append(ParticleEmitter(json_object))
		elif type == "anchor":
			anchor_id: int = json_object["anchor_id"]
			self.anchors[anchor_id] = AnchorPoint(json_object)
		elif type == "spring":
			anchor_id: int = json_object["anchor_id"]
			spring = Spring(json_object, topology)
			self.anchors[anchor_id].springs.append(spring)
		else:
			logging.error(f"Unknown virtual object: {type}")
			logging.warning(json_object)
	
	def to_openff_molecules(self) -> list[Molecule]:
		if len(self._openff_molecules) > 0:
			return self._openff_molecules
		molecules: list[Molecule] = []
		atom_to_group: dict = {}
		atom_to_group_atom: dict = {}
		group_atom_to_atom: dict = {}
		mol = Molecule()
		for atoms_in_group in self.find_unconnected_molecules(range(self.atoms_count), self.bonds):
			mol = Molecule()
			group = len(molecules)
			molecules.append(mol)
			for atom_id in atoms_in_group:
				atom: AtomData = self.atoms[atom_id]
				atom_to_group[atom_id] = group
				atom_to_group_atom[atom_id] = mol.add_atom(atomic_number=atom.element, formal_charge=atom.charge, is_aromatic=False)
				group_atom_to_atom[(group,atom_to_group_atom[atom_id])] = atom_id
		
		for bond in self.bonds:
			atom1, atom2, bond_order = bond
			group = atom_to_group[atom1]
			mol = molecules[group]
			mol.add_bond(atom_to_group_atom[atom1], atom_to_group_atom[atom2], bond_order, is_aromatic=False, stereochemistry = None, fractional_bond_order = None)
		logging.info(f"Created {len(molecules)} molecules")
		
		# in order to identify which atom is which we need a map
		# 1. initialize a list with the size of self.atoms filled with 0(es)
		self.payload_to_openff_atom: dict = {}
		self.openff_atom_to_payload: dict = {}
		# 2. atoms inside the system will be in the same order as molecules in this list
		next_openff_atom = 0
		for group,mol in enumerate(molecules):
			for i in range(len(mol.atoms)):
				payload_atom = group_atom_to_atom[(group,i)]
				self.openff_atom_to_payload[next_openff_atom] = payload_atom
				if payload_atom in self.payload_to_openff_atom:
					logging.error(f"ERROR: payload atom")
				self.payload_to_openff_atom[payload_atom] = next_openff_atom
				next_openff_atom += 1

		try:
			for mol in molecules:
				mol.assign_partial_charges(partial_charge_method="mmff94", toolkit_registry=RDKitToolkitWrapper())
		except Exception as e:
			logging.warning(f"Failed to assign partial charges with method 'mmff94'. Fallback to 'gasteiger'")
			try:
				for i, mol in enumerate(molecules):
					mol.assign_partial_charges(partial_charge_method="gasteiger", toolkit_registry=RDKitToolkitWrapper())
			except Exception as e:
				# Atom id in the error is the ID of the molecule, not the ID in the entire structure
				# we need to rewrite the error before raising it
				err_text: str = str(e)
				start: int = err_text.find("atom # ") + 7
				end: int = err_text.find(" ", start)
				num_string: str = err_text[start:end]
				mol_atom_id: int = int(num_string)
				# `i` from for loop should be unchanged
				payload_atom: int = group_atom_to_atom[(i, mol_atom_id)]
				openff_atom_id: int = self.payload_to_openff_atom[payload_atom]
				err_text = err_text[0:start] + str(openff_atom_id) + err_text[end:len(err_text)]
				raise Exception(err_text)
		
		self._openff_molecules = molecules
		return molecules

	def find_unconnected_molecules(self, atoms, bonds):
		# Create an adjacency list for the graph
		graph = defaultdict(list)
		for bond in bonds:
			atom1, atom2, _ = bond
			graph[atom1].append(atom2)
			graph[atom2].append(atom1)
		
		# Function to perform BFS and find all nodes in the same component
		def bfs(start, visited):
			queue = deque([start])
			component = []
			while queue:
				node = queue.popleft()
				if node not in visited:
					visited.add(node)
					component.append(node)
					for neighbor in graph[node]:
						if neighbor not in visited:
							queue.append(neighbor)
			return component
		
		# Find all connected components
		visited = set()
		molecules = []
		for atom in atoms:
			if atom not in visited:
				component = bfs(atom, visited)
				molecules.append(component)
		
		return molecules


class PayloadStateReader(PayloadChunkReader):
	def __init__(self, chunk, atoms_count, passivation_atoms_count):
		super().__init__(chunk)
		self.atoms_count: int = atoms_count
		self.positions: list[Vec3] = []
		for i in range(self.atoms_count + passivation_atoms_count):
			pos = Vec3(self.read_float(), self.read_float(), self.read_float())
			self.positions.append(pos)
		assert(self.seek == len(self.chunk))


class Spring:
	def __init__(self, spring_data: dict, topology_payload: PayloadTopologyReader) -> None:
		self.anchor_id: int = spring_data["anchor_id"]
		msep_atom_id: int = spring_data["particle_id"]
		openff_atom_id = topology_payload.payload_to_openff_atom[msep_atom_id]
		self.particle_id: int = openff_atom_id
		self.k_constant: float = spring_data["k_constant"]
		self.equilibrium_length: float = spring_data["equilibrium_length"]


class AnchorPoint:
	def __init__(self, anchor_data: dict) -> None:
		self.anchor_id: int = json_object["anchor_id"]
		self.openmm_particle_id = -1 # to be overriden when PayloadTopologyReader.to_openmm() is called
		self.position: list[float] = json_object["position"]
		self.springs: list[Spring] = []


class MotorType(IntEnum):
	UNKNOWN = 0,
	ROTARY = 1,
	LINEAR = 2

class RotaryPolarity(IntEnum):
	CLOCKWISE = 0,
	COUNTER_CLOCKWISE = 1

class RotaryMaxSpeedType(IntEnum):
	TOP_SPEED = 0,
	MAX_TORQUE = 1

class LinearPolarity(IntEnum):
	FORWARD = 0,
	BACKWARDS = 1

class CycleType(IntEnum):
	CONTINUOUS = 0,  ## Start and never stop the motor
	TIMED = 1,       ## In every cycle, motor will stop after a fixed amount of time has elapsed
	BY_DISTANCE = 2, ## In every cycle, motor will stop after a fixed amount of distance was covered, This distance is in nanometers for linear motors and revolutions for rotary motors

MOTOR_DEBUG_PRINTS = False
MOTOR_PER_PARTICLE_LOG_FILES = [] # ie: [1, 2, 60, ....]
PI = 3.14159265359
class MotorForce:
	def __init__(self, motor_force_data: dict, topology_payload: PayloadTopologyReader, state_payload: PayloadStateReader) -> None:
		self.stopped = False
		self.connected_molecules: list[int] = motor_force_data["connected_molecules"]
		self.motor_type: MotorType = motor_force_data["parameters"]["motor_type"]
		
		self.ramp_in_time_in_nanoseconds: float = motor_force_data["parameters"]["ramp_in_time_in_nanoseconds"]
		match self.motor_type:
			case MotorType.ROTARY:
				rotary_polarity: RotaryPolarity = motor_force_data["parameters"]["polarity"]
				self.polarity: float = 1.0 if rotary_polarity == RotaryPolarity.CLOCKWISE else -1.0
				self.is_jerk_limited: bool = motor_force_data["parameters"]["is_jerk_limited"]
				self.jerk_limit: float = motor_force_data["parameters"]["jerk_limit"]
				self.max_speed_type: RotaryMaxSpeedType = motor_force_data["parameters"]["max_speed_type"]
				self.max_torque: float = motor_force_data["parameters"]["max_torque"]
				top_revolutions_per_nanosecond: float = motor_force_data["parameters"]["top_revolutions_per_nanosecond"]
				# convert Rev/ns to RADIANS/ns
				self.top_speed_in_radians_per_nanosecond = top_revolutions_per_nanosecond * 2.0 * PI
				self.last_motor_velocities = []
			case MotorType.LINEAR:
				linear_polarity: LinearPolarity = motor_force_data["parameters"]["polarity"]
				self.polarity: float = 1.0 if linear_polarity == LinearPolarity.FORWARD else -1.0
				self.top_speed_in_nanometers_by_nanoseconds = motor_force_data["parameters"]["top_speed_in_nanometers_by_nanoseconds"]
			case _:
				logging.error(f"Unknown motor type '{self.motor_type}'!")
				pass
		self.cycle_type: CycleType = motor_force_data["parameters"]["cycle_type"]
		if self.cycle_type == CycleType.CONTINUOUS:
			# nothing to do here
			pass
		elif self.cycle_type == CycleType.TIMED:
			self.ramp_out_time_in_nanoseconds: float = motor_force_data["parameters"]["ramp_out_time_in_nanoseconds"]
			self.cycle_time_limit_in_nanoseconds: float = motor_force_data["parameters"]["cycle_time_limit_in_femtoseconds"] / 1000000.0
			self.cycle_start_stop_at_nanoseconds: float = self.cycle_time_limit_in_nanoseconds - self.ramp_out_time_in_nanoseconds
			self.cycle_pause_in_nanoseconds: float = motor_force_data["parameters"]["cycle_pause_time_in_femtoseconds"] / 1000000.0
			self.cycle_eventually_stops: bool = motor_force_data["parameters"]["cycle_eventually_stops"]
			self.cycle_stop_after_n_cycles: int = motor_force_data["parameters"]["cycle_stop_after_n_cycles"]
			self.cycle_swap_polarity: bool = motor_force_data["parameters"]["cycle_swap_polarity"]
			# Calculate acceleration
			if self.ramp_in_time_in_nanoseconds <= 0:
				self.cycle_accel: float = 0.0
			elif self.motor_type == MotorType.ROTARY:
				self.cycle_accel: float = self.top_speed_in_radians_per_nanosecond / self.ramp_in_time_in_nanoseconds
			else: # MotorType.LINEAR
				self.cycle_accel: float = self.top_speed_in_nanometers_by_nanoseconds / self.ramp_in_time_in_nanoseconds
			# Calculate deceleration
			if self.ramp_out_time_in_nanoseconds <= 0:
				self.cycle_decel: float = 0
			elif self.motor_type == MotorType.ROTARY:
				self.cycle_decel: float = self.top_speed_in_radians_per_nanosecond / self.ramp_out_time_in_nanoseconds
			else: # MotorType.LINEAR
				self.cycle_decel: float = self.top_speed_in_nanometers_by_nanoseconds / self.ramp_out_time_in_nanoseconds
			# Calculate peaek speeds and times
			if self.cycle_time_limit_in_nanoseconds < (self.ramp_in_time_in_nanoseconds + self.ramp_out_time_in_nanoseconds):
				# Needs to adjust ramp time and max speed
				expected_time: float = self.ramp_in_time_in_nanoseconds + self.ramp_out_time_in_nanoseconds
				acceleration_ratio: float = self.ramp_in_time_in_nanoseconds / expected_time
				self.ramp_in_time_in_nanoseconds = self.cycle_time_limit_in_nanoseconds * acceleration_ratio
				self.ramp_out_time_in_nanoseconds = self.cycle_time_limit_in_nanoseconds - self.ramp_in_time_in_nanoseconds
				# Calculate new top speed based on acceleration and ramp in time
				if self.motor_type == MotorType.ROTARY:
					self.top_speed_in_radians_per_nanosecond = self.ramp_in_time_in_nanoseconds * self.cycle_accel
				else: # MotorType.LINEAR
					self.top_speed_in_nanometers_by_nanoseconds = self.ramp_in_time_in_nanoseconds * self.cycle_accel
			self.cycle_start_stop_at_nanoseconds: float = self.cycle_time_limit_in_nanoseconds - self.ramp_out_time_in_nanoseconds
		elif self.cycle_type == CycleType.BY_DISTANCE:
			self.ramp_out_time_in_nanoseconds: float = motor_force_data["parameters"]["ramp_out_time_in_nanoseconds"]
			cycle_limit: float
			cycle_top_speed: float
			if self.motor_type == MotorType.ROTARY:
				cycle_limit_in_revolutions: float = motor_force_data["parameters"]["cycle_distance_limit"]
				self.cycle_limit_in_radians = cycle_limit_in_revolutions * 2.0 * PI
				cycle_limit = self.cycle_limit_in_radians
				cycle_top_speed = self.top_speed_in_radians_per_nanosecond
			else: # MotorType.LINEAR
				self.cycle_limit_in_nanometers: float = motor_force_data["parameters"]["cycle_distance_limit"]
				cycle_limit = self.cycle_limit_in_nanometers
				cycle_top_speed = self.top_speed_in_nanometers_by_nanoseconds
			self.cycle_pause_in_nanoseconds: float = motor_force_data["parameters"]["cycle_pause_time_in_femtoseconds"] / 1000000.0
			self.cycle_eventually_stops: bool = motor_force_data["parameters"]["cycle_eventually_stops"]
			self.cycle_stop_after_n_cycles: int = motor_force_data["parameters"]["cycle_stop_after_n_cycles"]
			self.cycle_swap_polarity: bool = motor_force_data["parameters"]["cycle_swap_polarity"]
			# Calculate acceleration
			if self.ramp_in_time_in_nanoseconds <= 0:
				self.cycle_accel: float = 0.0
			elif self.motor_type == MotorType.ROTARY:
				self.cycle_accel: float = self.top_speed_in_radians_per_nanosecond / self.ramp_in_time_in_nanoseconds
			else: # MotorType.LINEAR
				self.cycle_accel: float = self.top_speed_in_nanometers_by_nanoseconds / self.ramp_in_time_in_nanoseconds
			# Calculate deceleration
			if self.ramp_out_time_in_nanoseconds <= 0:
				self.cycle_decel: float = 0
			elif self.motor_type == MotorType.ROTARY:
				self.cycle_decel: float = self.top_speed_in_radians_per_nanosecond / self.ramp_out_time_in_nanoseconds
			else: # MotorType.LINEAR
				self.cycle_decel: float = self.top_speed_in_nanometers_by_nanoseconds / self.ramp_out_time_in_nanoseconds
			# Calculate peaek speeds and times
			# pos = v0 * t + a * t**2 / 2
			# with v0 = 0
			# with a  = self.cycle_accel
			# with t  = self.ramp_in_time_in_nanoseconds
			# =>
			expected_acceleration_distance = self.cycle_accel * (self.ramp_in_time_in_nanoseconds**2) * 0.5
			expected_deceleration_distance = self.cycle_decel * (self.ramp_out_time_in_nanoseconds**2) * 0.5
			constant_speed_time = (cycle_limit - (expected_acceleration_distance + expected_deceleration_distance)) / cycle_top_speed
			if constant_speed_time < 0:
				# Need to adjust top speed
				expected_time: float = self.ramp_in_time_in_nanoseconds + self.ramp_out_time_in_nanoseconds
				acceleration_ratio: float = self.ramp_in_time_in_nanoseconds / expected_time
				self.ramp_in_time_in_nanoseconds = self.ramp_in_time_in_nanoseconds + constant_speed_time * (1.0 - acceleration_ratio)
				self.ramp_out_time_in_nanoseconds = self.ramp_out_time_in_nanoseconds + constant_speed_time * acceleration_ratio
				expected_acceleration_distance = self.cycle_accel * (self.ramp_in_time_in_nanoseconds**2) * 0.5
				expected_deceleration_distance = self.cycle_decel * (self.ramp_out_time_in_nanoseconds**2) * 0.5
				# Calculate new top speed based on acceleration and ramp in time
				if self.motor_type == MotorType.ROTARY:
					self.top_speed_in_radians_per_nanosecond = self.ramp_in_time_in_nanoseconds * self.cycle_accel
				else: # MotorType.LINEAR
					self.top_speed_in_nanometers_by_nanoseconds = self.ramp_in_time_in_nanoseconds * self.cycle_accel
			self.cycle_start_stop_at_distance: float = cycle_limit - expected_deceleration_distance
		pos: list[float] = motor_force_data["position"]
		self.position = Vec3(pos[0], pos[1], pos[2]) * nanometer
		dir: list[float] = motor_force_data["axis_direction"]
		self.axis_direction: Vec3 = Vec3(dir[0], dir[1], dir[2])
		# Initialize motor internal state
		self.atom_ids: list[int] = []
		Path(os.path.expanduser(os.path.join('~','particle_logs'))).mkdir(parents=True, exist_ok=True)
		self.particle_log_file: list[int] = []
		self.time_accum: float = 0
		self.distance_accum: float = 0
		self.cycle_counter: int = 0
		self.cycle_time_accum: float = 0.0
		self.cycle_distance_accum: float = 0.0
		self.cycle_started_to_stop_at_time: float = 0
		self.cycle_pause_time_accum: float = 0.0
		self.cycle_paused: bool = False
		self.print_counter: int = 0
		added_particles = 0
		is_rotary: bool = self.motor_type == MotorType.ROTARY
		for i in range(topology_payload.atoms_count):
			atom: AtomData = topology_payload.atoms[i]
			if not atom.molecule_id in self.connected_molecules:
				continue
			openff_atom_id = topology_payload.payload_to_openff_atom[i]
			self.atom_ids.append(openff_atom_id)
			self.particle_log_file.append(os.path.expanduser(os.path.join('~','particle_logs',f'{openff_atom_id}.log')))
			if is_rotary:
				self.last_motor_velocities.append(Vec3(0.0, 0.0, 0.0) * nanometer / nanosecond)
				self.init_particle_log(self.atom_ids.index(openff_atom_id))
			added_particles += 1
		types_str: list[str] = ["unk", "rotary", "linear"]
		logging.info(f"Added {added_particles} particles to {types_str[self.motor_type]} force")

	def particle_log(self, i, text):
		atom_id: int = self.atom_ids[i]
		if not atom_id in MOTOR_PER_PARTICLE_LOG_FILES:
			return
		with open(self.particle_log_file[i], 'a') as f:
			print(text, file=f)
	
	def init_particle_log(self, i):
		atom_id: int = self.atom_ids[i]
		if not atom_id in MOTOR_PER_PARTICLE_LOG_FILES:
			return
		# deletes file if exists
		try:
			os.remove(self.particle_log_file[i])
		except OSError:
			pass
		
		with open(self.particle_log_file[i], 'w') as f:
			f.write("")
		print(f"Initialized log path: {self.particle_log_file[i]}")


	def advance(self, simulation):
		match self.motor_type:
			case MotorType.ROTARY:
				self._advance_rotary(simulation)
			case MotorType.LINEAR:
				self._advance_linear(simulation)
			case _:
				logging.error(f"Unknown motor type '{self.motor_type}'!")
				pass
	
	def _advance_rotary(self, simulation):
		if self.stopped or len(self.atom_ids) == 0:
			# Nothing to do here
			return
		self.time_accum += simulation.time_step_in_nanoseconds
		speed: float = self._calculate_speed(simulation.time_step_in_nanoseconds)
		self.distance_accum += (simulation.time_step_in_nanoseconds * speed) / (2 * PI) # acum distance is in cycles
		
		self.print_counter = (self.print_counter + 1) % 64 # print every 64 steps
		if self.print_counter == 0:
			if MOTOR_DEBUG_PRINTS:
				logging.info(f"motor speed is {speed}rad/ns , distance is {self.distance_accum}nm ")
		
		state = simulation.context.getState(getVelocities=True, getPositions= True)
		prev_velocities = state.getVelocities()
		positions = state.getPositions()
		new_velocities = prev_velocities.copy()
		for i in range(len(self.atom_ids)):
			atom_id: int = self.atom_ids[i]
			new_motor_velocity: Vec3 = self._calculate_rotary_motor_particle_velocity(speed, positions[atom_id], i)
			if atom_id in MOTOR_PER_PARTICLE_LOG_FILES:
				prev_motor_velocity: Vec3 = self.last_motor_velocities[i]
				if length_Vec3(prev_motor_velocity) > 0.0 and length_Vec3(new_motor_velocity) > 0.0 and dot_Vec3(normalize_Vec3(prev_motor_velocity), normalize_Vec3(new_motor_velocity)) < 0.1:
					self.particle_log(i, "		MOTOR DIRECTION SUDDENLY INVERTED!")
					self.particle_log(i, f"		speed ({speed}) , prev_motor_velocity {prev_motor_velocity}({length_Vec3(prev_motor_velocity)}) new_motor_velocity {new_motor_velocity}({length_Vec3(new_motor_velocity)})")
			new_velocities[atom_id] = new_motor_velocity
			self.last_motor_velocities[i] = new_motor_velocity # update record for the next iter
		simulation.context.setVelocities(new_velocities)
		return
	
	def _calculate_rotary_motor_particle_distance_to_axis(self, particle_pos: Vec3) -> float:
		axis_of_rotation: Vec3 = closest_point_in_rect_to_other(self.position, self.axis_direction, particle_pos)
		distance = length_Vec3(particle_pos - axis_of_rotation)
		return distance
	
	def _calculate_rotary_motor_particle_velocity(self, speed: float, particle_pos: Vec3, i: int) -> Vec3:
		distance_to_axis: float = self._calculate_rotary_motor_particle_distance_to_axis(particle_pos)
		axis_of_rotation: Vec3 = closest_point_in_rect_to_other(self.position, self.axis_direction, particle_pos)
		axis_to_particle_vec: Vec3 = particle_pos - axis_of_rotation
		axis_to_particle_dir: Vec3 = normalize_Vec3(axis_to_particle_vec)
		move_dir: Vec3 = cross_Vec3(axis_to_particle_dir / nanometer, self.axis_direction) * nanometer / nanosecond
		velocity: Vec3 = move_dir * speed * distance_to_axis * self.polarity
		atom_id: int = self.atom_ids[i]
		if atom_id in MOTOR_PER_PARTICLE_LOG_FILES:
			# This if condition is not strictly necesary, but will prevent wasting cpu on formating strings
			self.particle_log(i, f"CALCULATE VELOCITY, time is {self.time_accum * 1000000}fs")
			self.particle_log(i, f"	particle_pos {particle_pos}")
			self.particle_log(i, f"	distance_to_axis {distance_to_axis}nm")
			self.particle_log(i, f"	axis_of_rotation {axis_of_rotation}")
			self.particle_log(i, f"	axis_to_particle_vec {axis_to_particle_vec}")
			self.particle_log(i, f"	axis_to_particle_dir {axis_to_particle_dir}")
			self.particle_log(i, f"	move_dir {move_dir}")
			self.particle_log(i, f"		velocity ({length_Vec3(velocity)}nm/ns) {velocity}")
		return velocity
	
	def _advance_linear(self, simulation):
		if self.stopped or len(self.atom_ids) == 0:
			# Nothing to do here
			return
		
		self.time_accum += simulation.time_step_in_nanoseconds
		new_motor_velocity: Vec3 = Vec3(0,0,0) # new motor velocity is the same for all particles linked to the motor
		speed: float = self._calculate_speed(simulation.time_step_in_nanoseconds)
		new_motor_velocity = self.axis_direction * speed * self.polarity * nanometer / nanosecond
		self.distance_accum += simulation.time_step_in_nanoseconds * speed
		self.print_counter = (self.print_counter + 1) % 64 # print every 64 steps

		if self.print_counter == 0 or self.stopped:
			if MOTOR_DEBUG_PRINTS:
				logging.info(f"motor velocity is {new_motor_velocity} , distance is {self.distance_accum}nm , time is {self.time_accum * 1000000}fs")
		
		state = simulation.context.getState(getVelocities=True)
		prev_velocities = state.getVelocities()
		new_velocities = prev_velocities.copy()
		for i in range(len(self.atom_ids)):
			atom_id: int = self.atom_ids[i]
			current_velocity_in_desired_direction = self.axis_direction * dot_Vec3(prev_velocities[atom_id], self.axis_direction) * prev_velocities[atom_id].unit
			delta_velocity = new_motor_velocity - current_velocity_in_desired_direction
			new_velocities[atom_id] = prev_velocities[atom_id] + delta_velocity
		simulation.context.setVelocities(new_velocities)
		return

	def _calculate_speed(self, delta_time: float) -> float:
		if self.cycle_paused:
			self.cycle_pause_time_accum += delta_time
			if self.cycle_pause_time_accum >= self.cycle_pause_in_nanoseconds:
				# Unpause
				self.cycle_pause_time_accum = 0.0
				self.cycle_paused = False
			PAUSE_SPEED = 0
			return PAUSE_SPEED

		max_speed: float = (
				self.top_speed_in_radians_per_nanosecond
				if self.motor_type == MotorType.ROTARY else
				self.top_speed_in_nanometers_by_nanoseconds )
		speed: float = max_speed
		self.cycle_time_accum += delta_time
		
		if self.cycle_time_accum < self.ramp_in_time_in_nanoseconds:
			relative_time = self.cycle_time_accum / self.ramp_in_time_in_nanoseconds
			speed = max_speed * relative_time
		
		if self.cycle_type == CycleType.CONTINUOUS:
			self.cycle_distance_accum += speed * delta_time
			return speed
		
		cycle_reference: float = self.cycle_time_accum if self.cycle_type == CycleType.TIMED else self.cycle_distance_accum
		cycle_start_stop_at = self.cycle_start_stop_at_nanoseconds if self.cycle_type == CycleType.TIMED else self.cycle_start_stop_at_distance
		if cycle_reference > cycle_start_stop_at:
			# Deaccelerating
			if self.cycle_started_to_stop_at_time == 0:
				self.cycle_started_to_stop_at_time = self.cycle_time_accum
			overshot_time: float = self.cycle_time_accum - self.cycle_started_to_stop_at_time
			if overshot_time >= self.ramp_out_time_in_nanoseconds:
				self.cycle_started_to_stop_at_time = 0
				self.cycle_distance_accum = 0
				self.cycle_time_accum = 0
				self.cycle_counter += 1
				if self.cycle_pause_in_nanoseconds > 0:
					self.cycle_paused = True
					self.cycle_pause_time_accum = 0
				if self.cycle_eventually_stops and self.cycle_counter >= self.cycle_stop_after_n_cycles:
					# Stop
					if MOTOR_DEBUG_PRINTS:
						logging.info("Stop")
					self._stop_motor(simulation)
					speed = 0
				else:
					if self.cycle_swap_polarity:
						self._invert_polarity()
					speed = 0
			else:
				relative_time:float = 1.0 - overshot_time / self.ramp_out_time_in_nanoseconds
				speed = max_speed * relative_time
		else:
			speed = max_speed
		self.cycle_distance_accum += speed * delta_time
		return speed

	def _invert_polarity(self):
		# Swap polarity and reset time and distance counters
		self.polarity *= -1.0
	
	def _stop_motor(self, simulation):
		self.stopped = True
	


class ParticleEmitter:
	def __init__(self, emitter_data: dict) -> None:
		self.emitter_id: int = emitter_data["emitter_id"]
		self.molecule_id: int = emitter_data["molecule_id"]
		pos: list[float] = emitter_data["position"]
		self.position = Vec3(pos[0], pos[1], pos[2]) * nanometer
		dir: list[float] = emitter_data["axis_direction"]
		self.axis_direction: Vec3 = Vec3(dir[0], dir[1], dir[2])
		self.running: bool = emitter_data["parameters"]["_initial_delay_in_nanoseconds"] <= 0.0
		self.initial_delay_in_nanoseconds = emitter_data["parameters"]["_initial_delay_in_nanoseconds"]
		self.instance_rate_time_in_nanoseconds = emitter_data["parameters"]["_instance_rate_time_in_nanoseconds"]
		self.instance_speed_nanometers_per_picosecond = emitter_data["parameters"]["_instance_speed_nanometers_per_picosecond"]
		self.molecules_per_instance = emitter_data["parameters"]["_molecules_per_instance"]
		self.total_instance_count = emitter_data["parameters"]["total_instance_count"]
		self.spread_angle = emitter_data["parameters"]["_spread_angle"]
		self.payload_instances_atoms_list: list[list[int]] = emitter_data["atoms_list"]
		self.openmm_instances_atoms_list: list[list[int]] = emitter_data["atoms_list"]
		self.atom_groups_per_instance = 1 # this is how many unnconected group of atoms are in the template, in example 2 molecules of water
		self.instances: list[list[Molecule]] = []
		self._molecule_forces_cache: dict[int,list] = {}
		self.time_accum: float = 0.0
		self.last_instanced_molecule_index: int = -1
	
	def setup(self, simulation: Simulation, out_nonbonded_force: NonbondedForce, payload_to_openff_atom: dict):
		# particles emiter should be one step ahead
		self.time_accum += simulation.time_step_in_nanoseconds
		state = simulation.context.getState(getPositions=True, getVelocities=True)
		positions = state.getPositions()
		initial_velocities = state.getVelocities()
		for i in range(len(initial_velocities)):
			# velocities can be initialized to nan for some reason
			if math.isnan(initial_velocities[i].x) or math.isnan(initial_velocities[i].y) or math.isnan(initial_velocities[i].z):
				initial_velocities._value[i] = Vec3(0.0, 0.0, 0.0)
		for i in range(len(self.payload_instances_atoms_list)):
			instance_atoms = self.payload_instances_atoms_list[i]
			instance_openmm_atoms: list[int] = []
			for payload_atom_id in instance_atoms:
				atom_id: int = payload_to_openff_atom[payload_atom_id]
				instance_openmm_atoms.append(atom_id)
				mass = simulation.system.getParticleMass(atom_id)
				simulation.system.setParticleMass(atom_id, 0)
				parameters = out_nonbonded_force.getParticleParameters(atom_id)
				position = positions[atom_id]
				velocity = initial_velocities[atom_id]
				self._molecule_forces_cache[atom_id] = [mass, parameters, position, velocity]
				out_nonbonded_force.setParticleParameters(atom_id, 0.0, 0.0, 0.0)
				# Override initial positions, this should prevent force calculations to fail until atoms are enabled
				positions._value[atom_id] = Vec3(0.0, 0.0, float(atom_id))
				initial_velocities._value[atom_id] = Vec3(0.0, 0.0, 0.0)
			self.openmm_instances_atoms_list.append(instance_openmm_atoms)
		simulation.context.setPositions(positions)
		simulation.context.setVelocities(initial_velocities)

	def advance(self, simulation: Simulation, out_nonbonded_force):
		self.time_accum += simulation.time_step_in_nanoseconds
		for i in range(self.last_instanced_molecule_index + 1, self.total_instance_count):
			spawn_time = self.initial_delay_in_nanoseconds + int(i / self.molecules_per_instance) * self.instance_rate_time_in_nanoseconds
			if spawn_time > self.time_accum:
				# not spawned yet
				return
			self.enable_instance(i, simulation, out_nonbonded_force)

	def enable_instance(self, instance_index: int, simulation: Simulation, out_nonbonded_force: NonbondedForce):
		state = simulation.context.getState(getVelocities=True, getPositions=True)
		velocities = state.getVelocities()
		current_positions = state.getPositions()
		new_velocities = velocities.copy()
		initial_velocity = self._get_random_dir_in_spread() * self.instance_speed_nanometers_per_picosecond
		for atom_id in self.openmm_instances_atoms_list[instance_index]:
			mass = self._molecule_forces_cache[atom_id][0]
			parameters = self._molecule_forces_cache[atom_id][1]
			position = self._molecule_forces_cache[atom_id][2]
			original_velocity = self._molecule_forces_cache[atom_id][3]
			simulation.system.setParticleMass(atom_id, mass)
			out_nonbonded_force.setParticleParameters(atom_id, parameters[0], parameters[1], parameters[2])
			current_positions[atom_id] = position
			TEMPERATURE_CONSERVATION_FACTOR = 0.5
			new_velocities[atom_id] = (original_velocity * TEMPERATURE_CONSERVATION_FACTOR) + initial_velocity * velocities[atom_id].unit
		self.last_instanced_molecule_index = max(self.last_instanced_molecule_index, instance_index)
		simulation.context.setVelocities(new_velocities)
		simulation.context.setPositions(current_positions)

	def _get_random_dir_in_spread(self) -> Vec3:
		if self.spread_angle == 0.0:
			return self.axis_direction
		
		import numpy as np
		from numpy.typing import NDArray
		v: NDArray[np.float64] = [self.axis_direction.x, self.axis_direction.y, self.axis_direction.z]
		# Normalize the input vector
		v = v / np.linalg.norm(v)

		# Generate a random axis perpendicular to v
		rand_vec: NDArray[np.float64] = np.random.randn(3)
		axis: NDArray[np.float64] = np.cross(v, rand_vec)
		axis_norm: float = np.linalg.norm(axis)

		if axis_norm == 0:
			axis = np.array([1.0, 0.0, 0.0]) if not np.allclose(v, [1.0, 0.0, 0.0]) else np.array([0.0, 1.0, 0.0])
		else:
			axis /= axis_norm

		# Random angle between 0 and max_angle_rad
		angle: float = np.random.uniform(0.0, self.spread_angle)

		# Rodrigues' rotation formula
		cos_theta: float = np.cos(angle)
		sin_theta: float = np.sin(angle)
		cross: NDArray[np.float64] = np.cross(axis, v)
		dot: float = np.dot(axis, v)
		rotated: NDArray[np.float64] = (
			v * cos_theta +
			cross * sin_theta +
			axis * dot * (1 - cos_theta)
		)

		return Vec3(rotated[0], rotated[1], rotated[2])



class ZmqPublishReporter(object):
	def __init__(self, simulation_id, publish_scoket, publish_socket_lock, reportInterval):
		self._simulation_id = simulation_id
		self._publish_scoket = publish_scoket
		self._publish_socket_lock = publish_socket_lock
		self._reportInterval = reportInterval
		self._has_error = False

	def describeNextReport(self, simulation):
		if self._has_error:
			return (0, False, False, False, False, None)
		steps = self._reportInterval - simulation.currentStep%self._reportInterval
		# Returns a touple containing:
		# - The number of time steps until the next report. We calculate this as (report interval)-(current step)%(report interval). For example, if we want a report every 100 steps and the simulation is currently on step 530, we will return 100-(530%100) = 70.
		# - Whether the next report will need particle positions.
		# - Whether the next report will need particle velocities.
		# - Whether the next report will need forces.
		# - Whether the next report will need energies.
		# - Whether the positions should be wrapped to the periodic box. If None, it will automatically decide whether to wrap positions based on whether the System uses periodic boundary conditions.
		return (steps, True, False, False, False, None)

	def report(self, simulation, state):
		simulation.frame += 1
		#time_in_femtoseconds: float = (state.getTime() / femtosecond)
		#time_buffer:bytes = struct.pack("d", time_in_femtoseconds)
		time_buffer:bytes = struct.pack("d", simulation.frame)
		openff_positions: list[Vec3] = state.getPositions()
		positions: list[Vec3] = []
		payload_to_openff_atom = simulation.payload_to_openff_atom
	
		for i in range(simulation.atoms_count):
			positions.append(openff_positions[payload_to_openff_atom[i]])

		positions_buffer: bytes = b''
		if len(positions) != simulation.atoms_count:
			self._has_error = True
		else:
			for p, pos in enumerate(positions):
				if p >= simulation.atoms_count:
					# This is an anchor position. Skip
					break
				for i in range(3):
					raw = pos[i] / nanometer
					if math.isnan(raw):
						self._has_error = True
						break
					positions_buffer += struct.pack("d", raw)
		with self._publish_socket_lock:
			self._publish_scoket.send_string(str(self._simulation_id), zmq.SNDMORE)
			self._publish_scoket.send(time_buffer, zmq.SNDMORE)
			if self._has_error:
				self._publish_scoket.send_string("err")
				# Abort simulation
				stop_trigger: threading.Event = running_simulations.get(self._simulation_id, None)
				if stop_trigger != None and not stop_trigger.is_set():
					logging.warning(f"Aborted simulation because system failed to calculate particles positions")
					stop_trigger.set()
			else:
				self._publish_scoket.send(positions_buffer)

class ImportFileRequest:
	def __init__(self, path):
		self.path = path
		try:
			self.extension = os.path.splitext(path)[1][1:]
		except Exception as inst:
			raise Exception(f"Failed to obtain file extension from path {path}")
		self.option_generate_bonds = False
		self.option_add_hydrogens = False
		self.option_remove_waters = False
	
	def process_option(self, option):
		parts = option.split("=", 1)
		if len(parts) != 2:
			logging.error(f"Invalid argument '{option}' for process 'Import File'")
			return
		if not parts[1] in ["yes", "no"]:
			# For now only boolean options are supported
			logging.error(f"Invalid argument value '{parts[1]}' for argument '{parts[0]}' in process 'Import File'")
			return
		opt_name: str = parts[0]
		opt_value: bool = True if parts[1] == "yes" else False

		match opt_name:
			case "--generate_bonds":
				self.option_generate_bonds = opt_value
			case "--add_hydrogens":
				self.option_add_hydrogens = opt_value
			case "--remove_waters":
				self.option_remove_waters = opt_value
			case _:
				logging.error(f"Unknown argument '{option}' for process 'Import File' will be ignored")
				return

class ImportFileResponse():
	def __init__(self, openmm_topology, positions, bonds):
		self.openmm_topology = openmm_topology
		self.positions = positions
		self.bonds = bonds


def create_forcefield_for_topology(topology_payload: PayloadTopologyReader, remove_constraints=False) -> ForceField:
	openff_forcefield_path = os.path.join(os.path.dirname(__file__ ), "offxml", topology_payload.forcefields[0])
	forcefield = ForceField(openff_forcefield_path)
	if remove_constraints and "Constraints" in forcefield.registered_parameter_handlers:
		forcefield.deregister_parameter_handler("Constraints")
	for i in range(1, len(topology_payload.forcefields)):
		forcefield_extension_path = os.path.join(os.path.dirname(__file__ ), "offxml_extensions", topology_payload.forcefields[i])
		with open(forcefield_extension_path, 'r', encoding='utf-8') as f:
			forcefield.parse_sources([f])
	return forcefield


def minimize_energy(header:PayloadHeaderReader, topology_payload: PayloadTopologyReader, state_payload: PayloadStateReader, temperature_in_kelvins: float, max_iterations: int = 0) -> list[Vec3]:
	molecules: list[Molecule] = topology_payload.to_openff_molecules()
	topology = Topology.from_molecules(molecules)
	forcefield = create_forcefield_for_topology(topology_payload)
	interchange = Interchange.from_smirnoff(forcefield, topology, charge_from_molecules=molecules)

	openmm_system = interchange.to_openmm()
	openmm_topology = interchange.to_openmm_topology()
	openff_initial_positions: list[Vec3] = []
	for i in range(len(state_payload.positions)):
		payload_atom_id = topology_payload.openff_atom_to_payload[i]
		openff_initial_positions.append(state_payload.positions[payload_atom_id])
	if (not header is None) and header.periodic_box_size[0] > 0 and header.periodic_box_size[1] > 0 and header.periodic_box_size[2] > 0:
		openmm_system.setDefaultPeriodicBoxVectors(
			Vec3(header.periodic_box_size[0], 0, 0),
			Vec3(0, header.periodic_box_size[1], 0),
			Vec3(0, 0, header.periodic_box_size[2]))
	# Anchors
	bond_force: HarmonicBondForce = None
	nonbonded_force: NonbondedForce = None
	for force in openmm_system.getForces():
		if isinstance(force, HarmonicBondForce):
			bond_force = force
		if isinstance(force, NonbondedForce):
			nonbonded_force = force
	for anchor_id in topology_payload.anchors:
		anchor: AnchorPoint = topology_payload.anchors[anchor_id]
		if len(anchor.springs) == 0:
			continue
		anchor.openmm_particle_id = openmm_system.addParticle(0.0)
		if nonbonded_force != None:
			nonbonded_force.addParticle(0.0, 1.0, 0.0)
		pos = anchor.position
		openff_initial_positions.append(Vec3(pos[0], pos[1], pos[2]))
		for spring in anchor.springs:
			k_constant: float = spring.k_constant
			equilibrium_length: float = spring.equilibrium_length
			if nonbonded_force != None:
				nonbonded_force.addException(anchor.openmm_particle_id, spring.particle_id, 0.0, 1.0, 0.0)
			# NOTE: use of openmm_system.addConstraint() was  not possible because it doesn't support massless particles
			bond_force.addBond(anchor.openmm_particle_id, spring.particle_id, equilibrium_length, k_constant)
	for i, atom in enumerate(topology_payload.atoms):
		if atom.is_locked:
			openff_atom_id = topology_payload.payload_to_openff_atom[i]
			lock_particle_id = openmm_system.addParticle(0.0)
			if nonbonded_force != None:
				nonbonded_force.addParticle(0.0, 1.0, 0.0)
			pos = state_payload.positions[i]
			openff_initial_positions.append(pos)
			k_constant: float = 500000.0
			equilibrium_length: float = 0.0
			if nonbonded_force != None:
				nonbonded_force.addException(lock_particle_id, openff_atom_id, 0.0, 1.0, 0.0)
			# NOTE: use of openmm_system.addConstraint() was  not possible because it doesn't support massless particles
			bond_force.addBond(lock_particle_id, openff_atom_id, equilibrium_length, k_constant)
		if atom.is_passivation_atom:
			openff_atom_id = topology_payload.payload_to_openff_atom[i]
			nonbonded_force.setParticleParameters(openff_atom_id, charge=0.0, sigma=0.0, epsilon=0.0)
	integrator: Integrator = None
	if (not header is None) and header.integrator == "langevin":
		integrator = LangevinMiddleIntegrator(temperature_in_kelvins*kelvin, 1/picosecond, 0.004*picoseconds)
	else:
		integrator = VerletIntegrator(0.004*picoseconds)
	simulation = Simulation(openmm_topology, openmm_system, integrator)
	simulation.context.setPositions(openff_initial_positions)
	tolerance = Quantity(value=10.000000000000004, unit=kilojoule/mole)
	simulation.minimizeEnergy(maxIterations = max_iterations)
	
	# Get the minimized positions
	openff_minimized_positions: list[Vec3] = simulation.context.getState(getPositions=True).getPositions()
	minimized_positions: list[Vec3] = []

	for i in range(topology_payload.atoms_count):
		minimized_positions.append(openff_minimized_positions[topology_payload.payload_to_openff_atom[i]])

	return minimized_positions


running_simulations: dict = {
#	id<int> = stop_trigger<threading.Event>
}
def start_simulation(socket, socket_lock, simulation_id: int, parameters: PayloadSimulationParameters, topology_payload: PayloadTopologyReader, state_payload: PayloadStateReader):
	try:
		stop_trigger: threading.Event = running_simulations.get(simulation_id, None)
		stop_exists: bool = stop_trigger != None
		if stop_exists and stop_trigger.is_set():
			if running_simulations.pop(simulation_id, None) != None:
				logging.info(f"Aborted simulation while starting, step #1")
			return
		molecules: list[Molecule] = topology_payload.to_openff_molecules()
		topology = Topology.from_molecules(molecules)
		has_emitters = len(topology_payload.emitters) > 0
		forcefield = create_forcefield_for_topology(topology_payload, remove_constraints=has_emitters)
		interchange = Interchange.from_smirnoff(forcefield, topology, charge_from_molecules=molecules)
		if stop_exists and stop_trigger.is_set():
			if running_simulations.pop(simulation_id, None) != None:
				logging.info(f"Aborted simulation while starting, step #2")
			return
		openmm_system: System =interchange.to_openmm(combine_nonbonded_forces=True, add_constrained_forces=False)
		if stop_exists and stop_trigger.is_set():
			if running_simulations.pop(simulation_id, None) != None:
				logging.info(f"Aborted simulation while starting, step #3")
			return
		openff_initial_positions: list[Vec3] = []
		for i in range(len(state_payload.positions)):
			payload_atom_id = topology_payload.openff_atom_to_payload[i]
			openff_initial_positions.append(state_payload.positions[payload_atom_id])
		if header.periodic_box_size[0] < 0 or header.periodic_box_size[1] < 0 or header.periodic_box_size[2] < 0:
			openmm_system.setDefaultPeriodicBoxVectors(Vec3(float("inf"), 0, 0), Vec3(0, float("inf"), 0), Vec3(0, 0, float("inf")))
		else:
			openmm_system.setDefaultPeriodicBoxVectors(
				Vec3(header.periodic_box_size[0], 0, 0),
				Vec3(0, header.periodic_box_size[1], 0),
				Vec3(0, 0, header.periodic_box_size[2]))
		# Anchors
		bond_force: HarmonicBondForce = None
		nonbonded_force: NonbondedForce = None
		for force in openmm_system.getForces():
			if isinstance(force, HarmonicBondForce):
				bond_force = force
			if isinstance(force, NonbondedForce):
				nonbonded_force = force
		if bond_force == None:
			bond_force = HarmonicBondForce()
			openmm_system.addForce(bond_force)
		# Springs
		for anchor_id in topology_payload.anchors:
			anchor: AnchorPoint = topology_payload.anchors[anchor_id]
			if len(anchor.springs) == 0:
				continue
			anchor.openmm_particle_id = openmm_system.addParticle(0.0)
			if nonbonded_force != None:
				nonbonded_force.addParticle(0.0, 1.0, 0.0)
			pos = anchor.position
			openff_initial_positions.append(Vec3(pos[0], pos[1], pos[2]))
			for spring in anchor.springs:
				k_constant: float = spring.k_constant
				equilibrium_length: float = spring.equilibrium_length
				if nonbonded_force != None:
					nonbonded_force.addException(anchor.openmm_particle_id, spring.particle_id, 0.0, 1.0, 0.0)
				# NOTE: use of openmm_system.addConstraint() was  not possible because it doesn't support massless particles
				bond_force.addBond(anchor.openmm_particle_id, spring.particle_id, equilibrium_length, k_constant)
		# Locked atoms
		for i, atom in enumerate(topology_payload.atoms):
			if atom.is_locked:
				openff_atom_id = topology_payload.payload_to_openff_atom[i]
				lock_particle_id = openmm_system.addParticle(0.0)
				if nonbonded_force != None:
					nonbonded_force.addParticle(0.0, 1.0, 0.0)
				pos = state_payload.positions[i]
				openff_initial_positions.append(pos)
				k_constant: float = 500000.0
				equilibrium_length: float = 0.0
				if nonbonded_force != None:
					nonbonded_force.addException(lock_particle_id, openff_atom_id, 0.0, 1.0, 0.0)
				# NOTE: use of openmm_system.addConstraint() was  not possible because it doesn't support massless particles
				bond_force.addBond(lock_particle_id, openff_atom_id, equilibrium_length, k_constant)
			if atom.is_passivation_atom:
				openff_atom_id = topology_payload.payload_to_openff_atom[i]
				nonbonded_force.setParticleParameters(openff_atom_id, charge=0.0, sigma=0.0, epsilon=0.0)

		if stop_exists and stop_trigger.is_set():
			if running_simulations.pop(simulation.simulation_id, None) != None:
				logging.info(f"Aborted simulation while starting, step #4")
			return
		# Propagate the System with Langevin dynamics.
		# "Typical time steps range from 0.25 fs for systems with light nuclei (such as hydrogen), to 2 fs or greater for systems with more massive nuclei"
		# Femtosecond = 1/1000 picosecond = 1e-15 s
		temperature = parameters.temperature_in_kelvins * kelvins  # simulation temperature
		time_step = parameters.time_step_in_femtoseconds*femtosecond  # simulation timestep
		time_step_in_nanoseconds = parameters.time_step_in_femtoseconds / 1e+6
		friction = 1/picosecond  # collision rate

		# Length of the simulation.
		num_steps = parameters.total_step_count  # number of integration steps to run

		# Logging options.
		trj_freq = parameters.steps_per_report  # number of steps per written trajectory frame

		# Set up an OpenMM simulation.
		# NOTE: The original implementation of simulation was as follows:
		# ```
		# simulation = interchange.to_openmm_simulation(integrator)
		# ```
		# However, to take anchors and springs into accounts we hacked into the integrator Interchange
		# class to use a modified version of `openmm_system`
		platforms_to_test: list[Platform] = [
			None, # None will fallback to the best possible, but CUDA failed for me to
			Platform.getPlatformByName("Reference"), # Reference is a CPU fallback that should always work
		]
		simulation: Simulation = None
		integrator: Integrator = None
		for platform_candidate in platforms_to_test:
			if header.integrator == "langevin":
				integrator = LangevinIntegrator(temperature, friction, time_step)
			else:
				integrator = VerletIntegrator(time_step)
			simulation = Simulation(
				topology=topology.to_openmm(),
				system=openmm_system,
				integrator=integrator,
				platform=platform_candidate
			)
			simulation.simulation_id = simulation_id
			simulation.atoms_count = topology_payload.atoms_count
			simulation.anchors_count = len(topology_payload.anchors)
			simulation.payload_to_openff_atom = topology_payload.payload_to_openff_atom
			simulation.openff_atom_to_payload = topology_payload.openff_atom_to_payload
			simulation.time_step_in_nanoseconds = time_step_in_nanoseconds
			simulation.frame = 0

			simulation.context.setPositions(openff_initial_positions)
			if not math.isnan(simulation.context.getState(getPositions=True).getPositions()[0][0]._value):
				Quantity
				logging.info(f"Platform is '{str(simulation.context.getPlatform().getName())}'")
				break
		# Randomize the velocities from a Boltzmann distribution at a given temperature.
		simulation.context.setVelocitiesToTemperature(temperature)

		thermostat = AndersenThermostat(temperature, 1.0)
		openmm_system.addForce(thermostat)

		for emitter in topology_payload.emitters:
			# Initialize ParticleEmitter molecules
			emitter.setup(simulation, nonbonded_force, topology_payload.payload_to_openff_atom)
			if emitter.initial_delay_in_nanoseconds == 0:
				# Adjust initial velocity of any particle emitted in the frame 0
				for i in range(emitter.molecules_per_instance):
					emitter.enable_instance(i, simulation, nonbonded_force)

		# Configure publish reporter
		socket_publish_reporter = ZmqPublishReporter(simulation_id, socket, socket_lock, trj_freq)
		simulation.reporters.append(socket_publish_reporter)
		
		logs_config_file = os.path.join(os.path.dirname(__file__), "._log_enabled")
		if os.path.isfile(logs_config_file):
			# Logs enabled
			with open(logs_config_file) as f: logs_config = f.read()
			logs_location = logs_config.split("\n")[0]
			reporter_strings = logs_config.split("\n")[1]
			date_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
			report_file_name = date_time
			# Supported reporters: PDBxReporter,PDBReporter,CheckpointReporter,DCDReporter,StateDataReporter,CustomCSVReporter
			if "PDBxReporter" in reporter_strings:
				pdbx_reporter = PDBxReporter(os.path.join(logs_location, report_file_name + ".mmcif"), parameters.steps_per_report)
				simulation.reporters.append(pdbx_reporter)
			if "PDBReporter" in reporter_strings:
				pdb_reporter = PDBReporter(os.path.join(logs_location, report_file_name + ".pdb"), parameters.steps_per_report)
				simulation.reporters.append(pdb_reporter)
			if "CheckpointReporter" in reporter_strings:
				chk_reporter = CheckpointReporter(os.path.join(logs_location, report_file_name + "-state.xml"), parameters.steps_per_report, writeState=True)
				simulation.reporters.append(chk_reporter)
				chk_reporter = CheckpointReporter(os.path.join(logs_location, report_file_name + "-checkpoint.chk"), parameters.steps_per_report, writeState=False)
				simulation.reporters.append(chk_reporter)
			if "DCDReporter" in reporter_strings:
				dcd_reporter = DCDReporter(os.path.join(logs_location, report_file_name + ".dcd"), parameters.steps_per_report)
				simulation.reporters.append(dcd_reporter)
			if "StateDataReporter" in reporter_strings:
				sd_reporter = StateDataReporter(os.path.join(logs_location, report_file_name + ".csv"), parameters.steps_per_report,
						step=True, time=True, potentialEnergy=True, kineticEnergy=True, totalEnergy=True, temperature=True, volume=False, density=False,
						progress=True, remainingTime=True, speed=True, elapsedTime=False, separator=',', systemMass=None, totalSteps=num_steps)
				simulation.reporters.append(sd_reporter)
		
		if stop_exists and stop_trigger.is_set():
			if running_simulations.pop(simulation.simulation_id, None) != None:
				logging.info(f"Aborted simulation while starting, step #5")
			return
		with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
			executor.submit(thread_simulate, simulation, num_steps, topology_payload.motors_forces, topology_payload.emitters, time_step_in_nanoseconds)
	except Exception as inst:
			with socket_lock:
				socket.send_string("err:" + str(simulation_id), zmq.SNDMORE)
				if not topology is None and hasattr(topology, 'openff_atom_to_payload'):
					# Packing atom ids map topology.openff_atom_to_payload
					# It is necesary for identification of the actual problems in the model
					atom_id_buffer: bytes = b''
					for openff_atom in topology.openff_atom_to_payload.keys():
						atom_id_buffer += struct.pack("<I", openff_atom)
						atom_id_buffer += struct.pack("<I", topology.openff_atom_to_payload[openff_atom])
					socket.send(atom_id_buffer, zmq.SNDMORE)
				else:
					# Will not send IDs to remap
					socket.send(b'', zmq.SNDMORE)
				socket.send_string(f"[b]{str(inst)}[/b]", zmq.SNDMORE)
				socket.send_string("\n[b]Traceback:[/b]", zmq.SNDMORE)

				environment_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "msep.one")
				trace: list = traceback.extract_tb(inst.__traceback__)
				traceback_str = ""
				for trace_data in trace:
					full_path = trace_data[0]
					short_path = full_path.replace(__file__, "openmm_server.py")
					short_path = short_path.replace(environment_dir, "<env>")
					line = trace_data[1]
					module = trace_data[2]
					trace_line = f"\n    File [url={full_path}@{line}]{short_path}:{line}[/url], in {module}\n"
					for i in range(3, len(trace_data)):
						code = trace_data[i]
						trace_line += f"    {line-3+i}|   {code}\n"
					traceback_str += trace_line
				socket.send_string(traceback_str)
				traceback.print_exc()
				# raise inst


def thread_simulate(simulation: Simulation, num_steps, motors_forces, emitters, time_step_in_nanoseconds):
	stop_trigger: threading.Event = running_simulations.get(simulation.simulation_id, None)
	stop_exists: bool = stop_trigger != None
	nonbonded_force: NonbondedForce = None
	for force in simulation.system.getForces():
		if isinstance(force, NonbondedForce):
			nonbonded_force = force
	for step in range(num_steps):
		try:
			if stop_exists and stop_trigger.is_set():
				if running_simulations.pop(simulation.simulation_id, None) != None:
					logging.info(f"Aborted simulation on thread while running step #{step}")
				return
			for emitter in emitters:
				emitter.advance(simulation, nonbonded_force)
			for motor in motors_forces:
				motor.advance(simulation)
				
			simulation.step(1)
		except Exception as inst:
			environment_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "msep.one")
			trace: list = traceback.extract_tb(inst.__traceback__)
			traceback_str = ""
			for trace_data in trace:
				full_path = trace_data[0]
				short_path = full_path.replace(__file__, "openmm_server.py")
				short_path = short_path.replace(environment_dir, "<env>")
				line = trace_data[1]
				module = trace_data[2]
				trace_line = f"\n    File [url={full_path}@{line}]{short_path}:{line}[/url], in {module}\n"
				for i in range(3, len(trace_data)):
					code = trace_data[i]
					trace_line += f"    {line-3+i}|   {code}\n"
				traceback_str += trace_line
			logging.error(inst)
			logging.error(traceback_str)
			running_simulations.pop(simulation.simulation_id, None)
			return
	running_simulations.pop(simulation.simulation_id, None)

def import_file(payload: ImportFileRequest) -> ImportFileResponse:
	molecules: list[Molecule] = []
	if payload.extension == "pdb":
		pdbfile = app.PDBFile(payload.path)
		monomer_names = ["butanol", "cyclohexane", "ethanol", "methane", "propane", "water"]
		sdf_filepaths = [get_data_file_path(f'systems/monomers/{name}.sdf') for name in monomer_names]
		unique_molecules = [Molecule.from_file(sdf_filepath) for sdf_filepath in sdf_filepaths]
		openff_topology = Topology.from_openmm(pdbfile.topology, unique_molecules=unique_molecules)
		openff_topology.setPositions(pdbfile.getPositions())
		molecules = list(openff_topology.molecules)
	elif payload.extension.upper() in ["MOL", "SDF"]:
		from rdkit import Chem
		rdmol = Chem.MolFromMolFile(payload.path, sanitize=False, removeHs=False, strictParsing=True)
		toolkit_wrapper = RDKitToolkitWrapper()
		molecules = toolkit_wrapper.from_rdkit(rdmol, hydrogens_are_explicit=True)
	else:
		molecules = Molecule.from_file(payload.path, payload.extension, RDKitToolkitWrapper())
	if not molecules is list:
		molecules = [molecules]
	topology = Topology()
	for mol in molecules:
		topology.add_molecule(mol)
	openmm_topology = topology.to_openmm()
	positions = topology.get_positions().magnitude
	# POST PROCESS "Generate bonds"
	if payload.option_generate_bonds:
		openmm_topology.createDisulfideBonds(positions)
	# /POST PROCESS

	modeller = Modeller(openmm_topology, positions)
	if payload.option_add_hydrogens or payload.option_remove_waters:
		# POST PROCESS "Add hydrogens"
		if payload.option_add_hydrogens:
			a = modeller.addHydrogens(forcefield=None)
			logging.info(f"Add Hydrogens result: {str(a)}")

		# /POST PROCESS
		# POST PROCESS "Remo waters"
		if payload.option_remove_waters:
			b = modeller.deleteWater()
			logging.info(f"Remove Waters result: {str(b)}")
		# /POST PROCESS
		positions = modeller.positions / nanometer
		openmm_topology = modeller.topology
	bonds = list(topology.bonds)
	logging.info(f"openff has {len(bonds)} bonds, openmm has {len(list(openmm_topology.bonds()))}")
	return ImportFileResponse(openmm_topology, positions, bonds)


def prewarm_openmm_ff():
	topology = PayloadTopologyReader([], 0, 0, 0, "openff-2.1.0.offxml")
	topology.atoms_count = 3
	topology.bonds_count = 2
	topology.atoms = [
		AtomData(element=8, hybridization=0),
		AtomData(element=1, hybridization=0),
		AtomData(element=1, hybridization=0)
	]
	topology.bonds = [
		(0, 1, 1),
		(0, 2, 1)
	]
	state = PayloadStateReader([], 0, 0)
	state.atoms_count = 3
	state.positions = [
		Vec3(0.0, 0.0, 0.0),
		Vec3(1.0, 1.0, 0.0),
		Vec3(-1.0, 0.0, 0.0)
	]
	new_state: list = minimize_energy(None, topology, state, 300)
	if DETAILED_LOGS:
		logging.info(f"prewarmed openmm/ff relaxating a water molecule.\n\tpositions={str(new_state)}")


# Kill openmm if msep has died.
pid_check_frequency = 3

def is_process_running_on_windows(in_pid):
	try:
		output = subprocess.check_output(['tasklist', '/fi', f'PID eq {in_pid}'])
		return f"{in_pid}" in output.decode()
	except subprocess.CalledProcessError:
		# If tasklist command fails (e.g., command not found), return False
		return False


def pid_check_threaded_loop_on_windows(in_openmm_pid, in_msep_pid):
	while True:
		if not is_process_running_on_windows(in_msep_pid):
			subprocess.Popen(f"taskkill /F /PID {in_openmm_pid}")
		time.sleep(pid_check_frequency)


def start_monitoring_msep():
	openmm_pid = os.getpid()
	msep_pid = ""
	pid_found = False
	for arg in sys.argv:
		if arg[0:13] == "--ipc-socket=":
			msep_pid = arg[13:]
			pid_found = True
	if not pid_found:
		logging.warning(f"PID of MSEPone not found. Server is running in DEBUG socket. Will not monitor to close server.")
		return
	pattern = r'\d+$'
	match = re.search(pattern, msep_pid)
	msep_pid = match.group()
	# Yes, win32 will work with 64 Windows, the name is such for historical reasons.
	if platform == "win32":
		loop_thread = threading.Thread(target=pid_check_threaded_loop_on_windows, args=(openmm_pid, msep_pid))
		# We need this so that thread is automatically killed with the app so it doesn't hang on exit.
		loop_thread.daemon = True
		loop_thread.start()
	else:
		bash_code = f'''
#!/bin/bash

while true
do
	if ! ps -p {msep_pid} > /dev/null 2>&1
	then
		kill -9 {openmm_pid}
		break
	fi
	sleep {pid_check_frequency}
done

'''
		process = subprocess.Popen(bash_code, shell=True, executable='/bin/bash', \
						stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, \
						stderr=subprocess.DEVNULL)
# End Kill openmm if msep has died.


if __name__ == '__main__':
	apply_all_patches()
	start_monitoring_msep()
	prewarm_openmm_ff()
	DEFAULT_SOCKET_NAME: str = "msep-one-socket"
	ipc_socket: str = ""
	for arg in sys.argv:
		if arg[0:13] == "--ipc-socket=":
			ipc_socket = "ipc://" + arg[13:]
	context = zmq.Context(2)
	socket = context.socket(zmq.REP)
	socket_publish_simulation = context.socket(zmq.PUB)
	socket_publick_lock = threading.Lock()

	address = ipc_socket
	if ipc_socket == "":
			tmp_path = tempfile.gettempdir()
			tmp_path = os.path.join(tmp_path, DEFAULT_SOCKET_NAME)
			address = "ipc://" + tmp_path
	socket.bind(address)
	socket_publish_simulation.bind(address + "-subscription")
	logging.info(f"Listening to IPC socket ({address}, {address}-subscription)")

	while True:
		try:
			request_type = socket.recv()
			match request_type:
				case b"Relax":
					logging.info(f"Server received a Relax request")
					temperature_bytes = socket.recv()
					temperature_in_kelvins: float = struct.unpack('d', temperature_bytes)[0]
					forcefield_list: str = socket.recv_string()
					header_bytes: bytes = socket.recv()
					header = PayloadHeaderReader(header_bytes)
					logging.info(f"Header: atoms_count={str(header.atoms_count)}, bonds_count={header.bonds_count}")
					topology_bytes: bytes = socket.recv()
					topology = PayloadTopologyReader(topology_bytes, header.molecules_count, header.atoms_count, header.bonds_count, forcefield_list)
					atoms_str = "[" + ", ".join(periodic_table_symbols[item.element] for item in topology.atoms) + "]"
					if DETAILED_LOGS:
						logging.info(f"Topology: atoms={atoms_str} bonds={topology.bonds}")

					# pregenerate openff molecules
					topology.to_openff_molecules()
					state_bytes: bytes = socket.recv()
					state = PayloadStateReader(state_bytes, header.atoms_count, header.passivated_atoms_count)
					if DETAILED_LOGS:
						logging.info(f"state: positions={str(state.positions)}")

					# Collect motors parameters
					for m in range(header.virtual_objects_count):
						json_object: dict = json.loads(socket.recv_string())
						topology.add_virtual_object(json_object)
					minimized_positions = minimize_energy(header, topology, state, temperature_in_kelvins, max_iterations=500)
					new_state_buffer: bytes = b''
					for pos in minimized_positions:
						for i in range(3):
							raw = pos[i] / nanometer
							new_state_buffer += struct.pack("d", raw)
					socket.send(new_state_buffer)

				case b'Simulate':
					logging.info(f"Server received a Simulation Start request")
					id_bytes: bytes = socket.recv()
					simulation_id: int = struct.unpack('<q', id_bytes)[0]
					parameters_bytes: bytes = socket.recv()
					parameters = PayloadSimulationParameters(parameters_bytes)
					forcefield_list: str = socket.recv_string()
					header_bytes: bytes = socket.recv()
					header = PayloadHeaderReader(header_bytes)
					logging.info(f"Header: atoms_count={str(header.atoms_count)}, bonds_count={header.bonds_count}")
					topology_bytes: bytes = socket.recv()
					topology = PayloadTopologyReader(topology_bytes, header.molecules_count, header.atoms_count, header.bonds_count, forcefield_list)
					atoms_str = "[" + ", ".join(periodic_table_symbols[item.element] for item in topology.atoms) + "]"
					if DETAILED_LOGS:
						logging.info(f"Topology: atoms={atoms_str} bonds={topology.bonds}")
					# pregenerate openff molecules
					topology.to_openff_molecules()
					state_bytes: bytes = socket.recv()
					state = PayloadStateReader(state_bytes, header.atoms_count, header.passivated_atoms_count)
					if DETAILED_LOGS:
						logging.info(f"state: positions={str(state.positions)}")
					# Collect motors parameters
					for m in range(header.virtual_objects_count):
						json_string: str = socket.recv_string()
						json_object: dict = json.loads(json_string)
						topology.add_virtual_object(json_object)
					socket.send(b'Running')
					running_simulations[simulation_id] = threading.Event()
					threading.Thread(target=start_simulation, args=(socket_publish_simulation, socket_publick_lock, simulation_id, parameters, topology, state)).start()
				case b'AbortSimulation':
					id_bytes: bytes = socket.recv()
					simulation_id: int = struct.unpack('<q', id_bytes)[0]
					stop_trigger: threading.Event = running_simulations.get(simulation_id, None)
					if stop_trigger != None and not stop_trigger.is_set():
						logging.info(f"Server received an Abort Simulation request")
						stop_trigger.set()
					socket.send(b'ack')
				case b'Import File':
					path = socket.recv_string()
					payload = ImportFileRequest(path)
					while socket.getsockopt(zmq.RCVMORE):
						option = socket.recv_string()
						payload.process_option(option)
					response: ImportFileResponse = import_file(payload)
					# First frame are atomic_numbers as uint8
					atomic_numbers_buffer: bytes = b''
					for atom in response.openmm_topology.atoms():
						atomic_numbers_buffer += struct.pack("B", atom.element.atomic_number)
					# Second frame are atoms positions as 3 consecutive doubles
					positions_buffer: bytes = b''
					logging.info(f"PoSiTiOnS: {response.positions}")
					for pos in response.positions:
						for i in range(3):
							positions_buffer += struct.pack("d", pos[i])
					# Third frame are bonds represented as 2 atom_ids(uint32) + byte order (uint8)
					bonds_buffer: bytes = b''
					logging.info(f"BONDS: {str(response.bonds)}")
					for bond in response.bonds:
						bonds_buffer += struct.pack("<I", bond.atom1.molecule_atom_index)
						bonds_buffer += struct.pack("<I", bond.atom2.molecule_atom_index)
						bonds_buffer += struct.pack("B", bond.bond_order)
					socket.send(atomic_numbers_buffer, zmq.SNDMORE)
					socket.send(positions_buffer, zmq.SNDMORE)
					socket.send(bonds_buffer)
				case b'Export File':
					path = socket.recv_string()
					logging.info(f"Exporting file: {path}")
					forcefield_list: str = socket.recv_string()
					header_bytes: bytes = socket.recv()
					header = PayloadHeaderReader(header_bytes)
					topology_bytes: bytes = socket.recv()
					topology_payload = PayloadTopologyReader(topology_bytes, header.molecules_count, header.atoms_count, header.bonds_count, forcefield_list)
					molecules: list[Molecule] = topology_payload.to_openff_molecules()
					topology = Topology.from_molecules(molecules)
					state_bytes: bytes = socket.recv()
					state = PayloadStateReader(state_bytes, header.atoms_count, header.passivated_atoms_count)
					openff_positions: list[Vec3] = []
					for i in range(len(state.positions)):
						payload_atom_id = topology_payload.openff_atom_to_payload[i]
						position = state.positions[payload_atom_id] * nanometer
						openff_positions.append(position.value_in_unit(angstrom))
					output_file = open(path, 'w')
					PDBFile.writeFile(topology.to_openmm(), openff_positions, output_file)
					output_file.close()
					socket.send_string("SUCCESS")
				case b"GetProcessID":
					pid: int = os.getpid()
					pid_buffer: bytes = b''
					pid_buffer += struct.pack("<Q", pid)
					socket.send(pid_buffer)
				case b"Quit":
					for simulation_id in running_simulations.keys():
						stop_trigger: threading.Event = running_simulations.get(simulation_id, None)
						if stop_trigger != None and not stop_trigger.isSet():
							stop_trigger.set()
					socket.send_string("ack")
					sys.exit(0)
				case _:
					raise Exception(f"Unknown request instruction: {request_type}")
		except Exception as inst:
			while socket.getsockopt(zmq.RCVMORE):
				discard: bytes = socket.recv()
				logging.error(f"\tDISCARDED BYTES ON ERROR:{str(discard)}")
			socket.send(b"err", zmq.SNDMORE)
			if topology != None and hasattr(topology, 'openff_atom_to_payload'):
				# Packing atom ids map topology.openff_atom_to_payload
				# It is necesary for identification of the actual problems in the model
				atom_id_buffer: bytes = b''
				for openff_atom in topology.openff_atom_to_payload.keys():
					atom_id_buffer += struct.pack("<I", openff_atom)
					atom_id_buffer += struct.pack("<I", topology.openff_atom_to_payload[openff_atom])
				socket.send(atom_id_buffer, zmq.SNDMORE)
			else:
				# Will not send IDs to remap
				socket.send(b'', zmq.SNDMORE)
			socket.send_string(f"[b]{str(inst)}[/b]", zmq.SNDMORE)
			socket.send_string("\n[b]Traceback:[/b]", zmq.SNDMORE)

			environment_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "msep.one")
			trace: list = traceback.extract_tb(inst.__traceback__)
			traceback_str = ""
			for trace_data in trace:
				full_path = trace_data[0]
				short_path = full_path.replace(__file__, "openmm_server.py")
				short_path = short_path.replace(environment_dir, "<env>")
				line = trace_data[1]
				module = trace_data[2]
				trace_line = f"\n    File [url={full_path}@{line}]{short_path}:{line}[/url], in {module}\n"
				for i in range(3, len(trace_data)):
					code = trace_data[i]
					trace_line += f"    {line-3+i}|   {code}\n"
				traceback_str += trace_line
			socket.send_string(traceback_str)
			traceback.print_exc()
			# raise inst
