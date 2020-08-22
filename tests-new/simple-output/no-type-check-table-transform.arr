### true

# no-type-check-table-transform.arr
# `transform` syntax.

import global as G
import equality as E
import tables as T

my-table = table: name, age, favNum
  row: "Bob", 12, 1
  row: "Alice", 17, 2
  row: "Eve", 13, 3
end

my-transform-table = transform my-table using age, favNum:
  favNum: favNum + 5,
  age: age + 1
end

my-correct-transform-table = table: name, age, favNum
  row: "Bob", 13, 6
  row: "Alice", 18, 7
  row: "Eve", 14, 8
end

are-equal = E.equal-always(my-correct-transform-table, my-transform-table)

are-not-equal = E.equal-always(my-correct-transform-table, my-table)

passes-when-true = are-equal and G.not(are-not-equal)

G.console-log(passes-when-true)
