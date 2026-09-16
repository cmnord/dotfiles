#!/usr/bin/env python3
"""Docker, Colima and df stand-ins for isolated cleanup validation."""

import json
import os
import sys
from pathlib import Path

tool, args = Path(sys.argv[0]).name, sys.argv[1:]
home = Path(os.environ["HOME"])
if tool == "df":
    counter = home / "df-count"
    count = int(counter.read_text()) if counter.exists() else 0
    available = 60
    if args[0] == "-k":
        available = 60 * 1024 * 1024 + count * 2048
        counter.write_text(str(count + 1))
    print("Filesystem blocks used available")
    print("fixture 100000000 0", available)
    sys.exit(0)

with (home / "calls").open("a") as f:
    f.write(json.dumps([tool, args, dict(os.environ)]) + "\n")
if tool == "colima":
    if args == ["--profile", "default", "status"]:
        action = "status"
        output = "default profile status"
    elif args == ["--profile", "default", "ssh", "--", "sudo", "-n",
                  "fstrim", "-v", "/mnt/lima-colima"]:
        action = "trim"
        output = "/mnt/lima-colima: 20.5 GiB trimmed (fixture range)"
    else:
        sys.exit("UNEXPECTED colima command: " + repr(args))
elif tool == "docker":
    if args == ["--context", "colima", "context", "inspect", "colima",
                "--format", "{{.Endpoints.docker.Host}}"]:
        action = "context"
        output = os.environ.get("TEST_ENDPOINT", "unix://" + str(home / ".colima/default/docker.sock"))
    else:
        assert args[:2] == ["--host", "unix://" + str(home / ".colima/default/docker.sock")], args
        command = args[2:]
        if command == ["info"]:
            action, output = "info", "local daemon"
        elif command == ["image", "prune", "--all", "--force", "--filter", "until=168h"]:
            action, output = "image", "Total reclaimed space: 4.071 GB"
        elif command == ["builder", "prune", "--force", "--filter", "until=168h"]:
            assert os.environ.get("DOCKER_BUILDKIT") == "0", "must bypass Buildx forwarding"
            action, output = "builder", "Total reclaimed space: 1.426 GB"
        else:
            sys.exit("UNEXPECTED docker command: " + repr(args))
else:
    sys.exit("UNEXPECTED tool: " + tool)
if action in os.environ.get("TEST_FAIL", "").split(","):
    print("fixture failure: " + action, file=sys.stderr)
    sys.exit(42)
print(output)
