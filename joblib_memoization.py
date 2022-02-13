"""Some code to showcase joblib as a memoization technique.

If you run this multiple times, it should automatically infer when identical
input gets passed in (not sure if the cache ever gets evicted?).

NOTE:
    if you change the function in any way (e.g. adding a comment)
    joblib will warn you and evict the existing cache.
"""
import torch
import random
import logging
import joblib
import dataclasses as dcls

logging.basicConfig(
  format="\n>>> [%(filename)s:%(lineno)s|%(funcName)5s]\n%(message)s\n",
  level=logging.DEBUG)
L = logging.getLogger(__name__)

mem = joblib.Memory("~/.cache")


@dcls.dataclass
class NormalDataclass:
  value: int


@dcls.dataclass(repr=False, eq=False)
class NoRepr:
  value: int


@dcls.dataclass
class NormalDataclassWithMethods:
  value: int
  another_value: str = "default"

  def method1(self):
    return self.value + 10

  def __call__(self):
    return f"{self.another_value} as string"


class JustClass:
  def __init__(self, value):
    self.value = value


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


@mem.cache
def memoized_data(data: object):
  L.info("Actual implementation called")
  return f"{repr(data)} | {data.value if hasattr(data, 'value') else []}"


@mem.cache
def memoized_data_ret(data: object):
  L.info("Actual implementation called")
  return [data, NormalDataclass(1), NormalDataclassWithMethods(3)]


if __name__ == "__main__":
  import argparse
  parser = argparse.ArgumentParser()
  parser.add_argument('--clear', action='store_true')
  if parser.parse_args().clear:
    mem.clear()
  inp = "this is my string new"
  L.info("Calling with string len %s", len(inp))
  random.seed(111)
  print(memoized(inp))
  print(dependency(inp))

  print(memoized_data(NormalDataclass(1)))
  print(memoized_data(NormalDataclass(2)))
  print(memoized_data(NormalDataclassWithMethods(1)))
  print(memoized_data(NoRepr(1)))
  print(memoized_data(JustClass(1)))
  print(memoized_data([1,2,3]))
  print(memoized_data([JustClass(1), JustClass(2)]))

  result = memoized_data_ret(JustClass(5))
  print(memoized(str(result)))
  print(memoized_data(result))
  print(memoized_data_ret(result))

  # Tensors are not memoized. Joblib uses some numpy-specific hashing to memoize np as inputs.
  print(memoized_data(torch.tensor([1,2])))
  print(memoized_data(torch.tensor([1,2]).numpy()))

