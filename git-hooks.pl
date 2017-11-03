#!/usr/bin/env perl
## vim: ts=4:sw=4:expandtab:shiftround
use strict;
use warnings;

use Regexp::Common qw /net/;
use Scalar::Util 'blessed';
use JIRA::REST;
use Git::Hooks;
use Try::Tiny;
use Carp qw(cluck confess);

our %cache;

my $osx_kernel = qr/darwin/i;
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
    my $current = _current_server();

    return 1 if $current eq '*';

    if (not $current) {
        _error("Cannot find current server");
        return;
    }

    my $target  = _target_server($key);

    return 1 if $current eq '*';
    return 1 if grep { $current eq $_ } @$target;
}

sub _target_server {
    my $key = shift;
    my $target = $config->{$key}{target_server};

    if (not $target) {
         _error("No target server found for $key");
        return [];
    }
    elsif (not @$target) {
        _error("Invalid data structure found for target server");
        return [];
    }

    return $target;
}

sub _ip_addr {
    if (_is_linux()) {
        my ($addr) = split ' ', `hostname -I`;
        return $addr;
    }
    elsif (_is_osx()) {
        return `ipconfig getifaddr en0`;
    }
    else {
        _error('Unsupported OS');
    }

    return;
}

sub _hostname {
    $cache{current_server} ||= `hostname`;

    return $cache{current_server};
}

sub _is_linux         { `uname -a` =~ /linux/ }
sub _is_osx           { `uname -a` =~ $osx_kernel }
sub _current_server   { _looks_like_ipv4(shift) ? _hostname() : _ip_addr() }
sub _looks_like_ipv4  { shift =~ /$RE{net}{IPv4}/ }
sub _error            { $ENV{GIT_HOOK_DEBUG} ? cluck shift : return }

exit 0;

