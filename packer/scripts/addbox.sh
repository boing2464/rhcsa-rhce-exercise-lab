#!/bin/bash

provider=`echo $PACKER_BUILDER_TYPE| awk -F'-' '{print $1}'`
vagrant box add $BOX_NAME-$provider box_out/$BOX_NAME-$provider.box

