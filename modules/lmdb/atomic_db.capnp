@0xba11d4ca97ecfbd5;

struct Molecule {
  atomDatabaseID @0: Text;
  bondDatabaseID @1: Text;
  nextAtomID @2: UInt32;
  nextBondID @3: UInt32;
}

struct Atom {
  positionX @0: Float32;
  positionY @1: Float32;
  positionZ @2: Float32;
  elementType @3: UInt32;
  bonds @4: List(UInt32);
}

struct Bond {
  order @0: UInt32;
  firstAtom @1: UInt32;
  secondAtom @2: UInt32;
}

struct DBInfo {
  databaseVersion @0: UInt32;
  nextMoleculeID @1: UInt32;
}

