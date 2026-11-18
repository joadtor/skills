class Order:
    def total(self, items):
        t = 0
        for i in items:
            if i.a:
                for j in i.parts:
                    if j.ok and j.live:
                        if j.big:
                            t += 1
                        elif j.mid:
                            t += 2
                        else:
                            t += 3
        return t
