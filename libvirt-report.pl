#!/usr/bin/perl
#
# Copyright (C) 2014 Oliver Hitz <oliver@net-track.ch>
#
use Digest::SHA qw(sha1_hex);
use Getopt::Long;
use XML::XPath;
use Sys::Virt;
use strict;

my $configfile = "/etc/libvirt-report.conf";

# Expressions to shorten the hostname part in the reports.
# By default it will strip off the domain part.
my $hostname_rewrite_match = q/([^\.]*)\..*$/;
my $hostname_rewrite_replace = '"$1"';

if (!GetOptions("config=s" => \$configfile)) {
  print "Usage: $0 [--config=libvirt-report.conf]\n";
  exit 1;
}

my $clusters;

# Read configuration file
my %config;

open(FILE, $configfile) || die "Failed to open $configfile\n";
my @lines = <FILE>;
close(FILE);
eval("@lines");
die "Failed to eval() file $configfile:\n$@\n" if ($@);

my $report = "";

# Title
my $hostname = `hostname -f`;

chomp $hostname;

$report .= "libvirt-report.pl run on $hostname\n";
$report .= "\n";

foreach my $cluster_name (sort { $clusters->{$a}->{order} <=> $clusters->{$b}->{order} } keys %{ $clusters }) {

  my $cluster = $clusters->{$cluster_name};
  $cluster->{domains} = {};

  $report .= sprintf("Cluster: %s\n", $cluster_name);

  foreach my $member_name (@{ $cluster->{members} }) {
    my $vsys = Sys::Virt->new(uri => sprintf("qemu+ssh://%s/system", $member_name));
    foreach my $vdom ($vsys->list_domains(), $vsys->list_defined_domains()) {
      my $domain_name = $vdom->get_name;

      my $domain = $cluster->{domains}->{$domain_name};
      if (! defined $domain) {
	$domain = {
	  name => $domain_name,
	  hosts => {},
	  ram => 0,
	  cpus => 0,
          running => 0,
	};
	$cluster->{domains}->{$domain_name} = $domain;
      }

      my $info = $vdom->get_info;

      my $xml = $vdom->get_xml_description(Sys::Virt::Domain::XML_INACTIVE);

      # Strip seclabel tags from the XML representation. These are somehow
      # popping up and may result in bogus mismatch messages.
      $xml =~ s|<seclabel type='none'/>||g;

      # Strip whitespace so we can compare the XML strings.
      $xml =~ s/\s//g;

      $domain->{hosts}->{$member_name} = {
	xml => $xml,
	info => $info
      };

      if ($info->{state} == Sys::Virt::Domain::STATE_RUNNING) {
        $domain->{running} = 1;
	$domain->{run_ram} = $info->{maxMem} / 1024;
	$domain->{run_cpus} = $info->{nrVirtCpu};
	$domain->{run_xml} = $domain->{hosts}->{$member_name}->{xml};
      }
    }
  }

  my $title = sprintf("%-20s %5s %3s ",
		      "Domain",
		      "RAM",
		      "CPU");
  my $title_ul = sprintf("%-20s %5s %3s ",
		      "--------------------",
		      "-----",
		      "---");

  foreach my $member_name (@{ $cluster->{members} }) {
    my $name = $member_name;
    $name =~ s/$hostname_rewrite_match/$hostname_rewrite_replace/ee;

    $title .= sprintf("%-16s ", $name);
    $title_ul .= sprintf("%-16s ", "----------------");
  }
  $title .= "\n";
  $title_ul .= "\n";

  $report .= $title;
  $report .= $title_ul;

  foreach my $domain_name (sort keys %{ $cluster->{domains} }) {
    my $domain = $cluster->{domains}->{$domain_name};

    my $host_status = "";

    foreach my $member_name (@{ $cluster->{members} }) {

      if (defined $domain->{hosts}->{$member_name}) {
        if ($domain->{running} && ($domain->{run_xml} ne $domain->{hosts}->{$member_name}->{xml})) {
	  $host_status .= sprintf("%-16s ",
				  "*mismatch*");
	} else {
	  $host_status .= sprintf("%-16s ",
				  state_string($domain->{hosts}->{$member_name}->{info}->{state}));
	}	
      } else {
	$host_status .= sprintf("%-16s ", "*missing*");
      }
    }

    $report .= sprintf("%-20s %5d %3d %s\n",
		       $domain->{name},
		       $domain->{run_ram},
		       $domain->{run_cpus},
		       $host_status);
  }

  $report .= "\n";
}

print $report;

exit 0;

sub state_string
{
  my $state = shift;

  if ($state == Sys::Virt::Domain::STATE_NOSTATE) {
    return "nostate";
  } elsif ($state == Sys::Virt::Domain::STATE_RUNNING) {
    return "running";
  } elsif ($state == Sys::Virt::Domain::STATE_BLOCKED) {
    return "blocked";
  } elsif ($state == Sys::Virt::Domain::STATE_PAUSED) {
    return "paused";
  } elsif ($state == Sys::Virt::Domain::STATE_SHUTDOWN) {
    return "shutdown";
  } elsif ($state == Sys::Virt::Domain::STATE_SHUTOFF) {
    return "shutoff";
  } elsif ($state == Sys::Virt::Domain::STATE_CRASHED) {
    return "crashed";
  } elsif ($state == Sys::Virt::Domain::STATE_PMSUSPENDED) {
    return "pmsuspended";
  } else {
    return "<unknown>";
  }
}

