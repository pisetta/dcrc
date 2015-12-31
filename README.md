# dcrc
**dcrc** is an implementation of the fast table CRC calculation. The template CRC receives the polynomial, init value and a "output xor value" as parameters and creates a std.digest.isDigest compilant struct with the table calculated at compile time. This version of crc is more generic than std.digest.crc32 and can be used in CTFE. Don't know if it is as fast, a benchmark is in TODO list. 
CRC32 and other std.digest.crc symbols are redefined here using CRC template aliasing CRC with the proper parameters.
There is a definition of CRC64 with ISO polynomial, but it lacks unittest.
Feel free to suggest improvements and aliases for other standards.
