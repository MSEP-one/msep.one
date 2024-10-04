#include "lightning_memory_mapped_database.h"
#include <iostream>
#include "core/variant/variant_utility.h"
#include "core/io/marshalls.h"
#include <capnp/serialize-packed.h>
#include "kj/array.h"


using namespace godot;


//////////
// AtomSnapshot
AtomSnapshot::AtomSnapshot() {

}

int AtomSnapshot::get_type() const {
	return type;
}

Vector3 AtomSnapshot::get_position() const {
	return position;
}

void AtomSnapshot::set_position(const Vector3 &in_position){
	position = in_position;
}

void AtomSnapshot::set_type(const int in_type){
	type = in_type;
}

void AtomSnapshot::set_bonds(const PackedInt32Array &in_bonds) {
	bonds = in_bonds;
}

PackedInt32Array AtomSnapshot::get_bonds() const {
	return bonds;
}

void AtomSnapshot::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_type"), &AtomSnapshot::get_type);
	ClassDB::bind_method(D_METHOD("set_type", "element_type"), &AtomSnapshot::set_type);
	ClassDB::bind_method(D_METHOD("get_position"), &AtomSnapshot::get_position);
	ClassDB::bind_method(D_METHOD("set_position", "position"), &AtomSnapshot::set_position);
	ClassDB::bind_method(D_METHOD("get_bonds"), &AtomSnapshot::get_bonds);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "type"), "set_type", "get_type");
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "position"), "set_position", "get_position");
}

AtomSnapshot::~AtomSnapshot(){

}

//////////
// BondSnapshot
BondSnapshot::BondSnapshot() {

}

void BondSnapshot::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_first_atom"), &BondSnapshot::get_first_atom);
	ClassDB::bind_method(D_METHOD("set_first_atom", "atom_id"), &BondSnapshot::set_first_atom);
	ClassDB::bind_method(D_METHOD("get_second_atom"), &BondSnapshot::get_second_atom);
	ClassDB::bind_method(D_METHOD("set_second_atom", "atom_id"), &BondSnapshot::set_second_atom);
	ClassDB::bind_method(D_METHOD("set_order", "order"), &BondSnapshot::set_order);
	ClassDB::bind_method(D_METHOD("get_order"), &BondSnapshot::get_order);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "first_atom"), "set_first_atom", "get_first_atom");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "second_atom"), "set_second_atom", "get_second_atom");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "order"), "set_order", "get_order");
};

BondSnapshot::~BondSnapshot(){

}

int BondSnapshot::get_first_atom() const {
	return first_atom_id;
}

void BondSnapshot::set_first_atom(const int in_id) {
	first_atom_id = in_id;
}


int BondSnapshot::get_second_atom() const {
	return second_atom_id;
}

void BondSnapshot::set_second_atom(const int in_id) {
	second_atom_id = in_id;
}

int BondSnapshot::get_order() const {
	return order;
}

void BondSnapshot::set_order(const int in_order){
	order = in_order;
}

//////////
// LMDataBase
const int LightningMemoryMappedDatabase::DB_VERSION;
const int LightningMemoryMappedDatabase::DB_INFO_ATOM_COUNTER;
const int LightningMemoryMappedDatabase::DB_INFO_BOND_COUNTER;
const int LightningMemoryMappedDatabase::DB_INFO_SCHEMA_ID;

#define GUARD_BOOL(in_code) do { if (in_code != MDB_SUCCESS) { ERR_FAIL_V_MSG(false, mdb_strerror(in_code));} } while (0)
#define GUARD(in_code) do { if (in_code != MDB_SUCCESS) { ERR_FAIL_MSG(mdb_strerror(in_code));} } while (0)

LightningMemoryMappedDatabase::LightningMemoryMappedDatabase() {

}

LightningMemoryMappedDatabase::~LightningMemoryMappedDatabase() {
	if (is_initialized){
		cleanup();
		mdb_close(env, db_handle);
		mdb_close(env, db_info);
	}

	for (HashMap<int, MDB_dbi>::Iterator I = opened_atoms_databases.begin(); I; ++I) {
		int molecule_id = I->key;
		mdb_close(env, opened_atoms_databases[molecule_id]);
	}

	for (HashMap<int, MDB_dbi>::Iterator I = opened_bonds_databases.begin(); I; ++I) {
		int molecule_id = I->key;
		mdb_close(env, opened_bonds_databases[molecule_id]);
	}
}

bool LightningMemoryMappedDatabase::initialize(const String &in_directory_path) {

	GUARD_BOOL(mdb_env_create(&env));

	mdb_env_set_maxdbs(env, MAX_DBS);

	CharString chars = in_directory_path.utf8();
	const char *path = chars.get_data();
	GUARD_BOOL(mdb_env_open(env, path, MDB_FIXEDMAP, 0664));

	MDB_txn *open_dbs_transation_handle;
	GUARD_BOOL(mdb_txn_begin(env, NULL, 0, &open_dbs_transation_handle));
	
	int main_db_open_return_code = mdb_open(open_dbs_transation_handle, NULL, 0, &db_handle);
	if (main_db_open_return_code != MDB_SUCCESS) {
		mdb_close(env, db_handle);
		ERR_FAIL_COND_V(false, mdb_strerror(main_db_open_return_code));
	}

	bool db_info_init_success = init_db_info(open_dbs_transation_handle);
	if(!db_info_init_success) {
		mdb_close(env, db_handle);
		mdb_close(env, db_info);
		ERR_FAIL_COND_V(false, "Failed to initialize db_info");
	}

	int db_molecule_open_return_code = mdb_open(open_dbs_transation_handle, "db_molecule", MDB_INTEGERKEY | MDB_CREATE, &db_molecule);
	if (db_molecule_open_return_code != MDB_SUCCESS) {
		mdb_close(env, db_handle);
		mdb_close(env, db_info);
		ERR_FAIL_COND_V(false, mdb_strerror(db_molecule_open_return_code));
	}

	int commit_return_code = mdb_txn_commit(open_dbs_transation_handle);
	if (commit_return_code != MDB_SUCCESS){
		mdb_close(env, db_handle);
		mdb_close(env, db_info);
		mdb_close(env, db_handle);
		ERR_FAIL_COND_V(false, mdb_strerror(commit_return_code));
	}
	
	is_initialized = true;
	start();
	cleanup();
	return true;
}

int LightningMemoryMappedDatabase::create_molecule() {
	ERR_FAIL_COND_V(!is_initialized, -1);
	ERR_FAIL_COND_V(!transaction_in_progress, -1);

	int molecule_id = next_molecule_id;
	next_molecule_id = molecule_id + 1;
	

	const auto DB_ATOM_POSTFIX = "_db_atom";
	const auto DB_BOND_POSTFIX = "_db_bond";
	String atom_db_name = itos(molecule_id) + DB_ATOM_POSTFIX;
	String bond_db_name = itos(molecule_id) + DB_BOND_POSTFIX;
	::capnp::MallocMessageBuilder molecule_builder;
  	Molecule::Builder molecule = molecule_builder.initRoot<Molecule>();
	molecule.setAtomDatabaseID(atom_db_name.utf8().get_data());
	molecule.setBondDatabaseID(bond_db_name.utf8().get_data());
	molecule.setNextAtomID(0);
	molecule.setNextBondID(0);

	put_builder_schema_into_db(molecule_id, molecule_builder, ongoing_transation_handle, db_molecule);
	return molecule_id;
}

bool LightningMemoryMappedDatabase::remove_molecule(const int in_molecule_id) {
	ERR_FAIL_COND_V(!is_initialized, false);
	ERR_FAIL_COND_V(!transaction_in_progress, false);
	auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
	capnp::FlatArrayMessageReader schema_byte_reader(data_array);
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);
	mdb_drop(ongoing_transation_handle, atom_db, 1);
	mdb_drop(ongoing_transation_handle, bond_db, 1);
	opened_atoms_databases.erase(in_molecule_id);
	opened_bonds_databases.erase(in_molecule_id);

	MDB_val molecule_key;
	molecule_key.mv_data = (void*)&in_molecule_id;
	molecule_key.mv_size = sizeof(int);
	GUARD_BOOL(mdb_del(ongoing_transation_handle, db_molecule, &molecule_key, NULL));
	return true;
}

bool LightningMemoryMappedDatabase::has_molecule(const int in_molecule_id) {
	ERR_FAIL_COND_V(!is_initialized, false);
	ERR_FAIL_COND_V(!transaction_in_progress, false);

	MDB_val molecule_key, molecule_data;
	molecule_key.mv_data = (void*)&in_molecule_id;
	molecule_key.mv_size = sizeof(int);
	int get_code = mdb_get(ongoing_transation_handle, db_molecule, &molecule_key, &molecule_data);
	if (get_code == MDB_NOTFOUND){
		return false;
	} else if (get_code != MDB_SUCCESS) {
		ERR_FAIL_V_MSG(false, mdb_strerror(get_code));
	}

	return true;
}

PackedInt32Array LightningMemoryMappedDatabase::get_molecules() {
	PackedInt32Array molecules;
	MDB_val key, value;
    MDB_cursor *cursor;
    mdb_cursor_open(ongoing_transation_handle, db_molecule, &cursor);
	while ((mdb_cursor_get(cursor, &key, &value, MDB_NEXT)) == 0) {
		int int_key = *(int *)key.mv_data;
		molecules.push_back(int_key);
    }
	return molecules;
}

int LightningMemoryMappedDatabase::create_atom(const int in_molecule_id, const int in_element_type, const Vector3 &in_position) {
	ERR_FAIL_COND_V(!is_initialized, -1);
	ERR_FAIL_COND_V(!transaction_in_progress, -1);

	::capnp::MallocMessageBuilder atom_builder;
  	Atom::Builder new_atom = atom_builder.initRoot<Atom>();
	new_atom.setPositionX(in_position.x);
	new_atom.setPositionY(in_position.y);
	new_atom.setPositionZ(in_position.z);
	new_atom.setElementType(in_element_type);

	//
	auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
	capnp::FlatArrayMessageReader schema_byte_reader(data_array);
	auto molecule_data = schema_byte_reader.getRoot<Molecule>();
	int atom_id = molecule_data.getNextAtomID();
	put_molecule_into_db(in_molecule_id, atom_id + 1, molecule_data.getNextBondID(), molecule_data, ongoing_transation_handle, db_molecule);
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);

	put_builder_schema_into_db(atom_id, atom_builder, ongoing_transation_handle, atom_db);
	return atom_id;
}

void LightningMemoryMappedDatabase::mark_atom_as_removed(const int in_molecule_id, const int in_atom_id) {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(!transaction_in_progress);

	MDB_dbi market_for_removal_atom_db = get_marked_for_removal_atoms_db(in_molecule_id);
	uint32_t val = 0;
	MDB_val atom_key, atom_data;
	atom_key.mv_data = (void*)&in_atom_id;
	atom_key.mv_size = sizeof(int);
	atom_data.mv_size = sizeof(uint32_t);
	atom_data.mv_data = (void*)&val;
	int put_code = mdb_put(ongoing_transation_handle, market_for_removal_atom_db, &atom_key, &atom_data, 0);
	if (put_code != MDB_SUCCESS) {
		ERR_FAIL_MSG(mdb_strerror(put_code));
	}

	// correct bond states
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	auto atom_array = fetch_capnpro_schema(ongoing_transation_handle, atom_db, in_atom_id);
	capnp::FlatArrayMessageReader schema_byte_atom_reader(atom_array);
	auto atom_read_data = schema_byte_atom_reader.getRoot<Atom>();
	::capnp::List< ::uint32_t,  ::capnp::Kind::PRIMITIVE>::Reader bonds = atom_read_data.getBonds();
	for (::uint32_t bond : bonds) {
		if(! is_bond_marked_to_remove(in_molecule_id, bond)){
			mark_bond_as_removed(in_molecule_id, bond);
		}
	}
}

bool LightningMemoryMappedDatabase::unmark_atom_removal(const int in_molecule_id, const int in_atom_id) {
	ERR_FAIL_COND_V(!is_initialized, false);
	ERR_FAIL_COND_V(!transaction_in_progress, false);
	ERR_FAIL_COND_V(!is_atom_marked_to_remove(in_molecule_id, in_atom_id), false);

	MDB_dbi market_for_removal_atom_db = get_marked_for_removal_atoms_db(in_molecule_id);
	MDB_val atom_key;
	atom_key.mv_data = (void*)&in_atom_id;
	atom_key.mv_size = sizeof(int);
	int del_code = mdb_del(ongoing_transation_handle, market_for_removal_atom_db, &atom_key, NULL);
	bool success = del_code == 0;
	ERR_FAIL_COND_V(!success, false);
	return success;
}

bool LightningMemoryMappedDatabase::is_atom_marked_to_remove(const int in_molecule_id, const int in_atom_id) {
	ERR_FAIL_COND_V(!is_initialized, false);
	ERR_FAIL_COND_V(!transaction_in_progress, false);

	MDB_dbi market_for_removal_atom_db = get_marked_for_removal_atoms_db(in_molecule_id);
	MDB_val atom_key, atom_data;
	atom_key.mv_data = (void*)&in_atom_id;
	atom_key.mv_size = sizeof(int);
	int get_code = mdb_get(ongoing_transation_handle, market_for_removal_atom_db, &atom_key, &atom_data);
	if (get_code == MDB_NOTFOUND){
		return false;
	} else if (get_code != MDB_SUCCESS) {
		ERR_FAIL_V_MSG(false, mdb_strerror(get_code));
	}
	return true;
}

bool LightningMemoryMappedDatabase::remove_atom(const int in_molecule_id, const int in_atom_id) {
	ERR_FAIL_COND_V(!is_initialized, false);
	ERR_FAIL_COND_V(!transaction_in_progress, false);
	auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
	capnp::FlatArrayMessageReader schema_byte_reader(data_array);
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	MDB_val atom_key;
	atom_key.mv_data = (void*)&in_atom_id;
	atom_key.mv_size = sizeof(int);
	GUARD_BOOL(mdb_del(ongoing_transation_handle, atom_db, &atom_key, NULL));
	return true;
}

bool LightningMemoryMappedDatabase::has_atom(const int in_molecule_id, const int in_atom_id) {
	ERR_FAIL_COND_V(!is_initialized, false);
	ERR_FAIL_COND_V(!transaction_in_progress, false);
	if (!has_molecule(in_molecule_id)) {
		return false;
	}
	if(is_atom_marked_to_remove(in_molecule_id, in_atom_id)){
		return false;
	}

	auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
	capnp::FlatArrayMessageReader schema_byte_reader(data_array);
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);

	MDB_val atom_key, atom_data;
	atom_key.mv_data = (void*)&in_atom_id;
	atom_key.mv_size = sizeof(int);
	int get_code = mdb_get(ongoing_transation_handle, atom_db, &atom_key, &atom_data); //TODO
	if (get_code == MDB_NOTFOUND){
		return false;
	} else if (get_code != MDB_SUCCESS) {
		ERR_FAIL_V_MSG(false, mdb_strerror(get_code));
	}

	return true;
}

AtomSnapshot *LightningMemoryMappedDatabase::get_atom(const int in_molecule_id, const int in_atom_id) {
	ERR_FAIL_COND_V(!is_initialized, nullptr);
	ERR_FAIL_COND_V(!transaction_in_progress, nullptr);
	if (!has_atom(in_molecule_id, in_atom_id)) {
		return nullptr;
	}
	
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	auto atom_array = fetch_capnpro_schema(ongoing_transation_handle, atom_db, in_atom_id);
	capnp::FlatArrayMessageReader schema_byte_atom_reader(atom_array);
	auto atom_data = schema_byte_atom_reader.getRoot<Atom>();

	AtomSnapshot *atom = memnew(AtomSnapshot);
	atom->set_position(Vector3(atom_data.getPositionX(), atom_data.getPositionY(), atom_data.getPositionZ()));
	atom->set_type(atom_data.getElementType());
	PackedInt32Array atom_bonds;
	::capnp::List< ::uint32_t,  ::capnp::Kind::PRIMITIVE>::Reader bonds = atom_data.getBonds();
	for (auto bond : bonds) {
		ERR_FAIL_COND_V_MSG(is_bond_marked_to_remove(in_molecule_id, bond), nullptr, "Atom has non existing bonds!");
		atom_bonds.push_back(bond);
	}
	atom->set_bonds(atom_bonds);

	return atom;
}

void LightningMemoryMappedDatabase::set_atom_data(const int in_molecule_id, const int in_atom_id, const AtomSnapshot *_data) {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(!transaction_in_progress);
	put_atom_data(in_molecule_id, in_atom_id, _data, ongoing_transation_handle);
}

int LightningMemoryMappedDatabase::get_atom_count(const int in_molecule_id) {
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	MDB_stat atom_stats;
	mdb_stat(ongoing_transation_handle, atom_db, &atom_stats);
	MDB_dbi removed_atom_db = get_marked_for_removal_atoms_db(in_molecule_id);
	MDB_stat removed_atom_stats;
	mdb_stat(ongoing_transation_handle, removed_atom_db, &removed_atom_stats);
	return atom_stats.ms_entries - removed_atom_stats.ms_entries;
}

PackedInt32Array LightningMemoryMappedDatabase::get_atoms(const int in_molecule_id) {
	PackedInt32Array atoms;
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	MDB_val key,value;
    MDB_cursor *cursor;
    mdb_cursor_open(ongoing_transation_handle, atom_db, &cursor);
	while ((mdb_cursor_get(cursor, &key, &value, MDB_NEXT)) == 0) {
		int int_key = *(int *)key.mv_data;
		if(is_atom_marked_to_remove(in_molecule_id, int_key)){
			continue;
		}
		atoms.push_back(int_key);
    }
	return atoms;
}

int LightningMemoryMappedDatabase::create_bond(const int in_molecule_id, const int in_first_atom, const int in_second_atom, const int in_order) {
	ERR_FAIL_COND_V(!is_initialized, -1);
	ERR_FAIL_COND_V(!transaction_in_progress, -1);

	::capnp::MallocMessageBuilder bond_builder;
  	Bond::Builder new_bond = bond_builder.initRoot<Bond>();
	new_bond.setFirstAtom(in_first_atom);
	new_bond.setSecondAtom(in_second_atom);
	new_bond.setOrder(in_order);
	
	auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
	capnp::FlatArrayMessageReader schema_byte_reader(data_array);
	auto molecule_data = schema_byte_reader.getRoot<Molecule>();
	int bond_id = molecule_data.getNextBondID();
	put_molecule_into_db(in_molecule_id, molecule_data.getNextAtomID(), bond_id + 1, molecule_data, ongoing_transation_handle, db_molecule);
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);

	put_builder_schema_into_db(bond_id, bond_builder, ongoing_transation_handle, bond_db);

	atom_new_bond_relation(in_molecule_id, in_first_atom, bond_id);
	atom_new_bond_relation(in_molecule_id, in_second_atom, bond_id);
	return bond_id;
}

bool LightningMemoryMappedDatabase::has_bond(const int in_molecule_id, const int in_bond_id) {
	ERR_FAIL_COND_V(!is_initialized, false);
	ERR_FAIL_COND_V(!transaction_in_progress, false);
	if (!has_molecule(in_molecule_id)) {
		return false;
	}
	if(is_bond_marked_to_remove(in_molecule_id, in_bond_id)){
		return false;
	}

	auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
	capnp::FlatArrayMessageReader schema_byte_reader(data_array);
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);

	MDB_val bond_key, bond_data;
	bond_key.mv_data = (void*)&in_bond_id;
	bond_key.mv_size = sizeof(int);
	int get_code = mdb_get(ongoing_transation_handle, bond_db, &bond_key, &bond_data);
	if (get_code == MDB_NOTFOUND) {
		return false;
	} else if (get_code != MDB_SUCCESS) {
		ERR_FAIL_V_MSG(false, mdb_strerror(get_code));
	}
	return true;
}

BondSnapshot *LightningMemoryMappedDatabase::get_bond(const int in_molecule_id, const int in_bond_id) {
	ERR_FAIL_COND_V(!is_initialized, nullptr);
	ERR_FAIL_COND_V(!transaction_in_progress, nullptr);
	if (!has_bond(in_molecule_id, in_bond_id)) {
		return nullptr;
	}

	auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
	capnp::FlatArrayMessageReader schema_byte_reader(data_array);
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);

	auto bond_array = fetch_capnpro_schema(ongoing_transation_handle, bond_db, in_bond_id);
	capnp::FlatArrayMessageReader schema_bond_byte_reader(bond_array);
	auto bond_data = schema_bond_byte_reader.getRoot<Bond>();
	BondSnapshot *bond = memnew(BondSnapshot);
	bond->set_first_atom(bond_data.getFirstAtom());
	bond->set_second_atom(bond_data.getSecondAtom());
	bond->set_order(bond_data.getOrder());
	return bond;
}

void LightningMemoryMappedDatabase::set_bond_data(const int in_molecule_id, const int in_bond_id, const BondSnapshot *_data) {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(!transaction_in_progress);
	put_bond_data(in_molecule_id, in_bond_id, _data, ongoing_transation_handle);
}

bool LightningMemoryMappedDatabase::remove_bond(const int in_molecule_id, const int in_bond_id) {
	ERR_FAIL_COND_V(!is_initialized, false);
	ERR_FAIL_COND_V(!transaction_in_progress, false);
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);
	MDB_val bond_key;
	bond_key.mv_data = (void*)&in_bond_id;
	bond_key.mv_size = sizeof(int);
	GUARD_BOOL(mdb_del(ongoing_transation_handle, bond_db, &bond_key, NULL));
	return true;
}

void LightningMemoryMappedDatabase::mark_bond_as_removed(const int in_molecule_id, const int in_bond_id) {
    ERR_FAIL_COND(!is_initialized);
    ERR_FAIL_COND(!transaction_in_progress);

    MDB_dbi marked_for_removal_bond_db = get_marked_for_removal_bonds_db(in_molecule_id);
    uint32_t val = 0;
    MDB_val bond_key, bond_removal_data;
    bond_key.mv_data = (void*)&in_bond_id;
    bond_key.mv_size = sizeof(int);
    bond_removal_data.mv_size = sizeof(uint32_t);
    bond_removal_data.mv_data = (void*)&val;
    int put_code = mdb_put(ongoing_transation_handle, marked_for_removal_bond_db, &bond_key, &bond_removal_data, 0);
    if (put_code != MDB_SUCCESS) {
        ERR_FAIL_MSG(mdb_strerror(put_code));
		return;
    }

	// correct atom states
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);
	auto bond_data_array = fetch_capnpro_schema(ongoing_transation_handle, bond_db, in_bond_id);
	capnp::FlatArrayMessageReader schema_bond_byte_reader(bond_data_array);
	auto bond_data = schema_bond_byte_reader.getRoot<Bond>();
	atom_remove_bond_relation(in_molecule_id, bond_data.getFirstAtom(), in_bond_id);
	atom_remove_bond_relation(in_molecule_id, bond_data.getSecondAtom(), in_bond_id);
}

bool LightningMemoryMappedDatabase::unmark_bond_removal(const int in_molecule_id, const int in_bond_id) {
    ERR_FAIL_COND_V(!is_initialized, false);
    ERR_FAIL_COND_V(!transaction_in_progress, false);
    ERR_FAIL_COND_V(!is_bond_marked_to_remove(in_molecule_id, in_bond_id), false);

    MDB_dbi marked_for_removal_bond_db = get_marked_for_removal_bonds_db(in_molecule_id);
    MDB_val bond_key;
    bond_key.mv_data = (void*)&in_bond_id;
    bond_key.mv_size = sizeof(int);
    GUARD_BOOL(mdb_del(ongoing_transation_handle, marked_for_removal_bond_db, &bond_key, NULL));

	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);
	auto bond_array = fetch_capnpro_schema(ongoing_transation_handle, bond_db, in_bond_id);
	capnp::FlatArrayMessageReader schema_bond_byte_reader(bond_array);
	auto bond_data = schema_bond_byte_reader.getRoot<Bond>();
	atom_new_bond_relation(in_molecule_id, bond_data.getFirstAtom(), in_bond_id);
	atom_new_bond_relation(in_molecule_id, bond_data.getSecondAtom(), in_bond_id);

    return true;
}

bool LightningMemoryMappedDatabase::is_bond_marked_to_remove(const int in_molecule_id, const int in_bond_id) {
    ERR_FAIL_COND_V(!is_initialized, false);
    ERR_FAIL_COND_V(!transaction_in_progress, false);

    MDB_dbi marked_for_removal_bond_db = get_marked_for_removal_bonds_db(in_molecule_id);
    MDB_val bond_key, bond_data;
    bond_key.mv_data = (void*)&in_bond_id;
    bond_key.mv_size = sizeof(int);
    int get_code = mdb_get(ongoing_transation_handle, marked_for_removal_bond_db, &bond_key, &bond_data);
    if (get_code == MDB_NOTFOUND){
        return false;
    } else if (get_code != MDB_SUCCESS) {
        ERR_FAIL_V_MSG(false, mdb_strerror(get_code));
    }
    return true;
}

int LightningMemoryMappedDatabase::get_bond_count(const int in_molecule_id) {
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);
	MDB_stat stats;
	mdb_stat(ongoing_transation_handle, bond_db, &stats);
	MDB_dbi removed_bond_db = get_marked_for_removal_bonds_db(in_molecule_id);
	MDB_stat removed_bond_stats;
	mdb_stat(ongoing_transation_handle, removed_bond_db, &removed_bond_stats);
	return stats.ms_entries - removed_bond_stats.ms_entries;
}

PackedInt32Array LightningMemoryMappedDatabase::get_all_bonds(const int in_molecule_id) {
	PackedInt32Array bonds;
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);
	MDB_val key,value;
    MDB_cursor *cursor;
    mdb_cursor_open(ongoing_transation_handle, bond_db, &cursor);
	while ((mdb_cursor_get(cursor, &key, &value, MDB_NEXT)) == 0) {
		int int_key = *(int *)key.mv_data;
		if(is_bond_marked_to_remove(in_molecule_id, int_key)){
			continue;
		}
		bonds.push_back(int_key);
    }
	return bonds;
}


void LightningMemoryMappedDatabase::commit() {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(!transaction_in_progress);

	::capnp::MallocMessageBuilder info_builder;
  	DBInfo::Builder info = info_builder.initRoot<DBInfo>();
	info.setDatabaseVersion(DB_VERSION);
	info.setNextMoleculeID(next_molecule_id);
	put_builder_schema_into_db(DB_INFO_SCHEMA_ID, info_builder, ongoing_transation_handle, db_info);

	transaction_in_progress = false;
	int commit_code = mdb_txn_commit(ongoing_transation_handle);
	if (commit_code != MDB_SUCCESS) {
		ERR_FAIL_MSG(mdb_strerror(commit_code));
	}

	// prepare new transaction
	start();
}

bool LightningMemoryMappedDatabase::is_active() {
	return is_initialized;
}

bool LightningMemoryMappedDatabase::put_value(const Variant &in_key, const Variant &in_value) {
	ERR_FAIL_COND_V(!is_initialized, false);

	MDB_txn *write_translation_handle;
	int transation_begin_return_code = mdb_txn_begin(env, NULL, 0, &write_translation_handle);
	if (transation_begin_return_code != MDB_SUCCESS) {
		return false;
	}

	
	int open_return_code = mdb_open(write_translation_handle, NULL, 0, &db_handle);
	if (open_return_code != MDB_SUCCESS) {
		return false;
	}

	// key
	MDB_val key;
	PackedByteArray key_byte_array = VariantUtilityFunctions::var_to_bytes(in_key);
	uint8_t *key_bytes  = key_byte_array.ptrw();
	size_t key_size = key_byte_array.size();
	key.mv_size = key_size;
	key.mv_data = (void *) key_bytes;

	// value
	MDB_val val;
	PackedByteArray value_byte_array = VariantUtilityFunctions::var_to_bytes(in_value);
	uint8_t *value_bytes  = value_byte_array.ptrw();
	size_t value_size = value_byte_array.size();
	val.mv_size = value_size;
	val.mv_data = (void *) value_bytes;
	int put_return = mdb_put(write_translation_handle, db_handle, &key, &val, 0);
	if (put_return != MDB_SUCCESS) {
		mdb_close(env, db_handle);
		ERR_FAIL_V_MSG(false, mdb_strerror(put_return));
	}
	mdb_txn_commit(write_translation_handle);
	
	return true;
}

Variant LightningMemoryMappedDatabase::get_value(const Variant &in_key, const Variant &in_default_value) {
	ERR_FAIL_COND_V(!is_initialized, Variant());

	// key
	MDB_val key;
	PackedByteArray key_byte_array = VariantUtilityFunctions::var_to_bytes(in_key);
	uint8_t *key_bytes  = key_byte_array.ptrw();
	size_t key_size = key_byte_array.size();
	key.mv_size = key_size;
	key.mv_data = (void *) key_bytes;

	MDB_txn *read_transation_handle;
	int transation_handle_code = mdb_txn_begin(env, NULL, 0, &read_transation_handle);
	ERR_FAIL_COND_V_MSG(transation_handle_code != MDB_SUCCESS, Variant(), mdb_strerror(transation_handle_code));

	// value
	MDB_val value;
	int get_return_code = mdb_get(read_transation_handle, db_handle, &key, &value);
	if (get_return_code == MDB_NOTFOUND) {
		int commit_return_code = mdb_txn_commit(read_transation_handle);
		ERR_FAIL_COND_V_MSG(commit_return_code != MDB_SUCCESS, in_default_value, mdb_strerror(commit_return_code));
	} else if (get_return_code != MDB_SUCCESS) {
		ERR_FAIL_V_MSG(Variant(), mdb_strerror(get_return_code));
	}
	
	uint8_t *key_bytes_ptr = (uint8_t *) value.mv_data;
	PackedByteArray packed_byte_array;
	create_packed_byte_array_from_pointer(key_bytes_ptr, value.mv_size, &packed_byte_array);
	Variant return_value = VariantUtilityFunctions::bytes_to_var(packed_byte_array);

	int commit_return_code = mdb_txn_commit(read_transation_handle);
	ERR_FAIL_COND_V_MSG(commit_return_code == MDB_SUCCESS, Variant(), mdb_strerror(commit_return_code));

	return return_value;
}

void LightningMemoryMappedDatabase::_bind_methods() {
	ClassDB::bind_method(D_METHOD("initialize", "database_file_path"), &LightningMemoryMappedDatabase::initialize);
	ClassDB::bind_method(D_METHOD("put_value", "key", "value"), &LightningMemoryMappedDatabase::put_value);
	ClassDB::bind_method(D_METHOD("get_value", "key", "default_value"), &LightningMemoryMappedDatabase::get_value, "default", &LightningMemoryMappedDatabase::get_value, DEFVAL(Variant()));
	ClassDB::bind_method(D_METHOD("commit"), &LightningMemoryMappedDatabase::commit);
	ClassDB::bind_method(D_METHOD("is_active"), &LightningMemoryMappedDatabase::is_active);
	ClassDB::bind_method(D_METHOD("create_molecule"), &LightningMemoryMappedDatabase::create_molecule);
	ClassDB::bind_method(D_METHOD("has_molecule", "molecule_id"), &LightningMemoryMappedDatabase::has_molecule);
	ClassDB::bind_method(D_METHOD("get_molecules"), &LightningMemoryMappedDatabase::get_molecules);
	ClassDB::bind_method(D_METHOD("remove_molecule", "molecule_id"), &LightningMemoryMappedDatabase::remove_molecule);
	ClassDB::bind_method(D_METHOD("create_atom", "molecule_id", "element_type", "position"), &LightningMemoryMappedDatabase::create_atom);
	ClassDB::bind_method(D_METHOD("has_atom", "molecule_id", "atom_id"), &LightningMemoryMappedDatabase::has_atom);
	ClassDB::bind_method(D_METHOD("mark_atom_as_removed", "molecule_id", "atom_id"), &LightningMemoryMappedDatabase::mark_atom_as_removed);
	ClassDB::bind_method(D_METHOD("is_atom_marked_to_remove", "molecule_id", "atom_id"), &LightningMemoryMappedDatabase::is_atom_marked_to_remove);
	ClassDB::bind_method(D_METHOD("unmark_atom_removal", "molecule_id", "atom_id"), &LightningMemoryMappedDatabase::unmark_atom_removal);
	ClassDB::bind_method(D_METHOD("mark_bond_as_removed", "molecule_id", "bond_id"), &LightningMemoryMappedDatabase::mark_bond_as_removed);
	ClassDB::bind_method(D_METHOD("is_bond_marked_to_remove", "molecule_id", "bond_id"), &LightningMemoryMappedDatabase::is_bond_marked_to_remove); 
	ClassDB::bind_method(D_METHOD("unmark_bond_removal", "molecule_id", "bond_id"), &LightningMemoryMappedDatabase::unmark_bond_removal);
	ClassDB::bind_method(D_METHOD("set_atom_data", "molecule_id", "atom_id", "data"), &LightningMemoryMappedDatabase::set_atom_data);
	ClassDB::bind_method(D_METHOD("get_atom", "molecule_id", "atom_id"), &LightningMemoryMappedDatabase::get_atom);
	ClassDB::bind_method(D_METHOD("get_atom_count", "molecule_id"), &LightningMemoryMappedDatabase::get_atom_count);
	ClassDB::bind_method(D_METHOD("get_atoms", "molecule_id"), &LightningMemoryMappedDatabase::get_atoms);
	ClassDB::bind_method(D_METHOD("create_bond", "molecule_id", "first_atom_id", "second_atom_id", "order"), &LightningMemoryMappedDatabase::create_bond);
	ClassDB::bind_method(D_METHOD("has_bond", "molecule_id", "bond_id"), &LightningMemoryMappedDatabase::has_bond);
	ClassDB::bind_method(D_METHOD("set_bond_data", "molecule_id", "atom_id", "data"), &LightningMemoryMappedDatabase::set_bond_data);
	ClassDB::bind_method(D_METHOD("get_bond", "molecule_id", "bond_id"), &LightningMemoryMappedDatabase::get_bond);
	ClassDB::bind_method(D_METHOD("get_bond_count", "molecule_id"), &LightningMemoryMappedDatabase::get_bond_count);
	ClassDB::bind_method(D_METHOD("get_all_bonds", "molecule_id"), &LightningMemoryMappedDatabase::get_all_bonds);
}

bool LightningMemoryMappedDatabase::init_db_info(MDB_txn *in_open_dbs_transation_handle) {
	
	int db_info_open_return_code = mdb_open(in_open_dbs_transation_handle, "db_info", MDB_INTEGERKEY | MDB_CREATE, &db_info);
	if (db_info_open_return_code != MDB_SUCCESS) {
		mdb_close(env, db_handle);
		mdb_close(env, db_info);
		ERR_FAIL_V_MSG(false, mdb_strerror(db_info_open_return_code));
	}

	MDB_val db_info_key, db_info_data;
	db_info_key.mv_data = (void*)&DB_INFO_SCHEMA_ID;
	db_info_key.mv_size = sizeof(int);
	int info_get_code = mdb_get(in_open_dbs_transation_handle, db_info, &db_info_key, &db_info_data);
	if (info_get_code == MDB_NOTFOUND){

		// create new DBInfo schema object based on capnp schema
		::capnp::MallocMessageBuilder info_builder;
  		DBInfo::Builder info = info_builder.initRoot<DBInfo>();
		info.setDatabaseVersion(DB_VERSION);
		info.setNextMoleculeID(0);

		bool success = put_builder_schema_into_db(DB_INFO_SCHEMA_ID, info_builder, in_open_dbs_transation_handle, db_info);
		if (!success) {
			mdb_close(env, db_handle);
			mdb_close(env, db_info);
			ERR_FAIL_V_MSG(false, "Cannot initialize Info Database");
		}
	} else if (info_get_code != MDB_SUCCESS) {
		return false;
	}
	
	return true;
}

void LightningMemoryMappedDatabase::start() {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(transaction_in_progress);
	int begin_code = mdb_txn_begin(env, NULL, 0, &ongoing_transation_handle);
	if (begin_code != MDB_SUCCESS) {
		mdb_txn_abort(ongoing_transation_handle);
		ERR_FAIL_MSG(mdb_strerror(begin_code));
	}

	auto info_array = fetch_capnpro_schema(ongoing_transation_handle, db_info, DB_INFO_SCHEMA_ID);
	capnp::FlatArrayMessageReader schema_byte_reader(info_array);
	auto info = schema_byte_reader.getRoot<DBInfo>();

	next_molecule_id = info.getNextMoleculeID();
	transaction_in_progress = true;
}

void LightningMemoryMappedDatabase::cleanup() {
	// Iterate over every atom and bond which is marked for removal and remove those from databases
	MDB_val key,value;
    MDB_cursor *cursor;
	mdb_cursor_open(ongoing_transation_handle, db_molecule, &cursor);
	while ((mdb_cursor_get(cursor, &key, &value, MDB_NEXT)) == 0) {
		int molecule_id = *(int *)key.mv_data;
		MDB_dbi removed_atom_db = get_marked_for_removal_atoms_db(molecule_id);
		MDB_val removed_atom_key, removed_atom_value;
		MDB_cursor *removed_atom_cursor;
		mdb_cursor_open(ongoing_transation_handle, removed_atom_db, &removed_atom_cursor);
		while ((mdb_cursor_get(removed_atom_cursor, &removed_atom_key, &removed_atom_value, MDB_NEXT)) == 0) {
			int removed_atom_id = *(int *)removed_atom_key.mv_data;
			remove_atom(molecule_id, removed_atom_id);
		}

		MDB_dbi removed_bond_db = get_marked_for_removal_bonds_db(molecule_id);
		MDB_val removed_bond_key, removed_bond_value;
		MDB_cursor *removed_bond_cursor;
		mdb_cursor_open(ongoing_transation_handle, removed_bond_db, &removed_bond_cursor);
		while ((mdb_cursor_get(removed_bond_cursor, &removed_bond_key, &removed_bond_value, MDB_NEXT)) == 0) {
			int removed_bond_id = *(int *)removed_bond_key.mv_data;
			remove_bond(molecule_id, removed_bond_id);
		}

		// clean 'removal flag' databases
		mdb_drop(ongoing_transation_handle, removed_atom_db, 0);
		mdb_drop(ongoing_transation_handle, removed_bond_db, 0);
	}
}

bool LightningMemoryMappedDatabase::put_builder_schema_into_db(const int in_key, ::capnp::MallocMessageBuilder &in_builder, MDB_txn *in_transation_handle, MDB_dbi &in_db) {
	auto serialized_info = capnp::messageToFlatArray(in_builder);
	MDB_val key, value;
	key.mv_size = sizeof(uint32_t);
	key.mv_data = (void*)&in_key;
	kj::ArrayPtr<kj::byte> data_as_bytes = serialized_info.asBytes();
	value.mv_size = data_as_bytes.size();
	value.mv_data = data_as_bytes.begin();
	int put_code = mdb_put(in_transation_handle, in_db, &key, &value, 0);
	if (put_code != MDB_SUCCESS) {
		std::cout << mdb_strerror(put_code) << std::endl;
		return false;
	}

	return true;
}

void LightningMemoryMappedDatabase::atom_new_bond_relation(const int in_molecule_id, const int in_atom_id, const int in_bond_id) {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(!transaction_in_progress);

	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	auto atom_array = fetch_capnpro_schema(ongoing_transation_handle, atom_db, in_atom_id);
	capnp::FlatArrayMessageReader schema_byte_atom_reader(atom_array);
	auto atom_data = schema_byte_atom_reader.getRoot<Atom>();

	float position_x = atom_data.getPositionX();
	float position_y = atom_data.getPositionY();
	float position_z = atom_data.getPositionZ();
	int type = atom_data.getElementType();
	::capnp::List< ::uint32_t,  ::capnp::Kind::PRIMITIVE>::Reader bonds = atom_data.getBonds();
	PackedInt32Array updated_bonds;
	for (auto bond : bonds) {
		if (static_cast<unsigned int>(in_bond_id) != bond) {
			updated_bonds.push_back(bond);
		}
	}
	updated_bonds.push_back(in_bond_id);

	AtomSnapshot updated_atom;
	updated_atom.set_position(Vector3(position_x, position_y, position_z));
	updated_atom.set_type(type);
	updated_atom.set_bonds(updated_bonds);

	put_atom_data(in_molecule_id, in_atom_id, &updated_atom, ongoing_transation_handle);
}

void LightningMemoryMappedDatabase::atom_remove_bond_relation(const int in_molecule_id, const int in_atom_id, const int in_bond_id) {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(!transaction_in_progress);

	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	auto atom_array = fetch_capnpro_schema(ongoing_transation_handle, atom_db, in_atom_id);
	capnp::FlatArrayMessageReader schema_byte_atom_reader(atom_array);
	auto atom_data = schema_byte_atom_reader.getRoot<Atom>();

	float position_x = atom_data.getPositionX();
	float position_y = atom_data.getPositionY();
	float position_z = atom_data.getPositionZ();
	int type = atom_data.getElementType();
	::capnp::List< ::uint32_t,  ::capnp::Kind::PRIMITIVE>::Reader bonds = atom_data.getBonds();
	PackedInt32Array updated_bonds;
	for (auto bond : bonds) {
		if (static_cast<unsigned int>(in_bond_id) != bond) {
			updated_bonds.push_back(bond);
		}
	}

	AtomSnapshot updated_atom;
	updated_atom.set_position(Vector3(position_x, position_y, position_z));
	updated_atom.set_type(type);
	updated_atom.set_bonds(updated_bonds);

	put_atom_data(in_molecule_id, in_atom_id, &updated_atom, ongoing_transation_handle);
}


MDB_dbi LightningMemoryMappedDatabase::get_atom_db_for_molecule(const int in_molecule_id) {
	if (!opened_atoms_databases.has(in_molecule_id)) {
		auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
		capnp::FlatArrayMessageReader schema_byte_reader(data_array);
		auto molecule_data = schema_byte_reader.getRoot<Molecule>();
		auto atom_db_name = molecule_data.getAtomDatabaseID().cStr();
		MDB_dbi opened_db_atom;
		int db_open_code = mdb_open(ongoing_transation_handle, atom_db_name, MDB_INTEGERKEY | MDB_CREATE, &opened_db_atom);
		opened_atoms_databases[in_molecule_id] = opened_db_atom;
		ERR_FAIL_COND_V_MSG(db_open_code != MDB_SUCCESS, opened_db_atom, "Cannot open requested atom database");
	}
	return opened_atoms_databases.get(in_molecule_id);
}


MDB_dbi LightningMemoryMappedDatabase::get_marked_for_removal_atoms_db(const int in_molecule_id) {
	if (!opened_removed_atoms_databases.has(in_molecule_id)) {
		auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
		capnp::FlatArrayMessageReader schema_byte_reader(data_array);
		auto molecule_data = schema_byte_reader.getRoot<Molecule>();
		const char* removed_atom_db_name = addStrings(molecule_data.getAtomDatabaseID().cStr(), "_removed");
		MDB_dbi opened_db_removed_atoms;
		int db_open_code = mdb_open(ongoing_transation_handle, removed_atom_db_name, MDB_INTEGERKEY | MDB_CREATE, &opened_db_removed_atoms);
		opened_removed_atoms_databases[in_molecule_id] = opened_db_removed_atoms;
		ERR_FAIL_COND_V_MSG(db_open_code != MDB_SUCCESS, opened_db_removed_atoms, "Cannot open requested opened_db_removed_atoms database");
	}
	return opened_removed_atoms_databases.get(in_molecule_id);
}


MDB_dbi LightningMemoryMappedDatabase::get_marked_for_removal_bonds_db(const int in_molecule_id) {
	if (!opened_removed_bonds_databases.has(in_molecule_id)) {
		auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
		capnp::FlatArrayMessageReader schema_byte_reader(data_array);
		auto molecule_data = schema_byte_reader.getRoot<Molecule>();
		auto removed_bond_db_name = addStrings(molecule_data.getBondDatabaseID().cStr(), "_removed");
		MDB_dbi opened_db_removed_bonds;
		int db_open_code = mdb_open(ongoing_transation_handle, removed_bond_db_name, MDB_INTEGERKEY | MDB_CREATE, &opened_db_removed_bonds);
		opened_removed_bonds_databases[in_molecule_id] = opened_db_removed_bonds;
		ERR_FAIL_COND_V_MSG(db_open_code != MDB_SUCCESS, opened_db_removed_bonds, "Cannot open requested opened_db_removed_bonds database");
	}
	return opened_removed_bonds_databases.get(in_molecule_id);
}


MDB_dbi LightningMemoryMappedDatabase::get_bond_db_for_molecule(const int in_molecule_id) {
	if (!opened_bonds_databases.has(in_molecule_id)) {
		auto data_array = fetch_capnpro_schema(ongoing_transation_handle, db_molecule, in_molecule_id);
		capnp::FlatArrayMessageReader schema_byte_reader(data_array);
		auto molecule_data = schema_byte_reader.getRoot<Molecule>();
		auto bond_db_name = molecule_data.getBondDatabaseID().cStr();
		MDB_dbi opened_db_bond;
		int db_open_code = mdb_open(ongoing_transation_handle, bond_db_name, MDB_INTEGERKEY | MDB_CREATE, &opened_db_bond);
		opened_bonds_databases[in_molecule_id] = opened_db_bond;
		ERR_FAIL_COND_V_MSG(db_open_code != MDB_SUCCESS, opened_db_bond, "Cannot open requested bond database");
	}
	return opened_bonds_databases.get(in_molecule_id);
}

void LightningMemoryMappedDatabase::put_atom_data(int in_molecule_id, int in_atom_id, const AtomSnapshot *item_data, MDB_txn *in_transation_handle) {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(!transaction_in_progress);

	::capnp::MallocMessageBuilder atom_builder;
  	Atom::Builder new_atom = atom_builder.initRoot<Atom>();
	new_atom.setPositionX(item_data->get_position().x);
	new_atom.setPositionY(item_data->get_position().y);
	new_atom.setPositionZ(item_data->get_position().z);
	new_atom.setElementType(item_data->get_type());
	PackedInt32Array bonds = item_data->get_bonds();
	size_t nmb_of_bonds = bonds.size();
	auto schema_bonds = new_atom.initBonds(nmb_of_bonds);
	for (uint32_t i = 0; i < nmb_of_bonds; i++) {
		schema_bonds.set(i, bonds[i]);
	}
	
	MDB_dbi atom_db = get_atom_db_for_molecule(in_molecule_id);
	bool update_success = put_builder_schema_into_db(in_atom_id, atom_builder, in_transation_handle, atom_db);
	if(!update_success) {
		ERR_FAIL_MSG("Failed to update atom data");
	}
}

void LightningMemoryMappedDatabase::put_bond_data(const int in_molecule_id, const int in_bond_id, const BondSnapshot *item_data, MDB_txn *in_transation_handle) {
	ERR_FAIL_COND(!is_initialized);
	ERR_FAIL_COND(!transaction_in_progress);
	
	::capnp::MallocMessageBuilder bond_builder;
  	Bond::Builder new_bond = bond_builder.initRoot<Bond>();

	new_bond.setFirstAtom(item_data->get_first_atom());
	new_bond.setSecondAtom(item_data->get_second_atom());
	new_bond.setOrder(item_data->get_order());

	auto data_array = fetch_capnpro_schema(in_transation_handle, db_molecule, in_molecule_id);
	capnp::FlatArrayMessageReader schema_byte_reader(data_array);
	MDB_dbi bond_db = get_bond_db_for_molecule(in_molecule_id);
	bool update_success = put_builder_schema_into_db(in_bond_id, bond_builder, in_transation_handle, bond_db);
	if(!update_success) {
		ERR_FAIL_MSG("Failed to update atom data");
	}
}

void LightningMemoryMappedDatabase::put_molecule_into_db(const int in_key, const int in_next_atom_id, const int in_next_bond_id,
			Molecule::Reader in_molecule_reader, MDB_txn *in_transation_handle, MDB_dbi &in_db) {
	::capnp::MallocMessageBuilder builder;
  	Molecule::Builder updated_molecule = builder.initRoot<Molecule>();
	updated_molecule.setNextAtomID(in_next_atom_id);
	updated_molecule.setNextBondID(in_next_bond_id);
	updated_molecule.setAtomDatabaseID(in_molecule_reader.getAtomDatabaseID());
	updated_molecule.setBondDatabaseID(in_molecule_reader.getBondDatabaseID());
	put_builder_schema_into_db(in_key, builder, in_transation_handle, in_db);
}

kj::Array<capnp::word> LightningMemoryMappedDatabase::fetch_capnpro_schema(MDB_txn* fetch_txn, MDB_dbi &db, const int key_val) {
	MDB_val key, value;
	key.mv_size = sizeof(int);
	key.mv_data = (void*)&key_val;
  
	int get_return_code = mdb_get(fetch_txn, db, &key, &value);
	if (get_return_code != MDB_SUCCESS) {
		std::cout << mdb_strerror(get_return_code) << std::endl;
	}

	kj::Array<capnp::word> data_array = kj::heapArray<capnp::word>(value.mv_size / sizeof(capnp::word));
	memcpy(data_array.begin(), value.mv_data, value.mv_size);
	return data_array;
}

void LightningMemoryMappedDatabase::create_packed_byte_array_from_pointer(uint8_t* key_bytes, int key_bytes_length, PackedByteArray* packed_byte_array) {
	ERR_FAIL_COND(!is_initialized);
    packed_byte_array->resize(key_bytes_length);
    memcpy(packed_byte_array->ptrw(), key_bytes, key_bytes_length);
}


char* LightningMemoryMappedDatabase::addStrings(const char* str1, const char* str2) {
    // Calculate lengths of both strings
    size_t len1 = strlen(str1);
    size_t len2 = strlen(str2);
    
    // Allocate memory for the result string
    char* result = new char[len1 + len2 + 1]; // +1 for the null terminator
    
    // Copy the first string to the result
    strcpy(result, str1);
    
    // Append the second string to the result
    strcat(result, str2);
    
    return result;
}