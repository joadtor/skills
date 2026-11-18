pub fn score_22(a: i32, b: i32, c: i32) -> i32 {
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
    if a == 7 {
        n += 7;
    }
    if a == 8 {
        n += 8;
    }
    if a == 9 {
        n += 9;
    }
    if a == 10 {
        n += 10;
    }
    if a == 11 {
        n += 11;
    }
    if a == 12 {
        n += 12;
    }
    if a == 13 {
        n += 13;
    }
    n
}

pub fn score_18(a: i32, b: i32, c: i32) -> i32 {
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
    if a == 7 {
        n += 7;
    }
    if a == 8 {
        n += 8;
    }
    if a == 9 {
        n += 9;
    }
    n
}
