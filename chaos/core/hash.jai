
djb2 :: (s : string) -> u64 {
  hash : u64 = 5381;
  for c : s {
    hash = ((hash << 5) + hash) + c;
  }

  return hash;
}