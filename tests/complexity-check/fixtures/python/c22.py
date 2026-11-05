def risky(items):
    t = 0
    for i in items:
        if i.a:
            for j in i.parts:
                if j.ok and j.live:
                    if j.big or j.heavy:
                        t += 1
                    elif j.mid:
                        t += 2
                    else:
                        t += 3
                elif j.x and j.y or j.z:
                    t += 4
    return t
