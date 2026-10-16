# AWS backup and disaster-recovery lab

Terraform configuration and Lambda scripts for AWS backup and cross-region recovery experiments.

Explain recovery objectives, S3 versioning/replication, backup consistency, permissions, and how a restore would be verified.

[Reviewer guide](INTERVIEW.md) · [DevOps portfolio](https://github.com/Vishnu063/Vishnu063/blob/main/PORTFOLIO.md)

## Project status

Source is available for review. Runtime and deployment behavior were not newly verified in this documentation pass.

## Source map\n\n- [lambda/cross_region_copy.py](lambda/cross_region_copy.py)\n- [lambda/deploy.sh](lambda/deploy.sh)\n- [lambda/requirements.txt](lambda/requirements.txt)\n- [scripts/test_dr.sh](scripts/test_dr.sh)\n- [terraform/main.tf](terraform/main.tf)\n- [terraform/variables.tf](terraform/variables.tf)
