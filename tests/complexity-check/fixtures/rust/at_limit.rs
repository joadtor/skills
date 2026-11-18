pub fn at_limit(a: i32, b: i32, c: i32) -> i32 {
    let mut n = 0;
    if a > 0 {
        n += 1;
        if b > 0 {
            n += 2;
            if c > 0 {
                n += 3;
            }
        }
    }
    for i in 0..a {
        if i > b {
            n += i;
        }
        if i > c {
            n -= i;
        }
    }
    while n > 100 {
        n -= 1;
    }
    if a == 0 {
        n += 0;
    }
    if a == 1 {
        n += 1;
    }
    if a == 2 {
        n += 2;
    }
    if a == 3 {
        n += 3;
    }
    if a == 4 {
        n += 4;
    }
    if a == 5 {
        n += 5;
    }
    if a == 6 {
        n += 6;
    }
    n
}
