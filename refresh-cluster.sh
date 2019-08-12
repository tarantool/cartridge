#!/bin/bash

sh stop.sh && rm -rf ./dev && (sh start.sh & ls -lah)
