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
    username => $config->{jira_username}  // $ENV{JIRA_USERNAME},
    password => $config->{jira_password}  // $ENV{JIRA_PASSWORD},
});

PRE_PUSH sub { parse_msg('pre-push') };

run_hook $0, @ARGV;

sub parse_msg {
	my $transition = _transition(shift);

    return unless $transition;

    my $out     = `git log origin/master..HEAD`;
    my $tickets = _parse_log($out);

    return unless @$tickets;

    foreach my $tick (@$tickets) {
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
    my $transition = $config->{transitions}->{$key};

    if (not $transition) {
        _error("No transition found for $key");
        return;
    }

    return $transition;   
}

sub _parse_log {
    my $out = shift;

    my @matches = $out =~ /\[(\w+-\d+)\]/g;
	my %seen    = ();

    return [ grep { !$seen{$_}++ } @matches ];
}

sub _error { $ENV{GIT_HOOK_DEBUG} ? return cluck shift : return }

exit 0;

