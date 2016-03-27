## VyOS config-sync

This replicates the functionality of the commercial version of Vyatta's config-sync for VyOS and community Vyatta editions.

#### Installation

To install the prepackaged version, run the following:

    $ wget https://github.com/keshavdv/vyattta-config-sync/releases/download/v0.0.1/vyatta-config-sync_0.0.1_all.deb
    $ sudo dpkg -i vyatta-config-sync_0.0.1_all.deb

To compile a debian package yourself, run the following:

    $ https://github.com/keshavdv/vyattta-config-sync/archive/master.zip
    $ # Extract, install build dependencies
    $ dpkg-buildpackage -us -uc

#### Issues

This is *alpha* software! It attempts to follow the same API as the commercial config-sync tool but has a very hacked together implementation. Only use it to sync non-critical sections of config like nat or firewall rules to ensure you don't kick yourself out of the device.

#### Usage

Basic synchronization is setup via:

    set system config-sync sync-map slave rule 10 action include
    set system config-sync sync-map slave rule 10 location "nat"

    set system config-sync sync-map slave rule 20 action include
    set system config-sync sync-map slave rule 20 location "firewall"

    # the local user must be able to SSH to the remote host with the specified username
    # with passwordless authentication
    set system config-sync remote-router <remote-host> username <username>
    set system config-sync remote-router <remote-host> sync-map slave

    commit # Will automatically sync config

    # If you want, you can manually run a sync or view the latest status
    run update config-sync <remote-host>
    show config-sync status