#!/bin/bash

curdir=$(dirname $(realpath $0))

cd ../local-runner-ru
sh local-runner.sh
cd $curdir
sleep 3
#nim c -d:stdebug runner.nim
nim c -d:drawPFGrid runner.nim
#nim c runner.nim
#nim c -d:release runner.nim
#nim c --debugger:native runner.nim
#nim c --linedir:on --debuginfo -d:stdebug runner.nim
bash -c 'sleep 2; ./runner "127.0.0.1" "31002" "0000000000000000" &> second.log' &
#gdb ./runner
#./runner
#valgrind --tool=callgrind ./runner
./runner | sed -n 's/^!//p' | python plotter.py
