#!/usr/bin/env python3
import argparse
import sys
import urllib.request
import urllib.error


def parse_ok_range(s: str):
    """
    Parse "200:499" -> (200, 499)
    """
    parts = s.split(":")
    if len(parts) != 2:
        raise ValueError("ok-range must be like 200:499")
    lo = int(parts[0])
    hi = int(parts[1])
    if lo < 100 or hi < 100 or lo > hi:
        raise ValueError("invalid ok-range bounds")
    return lo, hi


def main() -> int:
    p = argparse.ArgumentParser(description="LiteLLM liveliness probe (exit 0 healthy, 1 unhealthy).")
    p.add_argument("--url", default="http://127.0.0.1:4000/health/liveliness", help="Health URL to probe")
    p.add_argument("--timeout", type=float, default=5.0, help="Timeout seconds")
    p.add_argument("--method", default="GET", choices=["GET", "HEAD"], help="HTTP method")
    p.add_argument("--ok-status", action="append", type=int, default=[], help="Additional HTTP status treated as OK (repeatable)")
    p.add_argument("--ok-range", default=None, help="Inclusive OK range like 200:499 (useful if endpoint returns 401/403)")
    args = p.parse_args()

    ok_statuses = set(args.ok_status)
    # Default OK status
    if not ok_statuses:
        ok_statuses = {200}

    ok_range = None
    if args.ok_range:
        ok_range = parse_ok_range(args.ok_range)

    req = urllib.request.Request(args.url, method=args.method)
    req.add_header("User-Agent", "homelab-healthcheck/1.0")

    try:
        with urllib.request.urlopen(req, timeout=args.timeout) as resp:
            code = resp.getcode()
            if code in ok_statuses:
                return 0
            if ok_range and ok_range[0] <= code <= ok_range[1]:
                return 0
            return 1

    except urllib.error.HTTPError as e:
        # HTTPError is still a response with a status code
        code = getattr(e, "code", None)
        if code is not None:
            if code in ok_statuses:
                return 0
            if ok_range and ok_range[0] <= code <= ok_range[1]:
                return 0
        return 1

    except Exception:
        return 1


if __name__ == "__main__":
    sys.exit(main())
    