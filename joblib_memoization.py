"""Some code to showcase joblib as a memoization technique.

If you run this multiple times, it should automatically infer when identical
input gets passed in (not sure if the cache ever gets evicted?).

NOTE:
    if you change the function in any way (e.g. adding a comment)
    joblib will warn you and evict the existing cache.
"""
import random
import logging
import joblib

logging.basicConfig(level=logging.DEBUG)

mem = joblib.Memory("~/.cache")


@mem.cache
def memoized(x: str):
  # Changing even a comment makes joblib recompute existing results.
  # It prints a warning in the log.
  return x + " additional string"


if __name__ == "__main__":
  print(memoized("this is my string new"))
  print(memoized(f"this is my string {random.randint(0, 10_000)}"))

