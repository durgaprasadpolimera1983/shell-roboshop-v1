#!/bin/bash
ami_id="ami-0220d79f3f480ecf5"
instance_type="t3.micro"
domain_name="daws92s.store"
hosted_zone_id="Z01595761DU8O4AX48D6A"

for instance in $@
do
    echo "Creating instance: $instance"
