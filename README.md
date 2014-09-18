libvirt-report
==============

A simple script that gives a report of which domain is running on
which server. It also verifies if the domains which are installed on
two servers (i.e. synchronized via DRBD or installed on shared
storage) are identical.


Requirements
------------

Requires the following perl libraries: XML::XPath, Sys::Virt

On Debian systems, these can be installed using `apt-get install
libxml-xpath-perl libsys-virt-perl`.


Configuration
-------------

See the included libvirt-report.conf.dist file for an example. By
default, libvirt-report.pl expects the configuration in
`/etc/libvirt-report.conf`, but this can be changed on the command
line.

It is important to make sure that SSH connectivity to the hosts
defined in the `members` arrays works properly. To test if you can
connect via libvirt, use the following:

    virsh -c qemu+ssh://<hostname>/system list

If this works, libvirt-report should work, too.


Running
-------

Just invoke libvirt-report.pl and it will print a report:

    libvirt-report.pl

If the configuration isn't it `/etc/`, specify its location using the
`--config` command line option.


Example reports
---------------

Example report for domains installed on a single server:

    Cluster: cluster1
    Domain                 RAM CPU host1
    -------------------- ----- --- ---------------- 
    domain1               8192   6 running          
    domain2               1024   1 running          
    domain3               2048   2 running          
    domain4               1024   1 shutoff

Example report for domains installed on `cluster2` comprised of two
servers `host2a` and `host2b`:

    Cluster: cluster2
    Domain                 RAM CPU host2a           host2b
    -------------------- ----- --- ---------------- ---------------- 
    domain1               8192   2 shutoff          running          
    domain2               1024   4 running          shutoff          
    domain3               2048   2 running          *mismatch*          
    domain4               2048   1 *missing*        running
