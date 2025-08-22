#!/bin/bash

PREFIX=/opt/venv/lib/python3.12/site-packages

cp lmcache/cache_engine.py "$PREFIX/lmcache/v1/cache_engine.py"
rm -rf "$PREFIX/lmcache/v1/__pycache__"
cp lmcache/gds_backend.py "$PREFIX/lmcache/v1/storage_backend/gds_backend.py"
rm -rf "$PREFIX/lmcache/v1/storage_backend/__pycache__"