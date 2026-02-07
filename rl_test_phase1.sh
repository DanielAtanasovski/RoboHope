#!/bin/bash
# Simple netcat test for RLServer (Phase 1)
# Usage: bash rl_test_phase1.sh

echo "RoboHope RL Server Phase 1 Netcat Test"
echo "======================================"
echo ""
echo "Testing reset command..."
echo '{"cmd": "reset", "seed": 42}' | nc localhost 9999
echo ""
echo "Testing step command (action 0 = noop)..."
echo '{"cmd": "step", "action": 0}' | nc localhost 9999
echo ""
echo "Testing another step..."
echo '{"cmd": "step", "action": 1}' | nc localhost 9999
echo ""
print "Remember: Start Godot with --rl-mode flag first!"
