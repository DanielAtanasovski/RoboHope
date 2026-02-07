#!/usr/bin/env python3
"""
Simple test script for RoboHope RL Server (Phase 1)
Connects to localhost:9999 and tests reset/step cycle
"""

import socket
import json
import time

class RLServerTester:
    def __init__(self, host="localhost", port=9999):
        self.host = host
        self.port = port
        self.socket = None

    def connect(self):
        """Connect to RL Server"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.host, self.port))
            print(f"✓ Connected to {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"✗ Failed to connect: {e}")
            return False

    def send_command(self, cmd: dict) -> dict:
        """Send JSON command and receive JSON response"""
        try:
            # Send
            json_str = json.dumps(cmd) + "\n"
            self.socket.sendall(json_str.encode())
            print(f"→ Sent: {json_str.strip()}")

            # Receive
            response_data = self.socket.recv(4096).decode()
            response = json.loads(response_data.strip())
            print(f"← Received: {json.dumps(response, indent=2)}")
            return response
        except Exception as e:
            print(f"✗ Error: {e}")
            return None

    def test_reset(self, seed=42):
        """Test reset command"""
        print("\n--- Testing RESET ---")
        response = self.send_command({"cmd": "reset", "seed": seed})
        if response and "obs" in response:
            print(f"✓ Reset successful. Obs size: {len(response['obs'])}")
            return True
        else:
            print("✗ Reset failed")
            return False

    def test_steps(self, num_steps=10):
        """Test multiple step commands"""
        print(f"\n--- Testing {num_steps} RANDOM STEPS ---")
        import random

        for step in range(num_steps):
            action = random.randint(0, 10)  # Random action
            response = self.send_command({"cmd": "step", "action": action})

            if not response or "obs" not in response:
                print(f"✗ Step {step} failed")
                return False

            obs = response.get("obs", [])
            done = response.get("done", False)
            events = response.get("info", {}).get("events", {})

            # Calculate example reward (agent would do this)
            example_reward = self._calculate_example_reward(events)

            print(f"  Step {step}: action={action}, reward={example_reward:.4f}, done={done}")
            if events and any(events.values()):
                print(f"    Events: {events}")

            if done:
                print(f"✓ Episode ended at step {step}")
                break

        print(f"✓ Completed {num_steps} steps")
        return True

    def _calculate_example_reward(self, events: dict) -> float:
        """Example reward calculation (agent would implement this)"""
        reward = 0.0

        # Avoids farming: only big rewards for progress
        if events.get("rocket_launched"):
            reward += 100.0
        if events.get("nest_destroyed", 0) > 0:
            reward += 20.0 * events["nest_destroyed"]
        if events.get("crystals_collected", 0) > 0:
            reward += 10.0 * events["crystals_collected"]

        # Penalties
        if events.get("player_died"):
            reward -= 20.0
        if events.get("factory_destroyed"):
            reward -= 10.0
        reward -= 0.01 * events.get("damage_taken", 0)

        # Time penalty (encourages speed)
        reward -= 0.005

        return reward

    def close(self):
        """Close connection"""
        if self.socket:
            self.send_command({"cmd": "close"})
            self.socket.close()
            print("✓ Connection closed")

def main():
    print("RoboHope RL Server Phase 1 Tester")
    print("=" * 40)

    tester = RLServerTester()

    if not tester.connect():
        return

    tests_passed = 0
    tests_total = 2

    # Test 1: Reset
    if tester.test_reset(seed=42):
        tests_passed += 1

    time.sleep(0.5)

    # Test 2: Steps
    if tester.test_steps(num_steps=10):
        tests_passed += 1

    tester.close()

    print("\n" + "=" * 40)
    print(f"Results: {tests_passed}/{tests_total} tests passed")

    if tests_passed == tests_total:
        print("✓ Phase 1 Milestone PASSED!")
    else:
        print("✗ Some tests failed")

if __name__ == "__main__":
    main()
