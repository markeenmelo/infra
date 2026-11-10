moved {
  from = unifi_firewall_zone_policy.home["Kids"]
  to   = unifi_firewall_zone_policy.this["Allow Home to Kids"]
}

moved {
  from = unifi_firewall_zone_policy.home_bastion["Allow Home to Bastion TCP"]
  to   = unifi_firewall_zone_policy.this["Allow Home to Bastion TCP"]
}

moved {
  from = unifi_firewall_zone_policy.home_bastion["Allow Home to Bastion UDP"]
  to   = unifi_firewall_zone_policy.this["Allow Home to Bastion UDP"]
}

moved {
  from = unifi_firewall_zone_policy.home_bastion_icmp
  to   = unifi_firewall_zone_policy.this["Allow Home ICMP to Bastion"]
}

moved {
  from = unifi_firewall_zone_policy.home_iot_local
  to   = unifi_firewall_zone_policy.this["Allow Home to IoT media and printer"]
}

moved {
  from = unifi_firewall_zone_policy.bastion_https["IoT"]
  to   = unifi_firewall_zone_policy.this["Allow IoT to Bastion HTTPS"]
}

moved {
  from = unifi_firewall_zone_policy.bastion_https["Kids"]
  to   = unifi_firewall_zone_policy.this["Allow Kids to Bastion HTTPS"]
}

moved {
  from = unifi_firewall_zone_policy.bastion_to["Allow Frigate to Tapo C120"]
  to   = unifi_firewall_zone_policy.this["Allow Frigate to Tapo C120"]
}

moved {
  from = unifi_firewall_zone_policy.bastion_routed["IoT"]
  to   = unifi_firewall_zone_policy.this["Allow Bastion-routed tailnet clients to IoT"]
}

moved {
  from = unifi_firewall_zone_policy.bastion_routed["Kids"]
  to   = unifi_firewall_zone_policy.this["Allow Bastion-routed tailnet clients to Kids"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_admin["Home"]
  to   = unifi_firewall_zone_policy.this["Allow Home administrators to gateway HTTPS"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_admin["Homelab"]
  to   = unifi_firewall_zone_policy.this["Allow Homelab administrators to gateway HTTPS"]
}

moved {
  from = unifi_firewall_zone_policy.external_dns["IoT"]
  to   = unifi_firewall_zone_policy.this["Block IoT to external DNS"]
}

moved {
  from = unifi_firewall_zone_policy.external_dns["Kids"]
  to   = unifi_firewall_zone_policy.this["Block Kids to external DNS"]
}

moved {
  from = unifi_firewall_zone_policy.kids_family_dns
  to   = unifi_firewall_zone_policy.this["Allow Kids to AdGuard family DNS"]
}

moved {
  from = unifi_firewall_zone_policy.kids_bedtime
  to   = unifi_firewall_zone_policy.this["Block Kids internet at bedtime"]
}

moved {
  from = unifi_firewall_zone_policy.iot_cloud
  to   = unifi_firewall_zone_policy.this["Allow IoT cloud devices to internet"]
}

moved {
  from = unifi_firewall_zone_policy.iot_internet_block
  to   = unifi_firewall_zone_policy.this["Block IoT to internet"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_services["Homelab"]
  to   = unifi_firewall_zone_policy.this["Allow Homelab to gateway network services"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_icmp["Homelab"]
  to   = unifi_firewall_zone_policy.this["Allow Homelab ICMP to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_block["Homelab"]
  to   = unifi_firewall_zone_policy.this["Block Homelab to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_services["Cameras"]
  to   = unifi_firewall_zone_policy.this["Allow Cameras to gateway network services"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_icmp["Cameras"]
  to   = unifi_firewall_zone_policy.this["Allow Cameras ICMP to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_block["Cameras"]
  to   = unifi_firewall_zone_policy.this["Block Cameras to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_services["IoT"]
  to   = unifi_firewall_zone_policy.this["Allow IoT to gateway network services"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_icmp["IoT"]
  to   = unifi_firewall_zone_policy.this["Allow IoT ICMP to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_block["IoT"]
  to   = unifi_firewall_zone_policy.this["Block IoT to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_services["Home"]
  to   = unifi_firewall_zone_policy.this["Allow Home to gateway network services"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_icmp["Home"]
  to   = unifi_firewall_zone_policy.this["Allow Home ICMP to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_block["Home"]
  to   = unifi_firewall_zone_policy.this["Block Home to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_services["Kids"]
  to   = unifi_firewall_zone_policy.this["Allow Kids to gateway network services"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_icmp["Kids"]
  to   = unifi_firewall_zone_policy.this["Allow Kids ICMP to gateway"]
}

moved {
  from = unifi_firewall_zone_policy.gateway_block["Kids"]
  to   = unifi_firewall_zone_policy.this["Block Kids to gateway"]
}

moved {
  from = unifi_firewall_zone_policy_order.gateway["Homelab"]
  to   = unifi_firewall_zone_policy_order.this["Homelab Gateway"]
}

moved {
  from = unifi_firewall_zone_policy_order.gateway["Cameras"]
  to   = unifi_firewall_zone_policy_order.this["Cameras Gateway"]
}

moved {
  from = unifi_firewall_zone_policy_order.gateway["IoT"]
  to   = unifi_firewall_zone_policy_order.this["IoT Gateway"]
}

moved {
  from = unifi_firewall_zone_policy_order.gateway["Home"]
  to   = unifi_firewall_zone_policy_order.this["Home Gateway"]
}

moved {
  from = unifi_firewall_zone_policy_order.gateway["Kids"]
  to   = unifi_firewall_zone_policy_order.this["Kids Gateway"]
}

moved {
  from = unifi_firewall_zone_policy_order.kids_external
  to   = unifi_firewall_zone_policy_order.this["Kids External"]
}

moved {
  from = unifi_firewall_zone_policy_order.iot_external
  to   = unifi_firewall_zone_policy_order.this["IoT External"]
}
