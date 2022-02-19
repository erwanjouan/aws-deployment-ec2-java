#!/bin/bash

ps -ef | grep app.jar | grep -v grep | awk '{print $2}' | xargs kill