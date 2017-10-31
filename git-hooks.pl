#!/usr/bin/env perl
use strict;
use warnings;

use JIRA::REST;
use Git::Hooks;
use Try::Tiny;
use Carp qw(cluck confess);

my $config;

BEGIN {
    if (-f $ENV{GIT_HOOK_CONFIG}) {
        my $xs = try {
            require YAML::XS;
            YAML::XS->import('LoadFile');
            1;
        };

        if (not $xs) {
            try {
                require YAML;
                YAML->import('LoadFile');
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
    username => $config->{jira_username}  // $ENV{JIRA_USER},
    password => $config->{jira_pass}      // $ENV{JIRA_PASS},
});

PRE_PUSH sub { parse_msg(@_, _transition('pre-push')) };

run_hook $0, @ARGV;

sub parse_msg {
    my ($git, $msg, $transition) = @_;

    my $branch  = $git->run('git rev-parse --abbrev-ref HEAD');
    my $out     = $git->run("git log origin/$branch..master");

    my $tickets = _parse_log($out);

    return unless $transition;

    foreach my $tick (@$tickets) {
        return unless $transition;

        my ($prefix, $num) = split '-', $tick;

        if (not $prefix and not $num) {
            _error("No ticket info found");
            return;
        }

        advance_ticket($transition, $prefix, $num);
    }
}

sub advance_ticket {
    my ($transition, $prefix, $num) = @_;

    my $resp;
    try {
        my $issue = "$prefix-$num";

        $resp = $jira->POST(
            'issue/' . $issue . '/transitions',
            undef,
            { transition => $transition },
        );
    } catch {
        cluck $_;
    };

    return;
}

sub _transition {
    my $key = shift;
    my $transition = $config->{transitions}->{$key};

    if (not $transition) {
        _error("No transition found for $key");
        return;
    }

    return $transition;   
}

sub _parse_log {
    my $out = shift;

    my @matches = $out =~ /(\[\w+-\d+\])/g;
    return \@matches; 
}

sub _error { $ENV{GIT_HOOK_DEBUG} ? return cluck shift : return }

exit 0;

