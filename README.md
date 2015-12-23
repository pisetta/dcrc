# dcrc
**dcrc** is an implementation of the fast table CRC calculation. The table is declared as enum and calculated on compile-time with ctfe. The crc calculation also supports CTFE, so it is possible to precalculate crc hash from an immutable message.
As of now, only CRC32 is the predeclared standard. What is needed is DDoc documentation and unittests.
