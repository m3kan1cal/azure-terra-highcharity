## Introduction

This is a multi-episode series of projects anchored on Azure's cloud platform and Hashicorp's Terraform framework, partially to teach myself more about these services, and also to share with others that may be trying to build an Enterprise cloud environment from the ground up.

If you’re interested in my opinions on the services involved, see this post: https://medium.com/@shouldroforion/azure-terraform-some-quick-observations-through-a-weekend-of-failfastshareoften-9bffc310c372.

We’ll start slow, then ramp up to a fully blown Enterprise cloud network with DevOps, serverless, and other cool marketing buzzwords. The project itself I’ve coined Project: High Charity, named after a pseudo-planet in my favorite sci-fi universe.

## Episodes

[Episode 1: Building a Basic Bastion/Worker Host Virtual Network](vnet/README.md)

Episode 1 of this series is comprised of an Azure subscription, the free version of Terraform, and a virtual network with a public subnet hosting a bastion host for jumping to worker hosts deployed to a private subnet. It’s a basic start for an enterprise-y network with the intent of segmenting off networks for security.
