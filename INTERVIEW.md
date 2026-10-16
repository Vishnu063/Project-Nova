# AWS backup and disaster-recovery lab: reviewer guide

Terraform configuration and Lambda scripts for AWS backup and cross-region recovery experiments.

## Start the review

Explain recovery objectives, S3 versioning/replication, backup consistency, permissions, and how a restore would be verified.

| Source | Review focus |\n| --- | --- |\n| [lambda/cross_region_copy.py](lambda/cross_region_copy.py) | Implementation, assumptions, and operational boundaries |\n| [lambda/deploy.sh](lambda/deploy.sh) | Implementation, assumptions, and operational boundaries |\n| [lambda/requirements.txt](lambda/requirements.txt) | Implementation, assumptions, and operational boundaries |\n| [scripts/test_dr.sh](scripts/test_dr.sh) | Behavior covered, fixtures used, and remaining gaps |\n| [terraform/main.tf](terraform/main.tf) | Inputs, state, permissions, cost, and resource lifecycle |\n| [terraform/variables.tf](terraform/variables.tf) | Inputs, state, permissions, cost, and resource lifecycle |

## A useful interview walkthrough

1. State the problem and the specific part you implemented or changed.
2. Open the source above and follow one request, release, or failure from start to finish.
3. Show a reproducible result, including an actual failure and the observation that confirms recovery.
4. Explain one tradeoff and one limitation. Distinguish a local test from a live deployment.

## Evidence and limits

This guide is based on the default-branch source inspected on 16 October 2026. It is a source review, not a fresh deployment or a certification of every feature. Existing CI runs and tests should be checked at the commit being demonstrated. Do not present screenshots, inherited code, planned features, or old README statements as proof of a current deployment.
