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
L = logging.getLogger(__name__)

mem = joblib.Memory("~/.cache")


def dependency(x: str):
  # NOTE: a change in this function will not affect the caching.
  # Also note that external state (randomness) is not accounted for.
  if len(x) < 10: return x
  return f"{x}{random.randint(0, 10)}"


@mem.cache
def memoized(x: str):
  # Changing even a comment makes joblib recompute existing results.
  # It prints a warning in the log.
  L.info("Actual implementation called")
  return x + " additional string " + dependency(x)


if __name__ == "__main__":
  inp = "this is my string new"
  L.info("Calling with string len %s", len(inp))
  random.seed(111)
  print(memoized(inp))
  print(dependency(inp))
  # print(memoized(f"this is my string {random.randint(0, 10_000)}"))

