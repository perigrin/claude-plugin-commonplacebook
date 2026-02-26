# ABOUTME: Logging service for Commonplacebook plugin
# ABOUTME: Provides optional file-based logging with MCP Server message formatting

package Commonplacebook::Logger;

use 5.034;
use warnings;
use experimental qw(signatures);

sub new ($class, %args) {
    my $file = $args{file} // $ENV{LOG_FILE};
    my $enabled = 0;

    if ($file) {
        open STDERR, ">>", $file or die "Failed to open log file: $!";
        $enabled = 1;
    }

    my $self = {
        file => $file,
        enabled => $enabled,
    };

    return bless $self, $class;
}

sub log ($self, $message) {
    return unless $self->{enabled};
    say STDERR "[MCP Server] $message";
}

1;
