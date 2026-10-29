package main

type Order struct{}

func Total(x int) int {
	t := 0
	if x > 1 {
		t++
	}
	if x > 2 {
		t++
	}
	if x > 3 {
		t++
	}
	if x > 4 {
		t++
	}
	if x > 5 {
		t++
	}
	if x > 6 {
		t++
	}
	if x > 7 {
		t++
	}
	if x > 8 {
		t++
	}
	if x > 9 {
		t++
	}
	if x > 10 {
		t++
	}
	return t
}

func (o *Order) Ship(x int) int {
	t := 0
	if x > 1 {
		t++
	}
	if x > 2 {
		t++
	}
	if x > 3 {
		t++
	}
	if x > 4 {
		t++
	}
	if x > 5 {
		t++
	}
	if x > 6 {
		t++
	}
	if x > 7 {
		t++
	}
	if x > 8 {
		t++
	}
	if x > 9 {
		t++
	}
	if x > 10 {
		t++
	}
	return t
}
