# terraform-learning

Files related to learning how to use Terraform.

Different branches have the same basic AWS setup idea in different states:

- master - original one file configuration
- one-file-with-comments - one file configuration with lots of comments
- provisioners-example - examples of using TF's provisioners
- modularize - broke up the configuration into modules
- use-tf-registry-module - replaced one of the local modules with an AWS module from the TF registry
- use-remote-state - added directive to use remote state with S3 as the backend
