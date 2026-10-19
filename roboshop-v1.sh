#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="devopsaws92s.shop"
hosted_zone_id="Z07233552T9R7ZHDVMAP4"

for instance in $@
do
    echo "Creating instance: $instance"
