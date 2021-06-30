# rhcsa-rhce-exercise-lab
Redhat exercises lab

Contents:
                                                         
Lab directory structure:

~/infrastructure
├── env.rhce
├── packer
│   ├── build.boxes
│   ├── http
│   │   ├── ISO -> /ISO
│   │   └── kickstart -> ../kickstart
│   ├── ISO -> /ISO
│   ├── kickstart
│   │   ├── ks-rhel-graph-virtualbox.cfg
│   │   ├── ks-rhel-graph-vmware.cfg
│   │   ├── ks-rhel-text-virtualbox.cfg
│   │   └── ks-rhel-text-vmware.cfg
│   ├── README
│   ├── scripts
│   │   ├── addbox.sh
│   │   └── packer_virtualbox.sh
│   ├── templates
│   │   └── rhel.rhce.pkr.hcl
│   └── vars
│       ├── rhel84graph.pkvars.hcl
│       └── rhel84text.pkvars.hcl
├── README
├── rhce.up
├── rhcsa.up
└── vagrant
    ├── config
    │   └── rhce-lab-config.yml
    ├── README
    ├── scripts
    │   └── rhce
    │       └── setupUtility.sh
    └── templates
        └── Vagrant-rhce-lab

This directory contains 3 bash scripts to start your lab:
build    - to build images and boxes
rhce.up  - start up rhce lab
rhcsa.up - start up rhcsa lab
