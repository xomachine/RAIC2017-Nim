from enhanced import Group

type
  GroupCounter* = set[Group]

proc initGroupCounter*(maxGroup: Group): GroupCounter
proc getFreeGroup*(self: var GroupCounter): Group
proc releaseGroup*(self: var GroupCounter, group: Group) {.inline.}

proc initGroupCounter(maxGroup: Group): GroupCounter =
  for i in 1.Group..maxGroup:
    result.incl(i)

proc releaseGroup(self: var GroupCounter, group: Group) =
  self.incl(group)

proc getFreeGroup(self: var GroupCounter): Group =
  for g in self:
    result = g
    break
  self.excl(result)
