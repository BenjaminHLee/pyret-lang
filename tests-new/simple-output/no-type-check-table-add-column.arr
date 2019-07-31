### true

# no-type-check-table-add-column.arr
# table-add-column test.

import global as G
import tables as T
import list as L
import js-file("../object-equality-helper") as Eq

my-table = table: a, b
  row: 1, 2
  row: 4, 5
  row: 7, 8
end

new-table = my-table.add-column("c", [L.list: 3, 6, 9])

expected-table = table: a, b, c
  row: 1, 2, 3
  row: 4, 5, 6
  row: 7, 8, 9
end

passes-when-true = Eq._objectDeepEqual(expected-table, new-table)

G.console-log(passes-when-true)