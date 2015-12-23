module crc;

/*****************************************************************************
 * Generic table driven CRC implementation
 * P is the polynomial
 * I is the initial value
 * O is the value xored with the output
 * The type of P determine the crc size. uint is crc32, ushort is crc16 and 
 *   ubyte is crc8
 * The template generates a function that uses 
 *****************************************************************************/
import std.algorithm;
import std.range;
import std.typecons;
import std.system;
import std.digest.digest;

enum Shift {
  Left,
  Right
}

template CRC(alias P,alias I,alias O,Shift S,Endian E) {
  
  template checkValidTypes(PT,IT,OT) {
    enum checkValidTypes = is( PT == IT )  && is( IT == OT ) && 
      ( is( PT == ulong ) || is( PT == uint ) || is( PT == ushort ) || is( PT == ubyte ) ) ;
  }

  static assert( checkValidTypes!( typeof( P ), typeof( I ), typeof( O ) ) );

  alias typeof( P ) CRCType;

  alias P Polynomial;
  alias I Init;
  alias O OutputXor;

  template ShiftExpressions(Shift S) if ( S == Shift.Left ) {
    enum TOPMASK = 1 << ( CRCType.sizeof * 8 - 1 );
    
    CRCType tableInit( ubyte value ) @trusted pure nothrow @nogc {
      return value << ( CRCType.sizeof * 8 - 8 );
    }

    CRCType tableStep(bool onlyShift)( CRCType reminder ) @trusted pure nothrow @nogc {
      CRCType tmp = reminder << 1;
      static if ( ! onlyShift ) {
        tmp ^= Polynomial;
      }
      return tmp;
    }

    CRCType crcStep( CRCType crc, ubyte value ) @trusted pure nothrow @nogc {
      return table[( ( crc >> 24 ) ^ value ) & 0xff] ^ ( crc << 8 );
    }
  }

  template ShiftExpressions(Shift S) if ( S == Shift.Right ) {
    enum TOPMASK = 1;
    
    CRCType tableInit( ubyte value ) @trusted pure nothrow @nogc {
      return value;
    }

    CRCType tableStep(bool onlyShift)( CRCType reminder ) @trusted pure nothrow @nogc {
      CRCType tmp = reminder >> 1;
      static if ( ! onlyShift ) {
        tmp ^= Polynomial;
      }
      return tmp;
    }

    CRCType crcStep( CRCType crc, ubyte value ) @trusted pure nothrow @nogc {
      return table[( crc & 0xFF ) ^ value] ^ ( crc >> 8 );
    }
  }

  immutable(CRCType[256]) calculateTable() @trusted pure nothrow @nogc {
    CRCType[256] result;

    auto calculateElement( ubyte value ) @trusted pure nothrow @nogc {
      CRCType reminder = ShiftExpressions!S.tableInit( value );

      foreach( bit; 0..8 ) {
        if ( ( reminder & ShiftExpressions!S.TOPMASK ) == ShiftExpressions!S.TOPMASK ) {
          reminder = ShiftExpressions!S.tableStep!false( reminder );
        }
        else {
          reminder = ShiftExpressions!S.tableStep!true( reminder );
        }
      }
      return tuple( value, reminder );
    }

    foreach( value; iota( 0, 256 )
                      .map!( a => cast(ubyte) a )()
                      .map!calculateElement() ) {
      result[value[0]] = value[1];
    }
    return result;
  }

  enum table = calculateTable();

  struct CRC {
    private:
      CRCType state = Init;

    public:
      void put( scope const(ubyte)[] data ... ) @trusted pure nothrow @nogc {
        foreach( value; data ) {
          state = ShiftExpressions!S.crcStep( state, value );
        }
      }

      void start() @safe pure nothrow @nogc {
        this = CRC.init;
      }

      ubyte[CRCType.sizeof] peek() const @safe pure nothrow @nogc {
        static if ( E == Endian.littleEndian ) {
		      if ( ! __ctfe ) {
		        import std.bitmanip : nativeToLittleEndian;

		        return nativeToLittleEndian( state ^ OutputXor );
		      }
		      else {
		        CRCType tmp = state ^ OutputXor;
		        ubyte[CRCType.sizeof] result;
		        foreach( byteNum; 0..CRCType.sizeof ) {
		          result[byteNum] = cast(ubyte) tmp;
		          tmp >>= 8;
		        }
		        return result;
          }
        }
        else static if ( E == Endian.bigEndian ) {
		      if ( ! __ctfe ) {
		        import std.bitmanip : nativeToBigEndian;

		        return nativeToBigEndian( state ^ OutputXor );
		      }
		      else {
		        CRCType tmp = state ^ OutputXor;
		        ubyte[CRCType.sizeof] result;
		        foreach( byteNum; 0..CRCType.sizeof ) {
		          result[byteNum] = cast(ubyte)( tmp >> ( ( CRCType.sizeof - 1 - byteNum ) * 8 ) );
		        }
		        return result;
          }
        }
      }

      ubyte[CRCType.sizeof] finish() @safe pure nothrow @nogc {
        auto crc = peek();
        start();
        return crc;
      }
  }
}

auto crcOf(alias P,alias I,alias O,Shift S,Endian E,T...)( T data ) {
  return digest!(CRC!(P,I,O,S,E))( data );
}

auto crcOf(P,T...)( T data ) if ( is( P == CRC!(P,I,O,S,E), alias P, alias I, alias O, Shift S, Endian E ) ) {
  return digest!P( data );
}

alias CRC!(0xEDB88320U,uint.max,uint.max,Shift.Right,Endian.littleEndian) CRC32;

alias crcOf!CRC32 crc32Of;

