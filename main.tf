# Configure the VMware NSX-T Provider
provider "nsxt" {
    host = "${var.nsx["ip"]}"
    username = "${var.nsx["user"]}"
    password = "${var.nsx["password"]}"
    allow_unverified_ssl = true
}

# Create the data sources we will need to refer to later
data "nsxt_transport_zone" "overlay_tz" {
    display_name = "${var.nsx_data_vars["transport_zone"]}"
}
data "nsxt_logical_tier0_router" "tier0_router" {
  display_name = "${var.nsx_data_vars["t0_router_name"]}"
}
data "nsxt_edge_cluster" "edge_cluster1" {
    display_name = "${var.nsx_data_vars["edge_cluster"]}"
}

# Create Web Tier NSX-T Logical Switch
resource "nsxt_logical_switch" "web" {
    admin_state = "UP"
    description = "LS created by Terraform"
    display_name = "web-tier"
    transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
    replication_mode = "MTEP"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
    tag {
	scope = "tier"
	tag = "web"
    }
}

# Create App Tier NSX-T Logical Switch
resource "nsxt_logical_switch" "app" {
    admin_state = "UP"
    description = "LS created by Terraform"
    display_name = "app-tier"
    transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
    replication_mode = "MTEP"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
    tag {
	scope = "tier"
	tag = "app"
    }
}


# Create DB Tier NSX-T Logical Switch
resource "nsxt_logical_switch" "db" {
    admin_state = "UP"
    description = "LS created by Terraform"
    display_name = "db-tier"
    transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
    replication_mode = "MTEP"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
    tag {
	scope = "tier"
	tag = "db"
    }
}


# Create T1 router
resource "nsxt_logical_tier1_router" "tier1_router" {
  description                 = "Tier1 router provisioned by Terraform"
  display_name                = "${var.nsx_rs_vars["t1_router_name"]}"
  failover_mode               = "PREEMPTIVE"
  edge_cluster_id             = "${data.nsxt_edge_cluster.edge_cluster1.id}"
  enable_router_advertisement = true
  advertise_connected_routes  = true
  advertise_static_routes     = true
  advertise_nat_routes        = true
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create a port on the T0 router. We will connect the T1 router to this port
resource "nsxt_logical_router_link_port_on_tier0" "link_port_tier0" {
  description       = "TIER0_PORT1 provisioned by Terraform"
  display_name      = "TIER0_PORT1"
  logical_router_id = "${data.nsxt_logical_tier0_router.tier0_router.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create a T1 uplink port and connect it to T0 router
resource "nsxt_logical_router_link_port_on_tier1" "link_port_tier1" {
  description                   = "TIER1_PORT1 provisioned by Terraform"
  display_name                  = "TIER1_PORT1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_router_port_id = "${nsxt_logical_router_link_port_on_tier0.link_port_tier0.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create a switchport on App logical switch
resource "nsxt_logical_port" "logical_port1" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "AppToT1"
  logical_switch_id = "${nsxt_logical_switch.app.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create downlink port on the T1 router and connect it to the switchport we created earlier for App Tier
resource "nsxt_logical_router_downlink_port" "downlink_port" {
  description                   = "DP1 provisioned by Terraform"
  display_name                  = "DP1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_switch_port_id = "${nsxt_logical_port.logical_port1.id}"
  ip_address                    = "${var.app["gw"]}/${var.app["mask"]}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create a switchport on Web logical switch
resource "nsxt_logical_port" "logical_port2" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "WebToT1"
  logical_switch_id = "${nsxt_logical_switch.web.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create downlink port on the T1 router and connect it to the switchport we created earlier
resource "nsxt_logical_router_downlink_port" "downlink_port2" {
  description                   = "DP2 provisioned by Terraform"
  display_name                  = "DP2"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_switch_port_id = "${nsxt_logical_port.logical_port2.id}"
  ip_address                    = "${var.web["gw"]}/${var.web["mask"]}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create a switchport on DB logical switch
resource "nsxt_logical_port" "logical_port3" {
  admin_state       = "UP"
  description       = "LP3 provisioned by Terraform"
  display_name      = "DBToT1"
  logical_switch_id = "${nsxt_logical_switch.db.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create downlink port on the T1 router and connect it to the switchport we created earlier
resource "nsxt_logical_router_downlink_port" "downlink_port3" {
  description                   = "DP3 provisioned by Terraform"
  display_name                  = "DP3"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_switch_port_id = "${nsxt_logical_port.logical_port3.id}"
  ip_address                    = "${var.db["gw"]}/${var.db["mask"]}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}


# Create NSGROUP with dynamic membership criteria
# all Virtual Machines with the specific tag and scope
resource "nsxt_ns_group" "nsgroup" {
  description  = "NSGroup provisioned by Terraform"
  display_name = "terraform-demo-sg"
  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "${var.nsx_tag_scope}"
    tag         = "${var.nsx_tag}"
  }
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create Web NSGROUP
resource "nsxt_ns_group" "webnsgroup" {
  description  = "NSGroup provisioned by Terraform"
  display_name = "web-terraform-demo-sg"
  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "tier"
    tag         = "web"
  }
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}
# Create App NSGROUP
resource "nsxt_ns_group" "appnsgroup" {
  description  = "NSGroup provisioned by Terraform"
  display_name = "app-terraform-demo-sg"
  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "tier"
    tag         = "app"
  }
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}
# Create DB NSGROUP
resource "nsxt_ns_group" "dbnsgroup" {
  description  = "NSGroup provisioned by Terraform"
  display_name = "db-terraform-demo-sg"
  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "tier"
    tag         = "db"
  }
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create custom NSService for App service that listens on port 8443
resource "nsxt_l4_port_set_ns_service" "app" {
  description       = "L4 Port range provisioned by Terraform"
  display_name      = "App Service"
  protocol          = "TCP"
  destination_ports = ["${var.app_listen_port}"]
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create data sourcees for some NSServices that we need to create FW rules
data "nsxt_ns_service" "https" {
  display_name = "HTTPS"
}

data "nsxt_ns_service" "mysql" {
  display_name = "MySQL"
}

data "nsxt_ns_service" "ssh" {
  display_name = "SSH"
}

# Create IP-SET with some ip addresses
# we will use in for fw rules allowing communication to this external IPs
resource "nsxt_ip_set" "ip_set" {
  description  = "Infrastructure IPSET provisioned by Terraform"
  display_name = "Infra"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
  ip_addresses = "${var.ipset}"
}

# Create a Firewall Section
# All rules of this section will be applied to the VMs that are members of the NSGroup we created earlier
resource "nsxt_firewall_section" "firewall_section" {
  description  = "FS provisioned by Terraform"
  display_name = "Terraform Demo FW Section"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
  applied_to {
    target_type = "NSGroup"
    target_id   = "${nsxt_ns_group.nsgroup.id}"
  }

  section_type = "LAYER3"
  stateful     = true


# Allow communication to my VMs only on the ports we defined earlier as NSService
  rule {
    display_name = "Allow HTTPs"
    description  = "In going rule"
    action       = "ALLOW"
    logged       = false
    ip_protocol  = "IPV4"
    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.webnsgroup.id}"
    }
    service {
      target_type = "NSService"
      target_id   = "${data.nsxt_ns_service.https.id}"
    }
  }
  rule {
    display_name = "Allow SSH"
    description  = "In going rule"
    action       = "ALLOW"
    logged       = false
    ip_protocol  = "IPV4"
    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.nsgroup.id}"
#      target_id   = "${nsxt_ns_group.webnsgroup.id}"
    }
    service {
      target_type = "NSService"
      target_id   = "${data.nsxt_ns_service.ssh.id}"
    }
  }
  rule {
    display_name = "Allow Web to App"
    description  = "In going rule"
    action       = "ALLOW"
    logged       = false
    ip_protocol  = "IPV4"
    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.webnsgroup.id}"
    }
    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.appnsgroup.id}"
    }
    service {
      target_type = "NSService"
      target_id   = "${nsxt_l4_port_set_ns_service.app.id}"
    }
  }
  rule {
    display_name = "Allow App to DB"
    description  = "In going rule"
    action       = "ALLOW"
    logged       = false
    ip_protocol  = "IPV4"
    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.appnsgroup.id}"
    }
    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.dbnsgroup.id}"
    }
    service {
      target_type = "NSService"
      target_id   = "${data.nsxt_ns_service.mysql.id}"
    }
  }

# Allow the ip addresses defined in the IP-SET to communicate to my VMs on all ports
  rule {
    display_name = "Allow Infrastructure"
    description  = "Allow DNS and Management Servers"
    action       = "ALLOW"
    logged       = false
    ip_protocol  = "IPV4"
    source {
      target_type = "IPSet"
      target_id   = "${nsxt_ip_set.ip_set.id}"
    }
    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.nsgroup.id}"
    }
  }
  
# Allow all communication from my VMs to everywhere
  rule {
    display_name = "Allow out"
    description  = "Out going rule"
    action       = "ALLOW"
    logged       = false
    ip_protocol  = "IPV4"

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.nsgroup.id}"
    }
  }

# REJECT everything that is not explicitelly allowed above and log a message
  rule {
    display_name = "Deny ANY"
    description  = "Default Deny the traffic"
    action       = "REJECT"
    logged       = true
    ip_protocol  = "IPV4"
  }
}

# Create 1 to 1 NAT for Web VM
resource "nsxt_nat_rule" "rule1" {
  count = "${var.web["nat_ip"] != "" ? 1 : 0}"
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "Web 1to1-in"
  action                    = "SNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        =  "${var.web["nat_ip"]}"
  match_source_network = "${var.web["ip"]}/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

resource "nsxt_nat_rule" "rule2" {
  count = "${var.web["nat_ip"] != "" ? 1 : 0}"
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "Web 1to1-out"
  action                    = "DNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "${var.web["ip"]}"
  match_destination_network = "${var.web["nat_ip"]}/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}


# Create 1 to 1 NAT for App VM
resource "nsxt_nat_rule" "rule3" {
  count = "${var.app["nat_ip"] != "" ? 1 : 0}"
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "App 1to1-in"
  action                    = "SNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        =  "${var.app["nat_ip"]}"
  match_source_network = "${var.app["ip"]}/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

resource "nsxt_nat_rule" "rule4" {
  count = "${var.app["nat_ip"] != "" ? 1 : 0}"
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "App 1to1-out"
  action                    = "DNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "${var.app["ip"]}"
  match_destination_network = "${var.app["nat_ip"]}/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create 1 to 1 NAT for DB VM
resource "nsxt_nat_rule" "rule5" {
  count = "${var.db["nat_ip"] != "" ? 1 : 0}"
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "DB 1to1-in"
  action                    = "SNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        =  "${var.db["nat_ip"]}"
  match_source_network      = "${var.db["ip"]}/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

resource "nsxt_nat_rule" "rule6" {
  count = "${var.db["nat_ip"] != "" ? 1 : 0}"
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "DB 1to1-out"
  action                    = "DNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "${var.db["ip"]}"
  match_destination_network = "${var.db["nat_ip"]}/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}



# Configure the VMware vSphere Provider
provider "vsphere" {
    user           = "${var.vsphere["vsphere_user"]}"
    password       = "${var.vsphere["vsphere_password"]}"
    vsphere_server = "${var.vsphere["vsphere_ip"]}"
    allow_unverified_ssl = true
}

# data source for my vSphere Data Center
data "vsphere_datacenter" "dc" {
  name = "${var.vsphere["dc"]}"
}

# Data source for the logical switch we created earlier
# we need that as we cannot refer directly to the logical switch from the vm resource below
data "vsphere_network" "terraform_web" {
    name = "${nsxt_logical_switch.web.display_name}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
    depends_on = ["nsxt_logical_switch.web"]
}
data "vsphere_network" "terraform_app" {
    name = "${nsxt_logical_switch.app.display_name}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
    depends_on = ["nsxt_logical_switch.app"]
}
data "vsphere_network" "terraform_db" {
    name = "${nsxt_logical_switch.db.display_name}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
    depends_on = ["nsxt_logical_switch.db"]
}



# Datastore data source
data "vsphere_datastore" "datastore" {
  name          = "${var.vsphere["datastore"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# data source for my cluster's default resource pool
data "vsphere_resource_pool" "pool" {
  name          = "${var.vsphere["resource_pool"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Data source for the template I am going to use to clone my VM from
data "vsphere_virtual_machine" "template" {
    name = "${var.vsphere["vm_template"]}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Clone a VM from the template above and attach it to the newly created logical switch
resource "vsphere_virtual_machine" "appvm" {
    name             = "${var.app["vm_name"]}"
    depends_on = ["nsxt_logical_switch.app"]
    resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
    datastore_id     = "${data.vsphere_datastore.datastore.id}"
    num_cpus = 1
    memory   = 1024
    guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
    scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"
    # Attach the VM to the network data source that refers to the newly created logical switch
    network_interface {
      network_id = "${data.vsphere_network.terraform_app.id}"
    }
    disk {
	label = "${var.app["vm_name"]}.vmdk"
        size = 16
        thin_provisioned = true
    }
    clone {
	template_uuid = "${data.vsphere_virtual_machine.template.id}"

	# Guest customization to supply hostname and ip addresses to the guest
	customize {
	    linux_options {
		host_name = "${var.app["vm_name"]}"
		domain = "${var.app["domain"]}"
	    }
	    network_interface {
		ipv4_address = "${var.app["ip"]}"
		ipv4_netmask = "${var.app["mask"]}"
		dns_server_list = "${var.dns_server_list}"
		dns_domain = "${var.app["domain"]}"
	    }
	    ipv4_gateway = "${var.app["gw"]}"
	}
    }
    connection {
	type = "ssh",
	agent = "false"
	host = "${var.app["nat_ip"] != "" ? var.app["nat_ip"] : var.app["ip"]}"
	user = "${var.app["user"]}"
	password = "${var.app["pass"]}"
	script_path = "/root/tf.sh"
    }
    provisioner "remote-exec" {
	inline = [
	    "echo 'nameserver ${var.dns_server_list[0]}' >> /etc/resolv.conf", # By some reason guest customization didnt configure DNS, so this is a workaround
	    "rm -f /etc/yum.repos.d/vmware-tools.repo",
	    "/usr/bin/systemctl stop firewalld",
	    "/usr/bin/systemctl disable firewalld",
	    "/usr/bin/yum makecache",
	    "git clone https://github.com/yasensim/demo-three-tier-app.git",
	    "cp demo-three-tier-app/nsxapp.tar.gz /opt/",
	    "tar -xvzf /opt/nsxapp.tar.gz -C /opt/",
	    "/usr/bin/yum install httpd -y",
	    "if [ -r /etc/httpd/conf.d/ssl.conf ]; then mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.disabled ; fi",
	    "/usr/bin/systemctl enable httpd.service",
	    "/usr/bin/systemctl start httpd.service",
	    "/usr/bin/yum install php php-mysql mariadb -y",
	    "/usr/sbin/setsebool -P httpd_can_network_connect=1",
	    "/usr/bin/systemctl restart httpd.service",
	    "/usr/bin/yum install mod_ssl -y",
	    "/usr/bin/mkdir -p /var/www/html2",
	    "/usr/bin/cp -a /opt/nsx/medicalapp/* /var/www/html2",
	    
	    # ssl certs
	    "/usr/bin/cp -a /opt/nsx/cert.pem /etc/ssl/cert.pem",
	    "/usr/bin/cp -a /opt/nsx/cert.key /etc/ssl/cert.key",
	    
	    # app configuration
	    "/bin/sed -i 's/MEDAPP_DB_USER/${var.db_user}/g' /var/www/html2/index.php",
	    "/bin/sed -i 's/MEDAPP_DB_PASS/${var.db_pass}/g' /var/www/html2/index.php",
	    "/bin/sed -i 's/MEDAPP_DB_HOST/${var.db["ip"]}/g' /var/www/html2/index.php",
	    "/bin/sed -i 's/MEDAPP_DB_NAME/${var.db_name}/g' /var/www/html2/index.php",
	    
	    # httpd configuration
	    "/usr/bin/echo 'ServerName appserver.yasen.local' > /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo 'Listen 8443' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo 'SSLCertificateFile /etc/ssl/cert.pem' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo 'SSLCertificateKeyFile /etc/ssl/cert.key' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '<VirtualHost _default_:${var.app_listen_port}>' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '  SSLEngine on' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '  DocumentRoot \"/var/www/html2\"' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '  <Directory \"/var/www/html\">' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '    Options Indexes FollowSymLinks' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '    AllowOverride None' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '    Require all granted' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '  </Directory>' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '</VirtualHost>' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/systemctl stop httpd",
	    "/usr/bin/systemctl start httpd" 
	]
    }

}

# Tag the newly created VM, so it will becaome a member of my NSGroup
# that way all fw rules we have defined earlier will be applied to it
resource "nsxt_vm_tags" "vm1_tags" {
    instance_id = "${vsphere_virtual_machine.appvm.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
    tag {
	scope = "tier"
	tag = "app"
    }
}
# Clone a VM from the template above and attach it to the newly created logical switch
resource "vsphere_virtual_machine" "webvm" {
    name             = "${var.web["vm_name"]}"
    depends_on = ["nsxt_logical_switch.web"]
    resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
    datastore_id     = "${data.vsphere_datastore.datastore.id}"
    num_cpus = 1
    memory   = 1024
    guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
    scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"
    # Attach the VM to the network data source that refers to the newly created logical switch
    network_interface {
      network_id = "${data.vsphere_network.terraform_web.id}"
    }
    disk {
	label = "${var.web["vm_name"]}.vmdk"
        size = 16
        thin_provisioned = true
    }
    clone {
	template_uuid = "${data.vsphere_virtual_machine.template.id}"

	# Guest customization to supply hostname and ip addresses to the guest
	customize {
	    linux_options {
		host_name = "${var.web["vm_name"]}"
		domain = "${var.web["domain"]}"
	    }
	    network_interface {
		ipv4_address = "${var.web["ip"]}"
		ipv4_netmask = "${var.web["mask"]}"
		dns_server_list = "${var.dns_server_list}"
		dns_domain = "${var.web["domain"]}"
	    }
	    ipv4_gateway = "${var.web["gw"]}"
	}
    }
    connection {
	type = "ssh",
	agent = "false"
	host = "${var.web["nat_ip"] != "" ? var.web["nat_ip"] : var.web["ip"]}"
	user = "${var.web["user"]}"
	password = "${var.web["pass"]}"
	script_path = "/root/tf.sh"
    }
    provisioner "remote-exec" {
	inline = [ 
	    "echo 'nameserver ${var.dns_server_list[0]}' >> /etc/resolv.conf",
	    "rm -f /etc/yum.repos.d/vmware-tools.repo",
	    "/usr/bin/systemctl stop firewalld",
	    "/usr/bin/systemctl disable firewalld",
	    "/usr/bin/yum makecache",
	    "/usr/bin/yum install epel-release -y",
	    "/usr/bin/yum install nginx -y",
	    "git clone https://github.com/yasensim/demo-three-tier-app.git",
	    "cp demo-three-tier-app/nsxapp.tar.gz /opt/",
	    "tar -xvzf /opt/nsxapp.tar.gz -C /opt/",
	    "/bin/sed -i \"s/80 default_server/443 default_server/g\" /etc/nginx/nginx.conf",
	    "/bin/sed -i 's/location \\//location \\/unuseful_location/g' /etc/nginx/nginx.conf",
	    "/usr/bin/cp -a /opt/nsx/cert.pem /etc/ssl/cert.pem",
	    "/usr/bin/cp -a /opt/nsx/cert.key /etc/ssl/cert.key",
	    "/bin/sed -i 's/.*\\[::\\]/#&/g' /etc/nginx/nginx.conf",
	    "/usr/bin/echo \"ssl on;\" > /etc/nginx/default.d/ssl.conf",
	    "/usr/bin/echo \"ssl_certificate /etc/ssl/cert.pem;\" >> /etc/nginx/default.d/ssl.conf",
	    "/usr/bin/echo \"ssl_certificate_key /etc/ssl/cert.key;\" >> /etc/nginx/default.d/ssl.conf",
	    "/usr/bin/echo \"location / {\" >> /etc/nginx/default.d/ssl.conf",
	    "/usr/bin/echo \"    proxy_pass https://${var.app["ip"]}:${var.app_listen_port};\" >> /etc/nginx/default.d/ssl.conf",
	    "/usr/bin/echo \"}\" >> /etc/nginx/default.d/ssl.conf",
	    "/usr/bin/systemctl enable nginx.service",
	    "/usr/bin/systemctl start nginx"
	]
    }
}

# Tag the newly created VM, so it will becaome a member of my NSGroup
# that way all fw rules we have defined earlier will be applied to it
resource "nsxt_vm_tags" "vm2_tags" {
    instance_id = "${vsphere_virtual_machine.webvm.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
    tag {
	scope = "tier"
	tag = "web"
    }
}




# Clone a VM from the template above and attach it to the newly created logical switch
resource "vsphere_virtual_machine" "dbvm" {
    name             = "${var.db["vm_name"]}"
    depends_on = ["nsxt_logical_switch.db"]
    resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
    datastore_id     = "${data.vsphere_datastore.datastore.id}"
    num_cpus = 1
    memory   = 1024
    guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
    scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"
    # Attach the VM to the network data source that refers to the newly created logical switch
    network_interface {
      network_id = "${data.vsphere_network.terraform_db.id}"
    }
    disk {
	label = "${var.db["vm_name"]}.vmdk"
        size = 16
        thin_provisioned = true
    }
    clone {
	template_uuid = "${data.vsphere_virtual_machine.template.id}"

	# Guest customization to supply hostname and ip addresses to the guest
	customize {
	    linux_options {
		host_name = "${var.db["vm_name"]}"
		domain = "${var.db["domain"]}"
	    }
	    network_interface {
		ipv4_address = "${var.db["ip"]}"
		ipv4_netmask = "${var.db["mask"]}"
		dns_server_list = "${var.dns_server_list}"
		dns_domain = "${var.db["domain"]}"
	    }
	    ipv4_gateway = "${var.db["gw"]}"
	}
    }
    connection {
	type = "ssh",
	agent = "false"
	host = "${var.db["nat_ip"] != "" ? var.db["nat_ip"] : var.db["ip"]}"
	user = "${var.app["user"]}"
	password = "${var.app["pass"]}"
	script_path = "/root/tf.sh"
    }
    provisioner "remote-exec" {
	inline = [ 
	    "echo 'nameserver ${var.dns_server_list[0]}' >> /etc/resolv.conf",
	    "rm -f /etc/yum.repos.d/vmware-tools.repo",
	    "/usr/bin/systemctl stop firewalld",
	    "/usr/bin/systemctl disable firewalld",
	    "/usr/bin/yum makecache",
	    "git clone https://github.com/yasensim/demo-three-tier-app.git",
	    "cp demo-three-tier-app/nsxapp.tar.gz /opt/",
	    "tar -xvzf /opt/nsxapp.tar.gz -C /opt/",
	    "/usr/bin/yum install mariadb-server -y",
	    "/sbin/chkconfig mariadb on",
	    "/sbin/service mariadb start",
	    "/bin/echo '[mysqld]' > /etc/my.cnf.d/skipdns.cnf",
	    "/bin/echo 'skip-name-resolve' >> /etc/my.cnf.d/skipdns.cnf",
	    "/usr/bin/mysql -e \"UPDATE mysql.user SET Password=PASSWORD('${var.db_pass}') WHERE User='root';\"",
	    "/usr/bin/mysql -e \"DELETE FROM mysql.user WHERE User='';\"",
	    "/usr/bin/mysql -e \"DROP DATABASE test;\"",
	    "/usr/bin/mysql -e \"FLUSH PRIVILEGES;\"",
	    "/bin/systemctl restart mariadb.service",
	    "/usr/bin/mysql -e 'CREATE DATABASE ${var.db_name};' --user=root --password=${var.db_pass}",
	    "/usr/bin/mysql -e \"CREATE USER '${var.db_user}'@'%';\" --user=root --password=${var.db_pass}",
	    "/usr/bin/mysql -e \"SET PASSWORD FOR '${var.db_user}'@'%'=PASSWORD('${var.db_pass}');\" --user=root --password=${var.db_pass}",
	    "/usr/bin/mysql -e \"GRANT ALL PRIVILEGES ON ${var.db_name}.* TO '${var.db_user}'@'%'IDENTIFIED BY '${var.db_pass}';\" --user=root --password=${var.db_pass}",
	    "/usr/bin/mysql -e \"FLUSH PRIVILEGES;\" --user=root --password=${var.db_pass}",
	    "/usr/bin/mysql --user=${var.db_user} --password=${var.db_pass} < /opt/nsx/medicalapp.sql ${var.db_name}"
	]
    }

}

# Tag the newly created VM, so it will becaome a member of my NSGroup
# that way all fw rules we have defined earlier will be applied to it
resource "nsxt_vm_tags" "vm3_tags" {
    instance_id = "${vsphere_virtual_machine.dbvm.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
    tag {
	scope = "tier"
	tag = "db"
    }
}
