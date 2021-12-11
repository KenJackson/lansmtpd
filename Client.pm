# This is a modified version of this module in metacpan.org:
# https://fastapi.metacpan.org/source/MACGYVER/SMTP-Server-1.1/Server/Client.pm
#
# Install it in: /usr/share/perl5/Net/SMTP/Server/
#            or: /usr/local/share/perl5/Net/SMTP/Server/
#
package Net::SMTP::Server::Client;
require 5.001;

use strict;
use vars qw($VERSION @ISA @EXPORT);

require Exporter;
require AutoLoader;
use Carp;
use IO::Socket;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw();

$VERSION = '1.1.1';                     # Original author's v1.1

my %_cmds = (
	    DATA => \&_data,
	    EXPN => \&_expn,
	    HELO => \&_hello,
	    HELP => \&_help,
	    MAIL => \&_mail,
	    NOOP => \&_noop,
	    QUIT => \&_quit,
	    RCPT => \&_receipt,
	    RSET => \&_reset,
	    VRFY => \&_verify,
            EXITLOCALSERVER => \&_exit
	    );

# Utility functions.
sub _put {
    print {shift->{SOCK}} @_, "\r\n";
}

sub _reset {
    my $self = shift;
    
    $self->{FROM} = undef;
    $self->{TO} = [];
    
    $self->_put("250 Complete");
}

# New instance.
sub new {
    my($this, $sock, $hello) = @_;
    
    my $class = ref($this) || $this;
    my $self = {};
    $self->{FROM} = undef;
    $self->{TO} = [];
    $self->{MSG} = undef;
    $self->{SOCK} = $sock;
    
    bless($self, $class);
    
    croak("No client connection specified.") unless defined($self->{SOCK});
    $hello = "lansmtpd" unless defined($hello);
    $self->_put("220 ${hello} ready");
    return $self;
}

sub process {
    my $self = shift;
    my($cmd, @args);
    
    my $sock = $self->{SOCK};
    
    while(<$sock>) {
	# Clean up.
	chomp;
	s/^\s+//;
	s/\s+$//;
	goto bad unless length($_);
	
	($cmd, @args) = split(/\s+/);
	
	$cmd =~ tr/a-z/A-Z/;
	
	if(!defined($_cmds{$cmd})) {
	  bad:
	    $self->_put("500 Command not recognized");
	    next;
	}
	
	return(defined($self->{MSG}) ? 1 : 0) unless
	    &{$_cmds{$cmd}}($self, \@args);
    }

    return undef;
}

sub _fromto {
    my $self = shift;
    my($which, $var, $args) = @_;
    
    if(!($$args[0] =~ /^$which\s*([^\s]+)/i)) {
	if(!$$args[1] || !($$args[0] =~ /^$which$/i)) {
	    $self->_put("501 Syntax error.");
	    return -1;
	}
	
	ref($var) eq 'ARRAY' ? (push @$var, $$args[1]) : ($$var = $$args[1]);
    }
    
    ref($var) eq 'ARRAY' ? (push @$var, $1) : ($$var = $1) unless !defined($1);
    
    $self->_put("250 OK");
}

sub _mail {
    my $self = shift;
    return $self->_fromto('FROM:', \$self->{FROM}, @_);
}

sub _receipt {
    my $self = shift;
    return $self->_fromto('TO:', \@{ $self->{TO} }, @_);
}

sub _data {
    my $self = shift;
    my $done = undef;
    
    if(!defined($self->{FROM})) {
	$self->_put("503 Missing the FROM address");
	return 1;
    }
    
    if(!@{$self->{TO}}) {
	$self->_put("503 Missing destination address(es)");
	return 1;
    }

    $self->_put("354 Start mail input; end with <CRLF> <CRLF>");

    my $sock = $self->{SOCK};
    
    while(<$sock>) {
	if(/^\.\r\n$/) {
	    $done = 1;
	    last;
	}
	
	# RFC 821 compliance.
	s/^\.\./\./;
	$self->{MSG} .= $_;
    }
    
    if(!defined($done)) {
	$self->_put("550 Requested action not taken");
	return 1;
    }
    
    $self->_put("250 Received successfully");
}

sub _verify {
    shift->_put("252 Cannot verify user, but will attempt delivery");
}

sub _expn {
    shift->_put("502 Command not implemented");
}

sub _noop {
    shift->_put("250 OK");
}

sub _help {
    my $self = shift;
    my $i = 0;
    my $str = "214-Commands\r\n";
    my $total = keys(%_cmds);
    
    foreach(sort(keys(%_cmds))) {
	if(!($i++ % 5)) {
	    if(($total - $i) < 5) {
		$str .= "\r\n214 ";
	    } else {
		$str .= "\r\n214-";
	    }
	} else {
	    $str .= ' ';
	}
	
	$str .= $_;
    }
    
    $self->_put($str);
}

sub _quit {
    my $self = shift;
    
    $self->_put("221 Bye");
    $self->{SOCK}->close;
    return 0;
}

sub _hello {
    shift->_put("250 OK");
}

sub _exit {
    shift->_put("250 OK");
    exit 0;
}

1;
__END__
# POD begins here.

=head1 NAME

Net::SMTP::Server::Client - Client session handling for Net::SMTP::Server.

=head1 SYNOPSIS

  use Carp;
  use Net::SMTP::Server;
  use Net::SMTP::Server::Client;
  use Net::SMTP::Server::Relay;

  $server = new Net::SMTP::Server('localhost', 25) ||
    croak("Unable to handle client connection: $!\n");

  while($conn = $server->accept()) {
    # We can perform all sorts of checks here for spammers, ACLs,
    # and other useful stuff to check on a connection.

    # Handle the client's connection and spawn off a new parser.
    # This can/should be a fork() or a new thread,
    # but for simplicity...
    my $client = new Net::SMTP::Server::Client($conn) ||
	croak("Unable to handle client connection: $!\n");

    # Process the client.  This command will block until
    # the connecting client completes the SMTP transaction.
    $client->process || next;
    
    # In this simple server, we're just relaying everything
    # to a server.  If a real server were implemented, you
    # could save email to a file, or perform various other
    # actions on it here.
    my $relay = new Net::SMTP::Server::Relay($client->{FROM},
					     $client->{TO},
					     $client->{MSG});
  }

=head1 DESCRIPTION

The Net::SMTP::Server::Client module implements all the session
handling required for a Net::SMTP::Server::Client connection.  The
above example demonstrates how to use Net::SMTP::Server::Client with
Net::SMTP::Server to handle SMTP connections.

$client = new Net::SMTP::Server::Client($conn, "lansmtpd")

Net::SMTP::Server::Client accepts one argument that must be a handle
to a connection that will be used for communication, and an optional
argument that is the name of the server returned in the handshake.

Once you have a new client session, simply call:

$client->process

This processes an SMTP transaction.  THIS MAY APPEAR TO HANG --
ESPECIALLY IF THERE IS A LARGE AMOUNT OF DATA BEING SENT.  Once this
method returns, the server will have processed an entire SMTP
transaction, and is ready to continue.

Once $client->process returns, various fields have been filled in.
Those are:

  $client->{TO}    -- This is an array containing the intended
                      recipients for this message.  There may be
                      multiple recipients for any given message.

  $client->{FROM}  -- This is the sender of the given message.
  $client->{MSG}   -- The actual message data. :)

=head1 AUTHOR AND COPYRIGHT
Net::SMTP::Server / SMTP::Server is Copyright(C) 1999, 
  MacGyver (aka Habeeb J. Dihu) <macgyver@tos.net>.  ALL RIGHTS RESERVED.

You may distribute this package under the terms of either the GNU
General Public License or the Artistic License, as specified in the
Perl README file. 

=head1 SEE ALSO

Net::SMTP::Server::Server, Net::SMTP::Server::Relay

=cut
