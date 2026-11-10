terraform {
  required_providers {
    unifi = {
      source  = "filipowm/unifi"
      version = "~> 1.1.0"
    }
  }
  backend "local" {}
  encryption {
    key_provider "pbkdf2" "operator" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "operator" {
      keys = key_provider.pbkdf2.operator
    }
    state {
      method   = method.aes_gcm.operator
      enforced = true
    }
    plan {
      method   = method.aes_gcm.operator
      enforced = true
    }
  }
}

variable "state_passphrase" {
  description = "Passphrase the state and plan encryption key is derived from."
  type        = string
  sensitive   = true
}

variable "wlan_passphrases" {
  description = "WPA passphrase of each WLAN, keyed by SSID."
  type        = map(string)
  sensitive   = true
  validation {
    condition     = alltrue([for passphrase in values(var.wlan_passphrases) : length(passphrase) >= 8 && length(passphrase) <= 63])
    error_message = "Every WPA passphrase must be 8 to 63 characters long."
  }
}

variable "fleet_lan" {
  description = "LAN facts per wired fleet host, from fleet.hosts.*.lan; the tofu app sets it."
  type = map(object({
    address    = string
    gateway    = string
    mac        = string
    syslogPort = number
  }))
}

# shortcut: the gateway's certificate is self-signed, verify it once it serves one for the domain
provider "unifi" {
  api_url        = "https://${local.bastion.gateway}"
  allow_insecure = true
}

variable "fleet_domain" {
  description = "The fleet's domain, from fleet.domain; the tofu app sets it."
  type        = string
}

locals {
  domain  = var.fleet_domain
  bastion = var.fleet_lan.bastion
  vlans   = { Homelab = 2, Cameras = 3, IoT = 4, Home = 10, Kids = 20 }
  vlan_of = { for name, id in local.vlans : id => name }
  network = merge({ Default = unifi_network.default.id }, { for name, net in unifi_network.vlan : name => net.id })
  zone    = merge({ for name, zone in data.unifi_firewall_zone.builtin : name => zone.id }, { for name, zone in unifi_firewall_zone.custom : name => zone.id })
  wlans = {
    MN-Home    = { network = "Home", bands = ["2g", "5g", "6g"], legacy = false, multicast = true, isolated = false }
    MN-Kids    = { network = "Kids", bands = ["5g"], legacy = false, multicast = false, isolated = false }
    MN-IoT     = { network = "IoT", bands = ["2g", "5g"], legacy = true, multicast = true, isolated = true }
    MN-Cameras = { network = "Cameras", bands = ["2g"], legacy = true, multicast = false, isolated = true }
  }

  clients = {
    "Bastion"            = { mac = local.bastion.mac, ip = local.bastion.address }
    "Front Yard Camera"  = { mac = "3c:6a:d2:c0:72:7c", ip = "192.168.3.2" }
    "Living Room TV"     = { mac = "38:1b:9e:89:1f:14", ip = "192.168.4.10", cloud = true, shared = true, player = true }
    "Ecovacs"            = { mac = "d4:8a:3b:b4:c5:92", ip = "192.168.4.11", cloud = true }
    "Echo"               = { mac = "44:00:49:aa:fb:74", ip = "192.168.4.12", cloud = true }
    "Bedroom TV"         = { mac = "54:8c:a0:4d:c9:1d", ip = "192.168.4.13", shared = true }
    "Bedroom Fire Stick" = { mac = "c0:8d:51:14:ca:c1", ip = "192.168.4.14", cloud = true, shared = true, player = true }
    "Alen Air Purifier"  = { mac = "fc:3c:d7:dd:cc:8f", ip = "192.168.4.15" }
    "Blink Camera 1"     = { mac = "7c:63:05:c3:62:62", ip = "192.168.4.16", cloud = true }
    "Blink Camera 2"     = { mac = "90:23:5b:fc:40:29", ip = "192.168.4.17", cloud = true }
    "Printer"            = { mac = "e0:bb:9e:39:04:5b", ip = "192.168.4.20", shared = true }
    "ThinkPad"           = { mac = "84:7b:57:95:b1:ae", ip = "192.168.10.2", admin = true }
    "Dock"               = { mac = "8c:ae:4c:af:7c:1e", ip = "192.168.10.3", admin = true }
    "Mac"                = { mac = "6c:7e:67:ca:c1:aa", ip = "192.168.10.4", admin = true }
    "Nara PC"            = { mac = "58:02:05:14:4c:2c", ip = "192.168.10.10" }
    "Nara Phone"         = { mac = "82:87:9d:ce:ba:16", ip = "192.168.10.11" }
    "Marcos Pixel"       = { mac = "e0:1a:df:32:f3:08", ip = "192.168.10.12" }
    "Dino"               = { mac = "c8:58:b3:79:d0:29", ip = "192.168.20.2" }
    "Ian Phone"          = { mac = "36:98:ab:a1:eb:ce", ip = "192.168.20.3" }
    "Ian Tablet"         = { mac = "f4:03:2a:f6:7b:dd", ip = "192.168.20.4" }
    "Nintendo Switch"    = { mac = "70:2c:09:6c:88:d9", ip = "192.168.20.5" }
  }
  role = { for role in ["admin", "cloud", "shared", "player"] : role => sort([for client in local.clients : client.ip if try(client[role], false)]) }

  port_groups = {
    "Camera streams"           = ["554", "2020"]
    "Gateway network services" = ["53", "67", "123", "5353"]
    "DNS"                      = ["53", "853"]
    "Bastion LAN TCP"          = ["80", "443"]
    "Bastion LAN UDP"          = ["443", "41641"]
  }

  policies = merge(
    {
      "Allow Home to Kids"                            = { from = "Home", to = "Kids" }
      "Allow Home to Bastion TCP"                     = { from = "Home", to = "Homelab", to_ips = [local.bastion.address], protocol = "tcp", ports = "Bastion LAN TCP" }
      "Allow Home to Bastion UDP"                     = { from = "Home", to = "Homelab", to_ips = [local.bastion.address], protocol = "udp", ports = "Bastion LAN UDP" }
      "Allow Home ICMP to Bastion"                    = { from = "Home", to = "Homelab", to_ips = [local.bastion.address], protocol = "icmp" }
      "Allow Home to IoT media and printer"           = { from = "Home", to = "IoT", to_ips = local.role.shared }
      "Allow IoT to Bastion HTTPS"                    = { from = "IoT", from_ips = local.role.player, to = "Homelab", to_ips = [local.bastion.address], protocol = "tcp", port = 443 }
      "Allow Kids to Bastion HTTPS"                   = { from = "Kids", to = "Homelab", to_ips = [local.bastion.address], protocol = "tcp", port = 443 }
      "Allow Frigate to Tapo C120"                    = { from = "Homelab", from_ips = [local.bastion.address], to = "Cameras", to_ips = [local.clients["Front Yard Camera"].ip], protocol = "tcp", ports = "Camera streams" }
      "Allow Bastion-routed tailnet clients to IoT"   = { from = "Homelab", from_ips = [local.bastion.address], to = "IoT", to_ips = local.role.shared }
      "Allow Bastion-routed tailnet clients to Kids"  = { from = "Homelab", from_ips = [local.bastion.address], to = "Kids" }
      "Allow Home administrators to gateway HTTPS"    = { from = "Home", from_ips = local.role.admin, to = "Gateway", protocol = "tcp", port = 443 }
      "Allow Homelab administrators to gateway HTTPS" = { from = "Homelab", from_ips = [local.bastion.address], to = "Gateway", protocol = "tcp", port = 443 }
      "Block IoT to external DNS"                     = { from = "IoT", to = "External", protocol = "tcp_udp", ports = "DNS", block = true }
      "Allow IoT cloud devices to internet"           = { from = "IoT", from_ips = local.role.cloud, to = "External" }
      "Block IoT to internet"                         = { from = "IoT", to = "External", block = true }
      "Block Kids internet at bedtime"                = { from = "Kids", to = "External", block = true, schedule = { mode = "EVERY_DAY", time_from = "21:00", time_to = "09:00" } }
      "Block Kids to external DNS"                    = { from = "Kids", to = "External", protocol = "tcp_udp", ports = "DNS", block = true }
    },
    [for vlan in keys(local.vlans) : {
      "Allow ${vlan} to gateway network services" = { from = vlan, to = "Gateway", protocol = "tcp_udp", ports = "Gateway network services" }
      "Allow ${vlan} ICMP to gateway"             = { from = vlan, to = "Gateway", protocol = "icmp" }
      "Block ${vlan} to gateway"                  = { from = vlan, to = "Gateway", block = true }
    }]...
  )

  orders = merge(
    {
      "IoT External" = ["Block IoT to external DNS", "Allow IoT cloud devices to internet", "Block IoT to internet"]
    },
    { for vlan in keys(local.vlans) : "${vlan} Gateway" => [for name in [
      "Allow ${vlan} to gateway network services",
      "Allow ${vlan} ICMP to gateway",
      "Allow ${vlan} administrators to gateway HTTPS",
      "Block ${vlan} to gateway",
    ] : name if contains(keys(local.policies), name)] },
  )
}

# shortcut: DHCP is off, but untagged UDR7 LAN ports land on Default; keep unused ports disabled in the UI (unifi_device would own the whole router); move to Tofu if the provider gains a per-port resource
resource "unifi_network" "default" {
  name                       = "Default"
  purpose                    = "corporate"
  subnet                     = "192.168.1.0/24"
  domain_name                = "localdomain"
  dhcp_enabled               = false
  dhcp_start                 = "192.168.1.6"
  dhcp_stop                  = "192.168.1.254"
  dhcp_lease                 = 86400
  dhcp_v6_lease              = 86400
  dhcp_v6_dns_auto           = true
  dhcp_v6_start              = "::2"
  dhcp_v6_stop               = "::7d1"
  ipv6_interface_type        = "none"
  ipv6_ra_enable             = true
  ipv6_pd_start              = "::2"
  ipv6_pd_stop               = "::7d1"
  ipv6_ra_preferred_lifetime = 14400
  ipv6_ra_priority           = "high"
  ipv6_ra_valid_lifetime     = 0
  internet_access_enabled    = true
  multicast_dns              = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "unifi_network" "vlan" {
  for_each                   = local.vlans
  name                       = each.key
  purpose                    = "corporate"
  vlan_id                    = each.value
  subnet                     = "192.168.${each.value}.0/24"
  dhcp_enabled               = true
  dhcp_start                 = "192.168.${each.value}.100"
  dhcp_stop                  = "192.168.${each.value}.254"
  dhcp_lease                 = 86400
  dhcp_v6_lease              = 0
  dhcp_v6_dns_auto           = false
  ipv6_interface_type        = "none"
  ipv6_ra_preferred_lifetime = 0
  ipv6_ra_valid_lifetime     = 0
  internet_access_enabled    = each.key != "Cameras"
  multicast_dns              = contains(["Home", "IoT"], each.key)
  lifecycle {
    prevent_destroy = true
  }
}

data "unifi_ap_group" "default" {}

data "unifi_user_group" "default" {}

resource "unifi_wlan" "this" {
  for_each                  = local.wlans
  name                      = each.key
  network_id                = local.network[each.value.network]
  security                  = "wpapsk"
  passphrase                = var.wlan_passphrases[each.key]
  wlan_bands                = each.value.bands
  wpa3_support              = !each.value.legacy
  wpa3_transition           = !each.value.legacy
  pmf_mode                  = "optional"
  bss_transition            = !each.value.legacy
  multicast_enhance         = each.value.multicast
  l2_isolation              = each.value.isolated
  minimum_data_rate_2g_kbps = each.value.legacy ? 5500 : 12000
  minimum_data_rate_5g_kbps = 6000
  no2ghz_oui                = !each.value.legacy
  ap_group_ids              = [data.unifi_ap_group.default.id]
  user_group_id             = data.unifi_user_group.default.id
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = contains(nonsensitive(keys(var.wlan_passphrases)), each.key)
      error_message = "wlan_passphrases has no entry for ${each.key}."
    }
  }
}

resource "unifi_user" "fixed" {
  for_each   = local.clients
  name       = each.key
  mac        = each.value.mac
  fixed_ip   = each.value.ip
  network_id = local.network[local.vlan_of[split(".", each.value.ip)[2]]]
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [note]
  }
}

resource "unifi_dns_record" "wildcard" {
  name   = "*.${local.domain}"
  type   = "A"
  record = local.bastion.address
  ttl    = 300
}

resource "unifi_setting_ips" "this" {
  ips_mode                      = "ips"
  advanced_filtering_preference = "manual"
  memory_optimized              = true
  restrict_torrents             = false
  enabled_networks              = [for name in ["Default", "Homelab", "IoT", "Home", "Kids"] : local.network[name]]
  honeypots                     = [for name in ["Homelab", "IoT", "Home", "Kids"] : { ip_address = "192.168.${local.vlans[name]}.99", network_id = local.network[name] }]
  enabled_categories = [
    "botcc", "emerging-dns", "dshield", "emerging-exploit", "emerging-malware", "emerging-mobile", "emerging-p2p",
    "emerging-shellcode", "tor", "emerging-useragent", "emerging-worm", "dark-web-blocker-list", "malicious-hosts",
  ]
}

resource "unifi_setting_rsyslogd" "this" {
  enabled = true
  ip      = local.bastion.address
  port    = local.bastion.syslogPort
  contents = [
    "device", "client", "firewall_default_policy", "triggers", "updates", "admin_activity", "critical",
    "security_detections", "vpn",
  ]
}

resource "unifi_setting_mgmt" "this" {
  ssh_enabled       = false
  auto_upgrade      = true
  auto_upgrade_hour = 4
}

resource "unifi_setting_auto_speedtest" "this" {
  enabled = true
  cron    = "0 3 * * *"
}

resource "unifi_setting_network_optimization" "this" {
  enabled = true
}

resource "unifi_setting_teleport" "this" {
  enabled = false
}

resource "unifi_setting_dpi" "this" {
  enabled                = true
  fingerprinting_enabled = true
}

data "unifi_firewall_zone" "builtin" {
  for_each = toset(["Internal", "Gateway", "External"])
  name     = each.key
}

resource "unifi_firewall_zone" "custom" {
  for_each = local.vlans
  name     = each.key
  networks = [local.network[each.key]]
}

resource "unifi_firewall_group" "ports" {
  for_each = local.port_groups
  name     = each.key
  type     = "port-group"
  members  = each.value
}

resource "unifi_firewall_zone_policy" "this" {
  for_each                  = local.policies
  name                      = each.key
  action                    = try(each.value.block, false) ? "BLOCK" : "ALLOW"
  protocol                  = try(each.value.protocol, "all")
  ip_version                = try(each.value.protocol, "all") == "icmp" ? "IPV4" : null
  auto_allow_return_traffic = !try(each.value.block, false) && !contains(["Gateway", "External"], each.value.to) && try(each.value.protocol, "all") != "icmp" ? true : null
  schedule                  = try(each.value.schedule, null)
  source = {
    zone_id = local.zone[each.value.from]
    ips     = try(each.value.from_ips, null)
  }
  destination = {
    zone_id       = local.zone[each.value.to]
    ips           = try(each.value.to_ips, null)
    port          = try(each.value.port, null)
    port_group_id = can(each.value.ports) ? unifi_firewall_group.ports[each.value.ports].id : null
  }
}

resource "unifi_firewall_zone_policy_order" "this" {
  for_each              = local.orders
  source_zone_id        = local.zone[local.policies[each.value[0]].from]
  destination_zone_id   = local.zone[local.policies[each.value[0]].to]
  before_predefined_ids = [for name in each.value : unifi_firewall_zone_policy.this[name].id]
}
