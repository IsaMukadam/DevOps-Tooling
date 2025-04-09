#!/usr/bin/env bash
npm i -g aws-cdk
cdk init app --language python
pip install aws-cdk-lib
pip install constructs
pip install --upgrade aws-cdk.core aws-cdk.aws-s3