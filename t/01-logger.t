#!/usr/bin/env perl
# ABOUTME: Test suite for Commonplacebook::Logger module
# ABOUTME: Validates logging functionality, file handling, and message formatting

use 5.034;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use FindBin;
use lib "$FindBin::Bin/../lib";

# Test 1: Module loads
use_ok('Commonplacebook::Logger') or BAIL_OUT("Cannot load Commonplacebook::Logger");

# Test 2: Constructor without file (disabled logging)
my $logger = Commonplacebook::Logger->new();
ok($logger, "Logger created without log file");
isa_ok($logger, 'Commonplacebook::Logger');

# Test 3: Logging when disabled should not crash
my $result = eval { $logger->log("Test message"); 1 };
ok($result, "Logging when disabled does not crash");

# Test 4: Constructor with file (enabled logging)
my ($fh, $filename) = tempfile(UNLINK => 1);
close $fh; # Close it so Logger can open it

my $file_logger = Commonplacebook::Logger->new(file => $filename);
ok($file_logger, "Logger created with log file");

# Test 5: Logging writes to file
$file_logger->log("Test message 1");
$file_logger->log("Test message 2");

open my $log_fh, '<', $filename or die "Cannot open log file: $!";
my @lines = <$log_fh>;
close $log_fh;

is(scalar(@lines), 2, "Two log messages written");
like($lines[0], qr/\[MCP Server\] Test message 1/, "First message formatted correctly");
like($lines[1], qr/\[MCP Server\] Test message 2/, "Second message formatted correctly");

# Test 6: Logger from ENV variable
{
    local $ENV{LOG_FILE} = $filename;
    my $env_logger = Commonplacebook::Logger->new();
    ok($env_logger, "Logger created from ENV variable");
    $env_logger->log("ENV test");
}

done_testing();
