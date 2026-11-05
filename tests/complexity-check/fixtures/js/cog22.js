export function risky(a) {
  let n = 0;
  for (const x of a) {
    if (x > 0) {
      if (x > 1) {
        if (x > 2) {
          if (x > 3) {
            n += x;
          }
        }
      }
    }
  }
  for (const y of a) {
    if (y > 10) {
      n += y;
    }
  }
  if (n > 100 && n < 200) {
    n = 0;
  }
  return n > 5 && n < 9 ? n : 0;
}
