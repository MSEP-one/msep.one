#pragma once

#if _WIN32 && !_INC_WINDOWS
#include <windows.h>
#endif
#include "core/variant/variant.h"
#include "scene/main/node.h"
#include "thirdparty/liblmdb/lmdb.h"
#include "thirdparty/capnproto/c++/src/capnp/message.h"
#include "atomic_db.capnp.h"



class AtomSnapshot : public RefCounted {
	GDCLASS(AtomSnapshot, RefCounted)

	int type;
	Vector3 position;
	PackedInt32Array bonds;

protected:
	static void _bind_methods();
public:
	AtomSnapshot();
	~AtomSnapshot();

	PackedByteArray get_packed_byte_array() const;
	void init_from_packed_byte_array(PackedByteArray &in_packed_byte_array);

	int get_type() const;
	Vector3 get_position() const;
	void set_type(const int in_type);
	void set_position(const Vector3 &in_position);
	void set_bonds(const PackedInt32Array &in_bonds);
	PackedInt32Array get_bonds() const;
};

class BondSnapshot: public RefCounted {
	GDCLASS(BondSnapshot, RefCounted)

	int first_atom_id;
	int second_atom_id;
	int order;

protected:
	static void _bind_methods();
public:
	BondSnapshot();
	~BondSnapshot();

	int get_first_atom() const;
	void set_first_atom(const int in_id);
	int get_second_atom() const;
	void set_second_atom(const int in_id);
	int get_order() const;
	void set_order(const int in_order);

	PackedByteArray get_packed_byte_array() const;
	void init_from_packed_byte_array(PackedByteArray &in_packed_byte_array);
};


class LightningMemoryMappedDatabase : public Node {
	GDCLASS(LightningMemoryMappedDatabase, Node)


private:
	static const int DB_VERSION = 1;
	static const int DB_INFO_ATOM_COUNTER = 1;
	static const int DB_INFO_BOND_COUNTER = 2;
	static const int DB_INFO_SCHEMA_ID = 3;
	// supports up to around 50 open structures at the same time (roughly 2 dbs per structure)
	static const MDB_dbi MAX_DBS = 100;

	MDB_env *env;
	MDB_txn *ongoing_transation_handle;
	MDB_dbi db_handle;
	MDB_dbi db_info;
	MDB_dbi db_molecule;
	bool is_initialized = false;
	
	bool transaction_in_progress = false;
	int next_molecule_id = 0;

	HashMap<int, MDB_dbi> opened_atoms_databases;
	HashMap<int, MDB_dbi> opened_bonds_databases;
	HashMap<int, MDB_dbi> opened_removed_atoms_databases;
	HashMap<int, MDB_dbi> opened_removed_bonds_databases;
	

public:
	LightningMemoryMappedDatabase();
	~LightningMemoryMappedDatabase();

	/// @brief Initializes the library with a specified directory path, database files will reside under that path
	/// @param in_directory_path The path to the directory containing molecule data.
	/// @return true if successful, false otherwise.
	bool initialize(const String &in_directory_path);

	/// @brief Creates a new empty molecule.
	/// @return The ID of the newly created molecule.
	int create_molecule();

	/// @brief Removes an existing molecule from the database.
	/// @param in_molecule_id The ID of the molecule to remove.
	/// @return true if successful, false otherwise.
	bool remove_molecule(const int in_molecule_id);

	/// @brief Checks if a molecule with the specified ID exists in the database.
	/// @param in_molecule_id  The ID of the molecule to check.
	/// @return true if the molecule exists, false otherwise.
	bool has_molecule(const int in_molecule_id);

	PackedInt32Array get_molecules();

	/// @brief Creates new atom
	/// @param in_molecule_id molecule which is related to freshly created atom
	/// @param in_element_type atom type (ex. Hydrogen=1, Carbon=6 etc)
	/// @param in_position position in 3d space
	/// @return id for freshly created atom
	int create_atom(const int in_molecule_id, const int in_element_type, const Vector3 &in_position);
	
	bool is_atom_marked_to_remove(const int in_molecule_id, const int in_atom_id);

	/// @brief Queues atom to be removed
	/// All associated bonds will be marked as removed as well
	/// get_all_atoms() will not return this atom
	/// @param in_molecule_id molecule from which atom will be removed
	/// @param in_atom_id id of an atom to remove
	/// @return true if success, false otherwise
	void mark_atom_as_removed(const int in_molecule_id, const int in_atom_id);

	/// @brief If during this session an atom has been removed, this function can be used to reverse that operation
	/// @param in_molecule_id 
	/// @param in_atom_id 
	/// @return success (true) of failure (false)
	bool unmark_atom_removal(const int in_molecule_id, const int in_atom_id);

	/// @brief Checks if an atom exists in a molecule
	/// @param in_molecule_id molecule to check
	/// @param in_atom_id id of the atom to check
	/// @return true if the atom exists, false otherwise
	bool has_atom(const int in_molecule_id, const int in_atom_id);

	// @brief Retrieves information about an atom
	/// @param in_molecule_id molecule containing the atom
	/// @param in_atom_id id of the atom to retrieve
	/// @return pointer to the atom data object, or nullptr if not found
	AtomSnapshot *get_atom(const int in_molecule_id, const int in_atom_id);

	/// @brief Updates the data associated with an atom
	/// @param in_molecule_id molecule containing the atom
	/// @param in_atom_id id of the atom to update
	/// @param in_data pointer to the new atom data object
	void set_atom_data(const int in_molecule_id, const int in_atom_id, const AtomSnapshot *in_data);


	/// @brief Gives access to information about atom count in a molecule
	/// @param in_molecule_id molecule
	/// @return number of atoms in molecule
	int get_atom_count(const int in_molecule_id);

	/// @brief Access to information about existing valid atoms
	/// @param in_molecule_id molecule containing the atom
	/// @return List of all the valid atom ids
	PackedInt32Array get_atoms(const int in_molecule_id);

	/// @brief Creates a new bond between two atoms in a molecule
	/// @param in_molecule_id molecule containing the atoms
	/// @param in_first_atom id of the first atom
	/// @param in_second_atom id of the second atom
	/// @param in_order bond order (1 for single bond, 2 for double bond, 3 for tripple bond)
	/// @return id of the newly created bond, or -1 if unsuccessful
	int create_bond(const int in_molecule_id, const int in_first_atom, const int in_second_atom, const int in_order);

	/// @brief Checks if a bond exists in a molecule
	/// @param in_molecule_id molecule to check
	/// @param in_bond_id id of the bond to check
	/// @return true if the bond exists, false otherwise
	bool has_bond(const int in_molecule_id, const int in_bond_id);

	// @brief Retrieves information about a bond
	/// @param in_molecule_id molecule containing the bond
	/// @param in_bond_id id of the bond to retrieve
	/// @return pointer to the bond data object, or nullptr if not found
	BondSnapshot *get_bond(const int in_molecule_id, const int in_bond_id);

	/// @brief Updates the data associated with a bond
	/// @param in_molecule_id molecule containing the bond
	/// @param in_bond_id id of the bond to update
	/// @param in_data pointer to the new bond data object
	/// @return true if successful, false otherwise
	void set_bond_data(const int in_molecule_id, const int in_bond_id, const BondSnapshot *in_data);

	/// @brief Queues bonds to be removed, 
	/// no Atom.get_bonds() will have association to this bond and get_all_bonds() will not return this bond
	/// Can be reversed with unmark_bond_removal()
	/// @param in_molecule_id molecule containing the bond
	/// @param in_bond_id id of the bond to remove
	/// @return true if successful, false otherwise
	void mark_bond_as_removed(const int in_molecule_id, const int in_bond_id);
	
	/// @brief Allows to check if given bond is marke to be removed
	/// @param in_molecule_id molecule containing the bond
	/// @param in_bond_id id of the bond to remove
	/// @return true if bond marked to be removed, false otherwise
	bool is_bond_marked_to_remove(const int in_molecule_id, const int in_bond_id);

	/// @brief If during this session a bond has been removed, this function can be used to reverse that operation
	/// @param in_molecule_id 
	/// @param in_bond_id 
	/// @return success (true) of failure (false)
	bool unmark_bond_removal(const int in_molecule_id, const int in_bond_id);

	/// @brief Information about bond count in a molecule
	/// @param in_molecule_id molecule
	/// @return number of bonds in molecule
	int get_bond_count(const int in_molecule_id);


	/// @brief Access to information about existing valid bonds
	/// @param in_molecule_id molecule
	/// @return List of all the valid bond ids
	PackedInt32Array get_all_bonds(const int in_molecule_id);

	/// @brief Ensures all changes since last commit() are saved. Should be called regularly (ex. once per frame)
	void commit();

	/// @brief Checks if this instance has been initialized
	bool is_active();

	/// @brief Stores a custom variant key-value pair, it's being left here only for prototyping reasons
	/// @param in_key key to store the value under
	/// @param in_value value to store
	/// @return true if successful, false otherwise
	bool put_value(const Variant &in_key, const Variant &in_value);

	/// @brief Retrieves a custom value, it's being left here only for prototyping reasons
	/// @param in_key key to retrieve the value from
	/// @param in_default_value default value to return if the key is not found
	/// @return the stored value (if found), or the default value
	Variant get_value(const Variant &in_key, const Variant &in_default_value);

protected:
	static void _bind_methods();
	bool init_db_info(MDB_txn *in_open_dbs_transation_handle);
	void start();
	void cleanup();
	bool put_builder_schema_into_db(const int in_key, ::capnp::MallocMessageBuilder &in_builder, MDB_txn *in_transation_handle, MDB_dbi &in_db);
	void put_atom_data(int in_molecule_id, int in_atom_id, const AtomSnapshot *item_data, MDB_txn *in_transation_handle);
	void atom_new_bond_relation(const int in_molecule_id, const int in_first_atom, const int bond_id);
	void atom_remove_bond_relation(const int in_molecule_id, const int in_atom_id, const int in_bond_id);
	MDB_dbi get_atom_db_for_molecule(const int in_molecule_id);
	MDB_dbi get_marked_for_removal_atoms_db(const int in_molecule_id);
	bool remove_atom(const int in_molecule_id, const int in_atom_id);
	void put_bond_data(const int in_molecule_id, const int in_id, const BondSnapshot *in_item_data, MDB_txn *in_transation_handle);
	MDB_dbi get_bond_db_for_molecule(const int in_molecule_id);
	MDB_dbi get_marked_for_removal_bonds_db(const int in_molecule_id);
	bool remove_bond(const int in_molecule_id, const int in_bond);
	void put_molecule_into_db(const int in_key, const int in_updated_atom_counter, const int in_updated_bond_counter,
			Molecule::Reader in_molecule_reader, MDB_txn *in_transation_handle, MDB_dbi &in_db);
	kj::Array<capnp::word> fetch_capnpro_schema(MDB_txn* fetch_txn, MDB_dbi &db, const int key_val);	
	void create_packed_byte_array_from_pointer(uint8_t* in_key_bytes, int in_key_bytes_length, PackedByteArray* in_packed_byte_array);
	char* addStrings(const char* str1, const char* str2);
	
};
