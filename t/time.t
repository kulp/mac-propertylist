#!/usr/bin/env perl

use Test::More;

my $class = 'Mac::PropertyList';
use_ok( $class ) or BAIL_OUT( "$class did not compile\n" );

use Time::HiRes qw(tv_interval gettimeofday);

my $data = do {
	local @ARGV = qw(plists/com.apple.iTunes.plist);
	do { local $/; <> };
	};

my $time1 = [ gettimeofday ];
my $plist = Mac::PropertyList::parse_plist( $data );
my $time2 = [ gettimeofday ];

my $elapsed = tv_interval( $time1, $time2 );
print STDERR "Elapsed time is $elapsed\n";

ok($elapsed < 3, "Parsing time test");

done_testing();
