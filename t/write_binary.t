use strict;
use warnings;
use utf8;

use Data::Dumper;
$Data::Dumper::Useqq = 1;

our($val, $expect);

use Test::More tests => 38;

BEGIN {
    my $class = 'Mac::PropertyList::WriteBinary';
    
    use_ok( $class, qw( as_string ) );
    can_ok( $class, qw( as_string ) );
}

use Mac::PropertyList ();

# Test basic (scalar) data types. Make a single-object plist
# containing each one and compare it to the expected representation.
sub testrep {
    my($tp, $arg, $frag) = @_;
    my ($pkg, $fn, $ln) = caller;

    my($val) = "Mac::PropertyList::$tp"->new($arg);
    my($bplist) = as_string($val);
    my($expected) = "bplist00" . $frag . 
        pack('C x6 CC x4N x4N x4N',
             8,    # Offset table: offset of only object
             1, 1, # Byte sizes of offsets and of object IDs
             1,    # Number of objects
             0,    # ID of root (only) object
             8 + length($frag)  # Start offset of offset table
        );
 
     is($bplist, $expected, "basic datatype '$tp', line $ln")
         || diag Dumper([$val, $bplist, $expected]);
}

# The fragments here were generated by the Mac OS X 'plutil' command.

&testrep( real => 1,    "\x23\x3f\xf0\x00\x00\x00\x00\x00\x00" );
&testrep( real => 0.5,  "\x23\x3f\xe0\x00\x00\x00\x00\x00\x00" );
&testrep( real => 2,    "\x23\x40\x00\x00\x00\x00\x00\x00\x00" );
&testrep( real => -256, "\x23\xC0\x70\x00\x00\x00\x00\x00\x00" );
&testrep( real => -257, "\x23\xC0\x70\x10\x00\x00\x00\x00\x00" );

&testrep( integer => 0,      "\x10\x00" );
&testrep( integer => 1,      "\x10\x01" );
&testrep( integer => 255,    "\x10\xFF" );
&testrep( integer => 256,    "\x11\x01\x00" );
&testrep( integer => 65535,  "\x11\xFF\xFF" );
TODO: {
    local $TODO = "32-bit integer repr not done yet";
    &testrep( integer => 65536,  "\x12\x00\x01\x00\x00" );
}
&testrep( integer => -1,     "\x13\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" );
&testrep( integer => -255,   "\x13\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x01" );

&testrep( string => "Hi!",   "\x53\x48\x69\x21" );
&testrep( string => "",      "\x50" );
&testrep( string => 'FifteenCharLong',
                             "\x5F\x10\x0FFifteenCharLong" );
&testrep( string => "Uni\x{2013}Code",
                             "\x68\0U\0n\0i\x20\x13\0C\0o\0d\0e" );
TODO: {
    local $TODO = "&testrep function not smart enough for >256bytes";
&testrep( string => ( 'π' x 128 ) . ( 'p' x 128 ),
                             "\x6F\x11\x01\x00" .
                             ( "\x03\xC0" x 128 ) .
                             ( "\x00\x70" x 128 ) );
}

TODO: {
    todo_skip "Date objects in binary plists not implemented" => 4;
}

&testrep( data => '',        "\x40" );
&testrep( data => "\0\xFF",  "\x42\x00\xFF" );
&testrep( data => 'Fourteen Chars',
                             "\x4EFourteen\x20Chars" );

&testrep( true  => 1,        "\x09" );
&testrep( false => 0,        "\x08" );

&testrep( array => [],       "\xA0" );
&testrep( dict => {},        "\xD0" );

# The null object is part of the specification but rarely if ever used;
# Apple's CFBinaryPList implementation of it appears to never have
# been finished anyway.
is( as_string(undef),
    "bplist00\x00\x08".
    "\0\0\0\0\0\0\x01\x01".
    "\0\0\0\0\0\0\0\x01".
    "\0\0\0\0\0\0\0\0".
    "\0\0\0\0\0\0\0\x09",
    'the null object' );

##
# Slightly more complex data structures. There is a lot of arbitrariness
# in the bplist format (e.g., object IDs can be assigned in any order
# without affecting the represented structure), so we're just testing
# against one of possibly many equally good representations.

sub ints {
    map { Mac::PropertyList::integer->new($_) } @_;
}

$val = as_string([ &ints(1, 10, 100) ]);
$expect = 'bplist00' .            # header
          "\x10\x01" .            # int 1
          "\x10\x0A" .            # int 10
          "\x10\x64" .            # int 100
          "\xA3\x00\x01\x02" .    # array
          "\x08\x0A\x0C\x0E" .    # offsets
          "\0\0\0\0\0\0\x01\x01" .  # sizes
          "\0\0\0\0\0\0\0\x04" .  # object count
          "\0\0\0\0\0\0\0\x03" .  # rootid
          "\0\0\0\0\0\0\0\x12";   # offset-offset

is($val, $expect, 'simple arrayref') || diag Dumper([$val, $expect]);

$val = as_string({ 'Foo' => Mac::PropertyList::integer->new(108),
                   'Z'   => 'Foo' });
$expect = 'bplist00' .            # header
          "\x53Foo" .             # string Foo
          "\x51Z" .               # string Z
          "\x10\x6C" .            # int 108
          "\xD2\x00\x01\x02\x00" . # dict (0,1)=>(2,0)
          "\x08\x0C\x0E\x10" .    # offsets
          "\0\0\0\0\0\0\x01\x01" .  # sizes
          "\0\0\0\0\0\0\0\x04" .  # object count
          "\0\0\0\0\0\0\0\x03" .  # rootid
          "\0\0\0\0\0\0\0\x15";   # offset-offset
is($val, $expect, 'simple hashref') || diag Dumper([$val, $expect]);

$val = as_string( Mac::PropertyList::dict->new({
    'Foo' => Mac::PropertyList::integer->new(108),
    'Z'   => 'Foo'
                                                   }));
is($val, $expect, 'simple dict') || diag Dumper([$val, $expect]);


{
    my($d1) = Mac::PropertyList::dict->new({ 'A' => &ints(1),
                                             'B' => &ints(2) });
    my($t)  = Mac::PropertyList::true->new();
    my($d2) = Mac::PropertyList::dict->new({ 'A' => [ $t, $t, undef ],
                                             'B' => $d1 });

    $val = as_string( Mac::PropertyList::array->new([$d1, $d2, $d2]) );
}
$expect = 'bplist00' .            # header
          "\x51A" .               # string A
          "\x51B" .               # string B
          "\x10\x01" .            # int 1
          "\x10\x02" .            # int 2
          "\xD2\x00\x01\x02\x03" . # dict (0,1)=>(2,3)
          "\x09" .                # true
          "\x00" .                # null
          "\xA3\x05\x05\x06" .    # array (5,5,6)
          "\xD2\x00\x01\x07\x04". # dict (0,1)=>(7,4)
          "\xA3\x04\x08\x08".     # array (4,8,8)
          "\x08\x0A\x0C\x0E\x10\x15\x16\x17\x1B\x20" .    # offsets
          "\0\0\0\0\0\0\x01\x01" .  # sizes
          "\0\0\0\0\0\0\0\x0A" .  # object count
          "\0\0\0\0\0\0\0\x09" .  # rootid
          "\0\0\0\0\0\0\0\x24";   # offset-offset
is($val, $expect, 'more complex structure') || diag Dumper([$val, $expect]);

##
# Test some unwritable structures.
#

eval {
    $val = as_string( [ sub { 32; } ] );
};
isnt($@, '', "writing a subroutine reference should fail");

{
    my($d1) = { 'A' => 'aye', 'B' => 'bee' };
    my($d2) = { 'A' => 'aye', 'B' => $d1 };
    $d1->{B} = $d2;
    
    eval { $val = as_string($d1); };
    like($@, qr/Recursive/, "recursive data structure");
}


1;
