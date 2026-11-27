if ($networks.meta.rc // "ok") != "ok" then error("the controller answered \($networks.meta | tojson)") else . end
| if ($rules | type) != "array" then error("the content filter answered \($rules | tojson)") else . end
| ($networks.data | map({key: ._id, value: .name}) | from_entries) as $name
| def shape: {name, enabled, categories: (.categories | sort), safe_search: (.safe_search | sort), networks: (.networks | sort), client_macs, allow_list, block_list, schedule};
  ($rules | map(.networks = (.network_ids | map($name[.] // .)) | shape)) as $have
| ($want[0] | map(shape)) as $want
| [($want - $have)[] | "content filter \(.name): want \(tojson)"]
  + [($have - $want)[] | "content filter \(.name): have \(tojson)"]
