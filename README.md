# ebs_volume_attachement
This script can mount EBS volumes attached to the instance as a user data

# Instructions
Volume should have tag where to be mounted. Eg - if vol-123123121 is need to mount on /x03 directory , there should be a tag for the volume with "mount = /x03", then Script will read the metadata and volume tags by itself and do the mounting part as user_data execution.

# Requirements 
aws cli should be installed in AMI
correct IAM policies ( service role ) should be attached to the the EC2 instance. 
