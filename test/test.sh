#!/bin/bash

echo begin
sleep 10
echo adding stack
echo -ne '\033[31;1m'
curl -XPOST -F 'file=@sample.yml' watcher:3000/sample
curl -XPOST -F 'file=@sample2.yml' watcher:3000/
echo -e '\033[m'
echo added stack
echo byebye
