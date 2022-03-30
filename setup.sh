#!/bin/bash

python3 -m venv pyvenv || exit 1
source pyvenv/bin/activate || exit 1
pip install elasticsearch || exit 1
pip install packaging

exit 0
