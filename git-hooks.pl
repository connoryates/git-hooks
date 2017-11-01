#!/usr/bin/env perl
use strict;
use warnings;

use Regexp::Common qw /net/;
use Scalar::Util 'blessed';
use IO::Socket::INET;
use JIRA::REST;
use Git::Hooks;
use Try::Tiny;
use Carp qw(cluck confess);

my $config;

BEGIN {
    if (-f $ENV{GIT_HOOK_CONFIG}) {
        my $xs = try {
            require YAML::XS;
            YAML::XS->import('LoadFile', 'Dump');
            1;
        };

        if (not $xs) {
            try {
                require YAML;
                YAML->import('LoadFile', 'Dump');
            } catch {
                confess "No YAML parser found. Please install either YAML::XS (recommended) or YAML";
            };
        }

        $config = LoadFile($ENV{GIT_HOOK_CONFIG});
    }
    else {
        confess "No config file found. Please create a YAML config file and export it to ENV{GIT_HOOK_CONFIG}";
    }
};

my $jira = JIRA::REST->new({
    url      => $config->{jira_url}       // $ENV{JIRA_URL},
    username => $config->{jira_username}  // $ENV{JIRA_USERNAME},
    password => $config->{jira_password}  // $ENV{JIRA_PASSWORD},
});

PRE_PUSH   sub { parse_commits('pre-push') };
POST_MERGE sub { parse_commits('post-merge') };

run_hook $0, @ARGV;

sub parse_commits {
    my $stage = shift;

    my $target     = _target_branch($stage);
    my $transition = _transition($stage);

    return unless $transition;
    return unless _server_ok();

    return if not $target or _current_branch() eq $target;

    my $out     = `git log origin/$target..HEAD`;
    my $tickets = _parse_log($out);

    return unless @$tickets;

    foreach my $tick (@$tickets) {
        my ($prefix, $num) = split '-', $tick;

        if (not $prefix and not $num) {
            _error("No ticket info found");
            return;
        }

        _advance_ticket($transition, $prefix, $num);
    }
}

sub _advance_ticket {
    my ($transition, $prefix, $num) = @_;

    try {
        my $issue = "$prefix-$num";

        print "Updating issue: $issue\n";

        my $resp = $jira->POST(
            '/issue/' . $issue . '/transitions?expand=transitions.fields',
            undef,
            {
                transition => {
                    id => 0 + $transition
                }
            }
       );
    } catch {
        cluck $_;
    };

    return;
}

sub _transition {
    my $key = shift;
    my $transition = $config->{$key}{transition};

    if (not $transition) {
        _error("No transition found for $key");
        return;
    }

    return $transition;   
}

sub _target_branch {
    my $key    = shift;
    my $target = $config->{$key}{target_branch};

    if (not $target) {
        _error("No target_branch found for $key");
        return;
    }

    return $target;
}

sub _parse_log {
    my $out = shift;

    my @matches = $out =~ /\[(\w+-\d+)\]/g;
    my %seen    = ();

    return [ grep { !$seen{$_}++ } @matches ];
}

sub _current_branch {
    my $out = `git rev-parse --abbrev-ref HEAD`;

    chomp($out);

    return $out;
}

sub _server_ok {
    my $key = shift;
    my $target  = _target_server($key);
    my $current = _current_server();

    if (not $current) {
        _error("Cannot find current server");
        return;
    }

    return 1 if $current eq '*';
    return $current eq $target;
}

sub _target_server {
    my $key = shift;
    my $target = $config->{$key}{target_server};

    if (not $target) {
         _error("No target server found for $key");
        return;
    }

    return $target;
}

sub _current_server {
    my $socket = try {
        IO::Socket::INET->new(
            Proto    => 'udp',
            PeerAddr => '198.41.0.4', # a.root-servers.net
            PeerPort => '53', # DNS
        );
    };

    return unless blessed $socket;

    my $addr = $socket->sockhost;

    return _looks_like_ipv4($addr) ? _dns_or_ip($addr) : $addr;
}

sub _dns_or_ip {
    my $addr = shift;

    return unless $addr;

    if (my $cached = _dns_cache($addr)) {
        return $cached;
    }

    my $name = gethostbyaddr($addr, AF_INET);

    return $name ? _extract_dns($name) : $addr;
}

sub _dns_cache {
    my $addr = shift;

    my $cache_dir = $ENV{GIT_HOOK_CACHE} // '/tmp';

    if (-d $cache_dir) {
        my $file = "$cache_dir/git-hook-cache";

        if (-f $file) {
            my $cache = LoadFile($file);

            return $cache->{$addr} if $cache->{$addr};

            open(my $fh, '>>', $file);
            print $fh Dump({ $addr => 1 });
        }
        else {
            open(my $fh, '>', $file);
            print $fh Dump({ $addr => 1 });
        }
    }

    return;
}

sub _extract_dns     { shift =~ /\.ip\.(.+)\.(?:net|com|org|us|eu)/ } 
sub _looks_like_ipv4 { shift =~ /$RE{net}{IPv4}/ }
sub _error           { $ENV{GIT_HOOK_DEBUG} ? cluck shift : return }

exit 0;

