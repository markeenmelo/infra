def changes($have; $path):
  to_entries[]
  | ($path + [.key]) as $at
  | .value as $new
  | ($have | getpath($at)) as $now
  | if ($new | type) == "object" and ($now | type) == "object" then $new | changes($have; $at)
    elif $now != $new then "\($at | join(".")): \($now | tojson) -> \($new | tojson)"
    else empty
    end;

if (.meta.rc // "ok") != "ok" then error("the controller answered \(.meta | tojson)") else . end
| (.data | map({key, value: .}) | from_entries) as $current
| $want[0]
| to_entries
| map(
    ($current[.key] // {key}) as $have
    | {key, changes: [.value | changes($have; [])], body: ($have * .value)}
    | select(.changes != [])
  )
