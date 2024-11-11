#!/bin/bash
set -e

# ビルド
make -C lambda/
make -C authorizer/