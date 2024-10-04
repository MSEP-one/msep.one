
#include "register_types.h"

#include "core/object/class_db.h"
#include "lightning_memory_mapped_database.h"

void initialize_lmdb_module(ModuleInitializationLevel p_level) {
	if (p_level != ModuleInitializationLevel::MODULE_INITIALIZATION_LEVEL_CORE) {
		return;
	}
	ClassDB::register_class<LightningMemoryMappedDatabase>();
	ClassDB::register_class<AtomSnapshot>();
	ClassDB::register_class<BondSnapshot>();
}

void uninitialize_lmdb_module(ModuleInitializationLevel p_level) {
}
