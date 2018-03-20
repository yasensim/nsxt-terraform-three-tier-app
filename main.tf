# configure some variables first 
variable "nsx_ip" {
    default = "10.29.15.73"
}
variable "nsx_password" {
    default = "VMware1!"
}

variable "nsx_tag_scope" {
    default = "project"
}
variable "nsx_tag" {
    default = "terraform-demo"
}
variable "nsx_t1_router_name" {
    default = "terraform-demo-router"
}
variable "vsphere_user" {
    default = "administrator@yasen.local"
}
variable "vsphere_password" {
    default = "VMware1!"
}
variable "vsphere_ip" {
    default = "10.29.15.69"
}

variable "db_user" {
    default = "medicalappuser"
}
variable "db_name" {
    default = "medicalapp"
}
variable "app_listen" {
    default = "8443"
}
variable "db_pass" {
    default = "VMware1!"
}
variable "db_host" {
    default = "192.168.247.2"
}


# Configure the VMware NSX-T Provider
provider "nsxt" {
    host = "${var.nsx_ip}"
    username = "admin"
    password = "${var.nsx_password}"
    allow_unverified_ssl = true
}

# Create the data sources we will need to refer to later
data "nsxt_transport_zone" "overlay_tz" {
    display_name = "tz1"
}
data "nsxt_logical_tier0_router" "tier0_router" {
  display_name = "DefaultT0Router"
}
data "nsxt_edge_cluster" "edge_cluster1" {
    display_name = "EdgeCluster1"
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
  display_name                = "${var.nsx_t1_router_name}"
  failover_mode               = "PREEMPTIVE"
  high_availability_mode      = "ACTIVE_STANDBY"
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

# Create DHCP RELAY PROFILE
resource "nsxt_dhcp_relay_profile" "dr_profile" {
  description  = "DHCP Relay Profile provisioned by Terraform"
  display_name = "DHCPRelayProfile1"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
  server_addresses = ["1.1.1.1"]
}

# Create DHCP RELAY SERVICE based on the profile above
resource "nsxt_dhcp_relay_service" "dr_service" {
  display_name          = "DHCPRelayService"
  dhcp_relay_profile_id = "${nsxt_dhcp_relay_profile.dr_profile.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create downlink port on the T1 router and connect it to the switchport we created earlier
# as well as to the DHCP relay service
resource "nsxt_logical_router_downlink_port" "downlink_port" {
  description                   = "DP1 provisioned by Terraform"
  display_name                  = "DP1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_switch_port_id = "${nsxt_logical_port.logical_port1.id}"
  ip_address                    = "192.168.245.1/24"
  service_binding {
    target_id   = "${nsxt_dhcp_relay_service.dr_service.id}"
    target_type = "LogicalService"
  }
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Althought we dont need it at the moment we create a static route on the T0
resource "nsxt_static_route" "static_route" {
  description       = "SR provisioned by Terraform"
  display_name      = "SR"
  logical_router_id = "${nsxt_logical_tier1_router.tier1_router.id}"
  network           = "4.4.4.0/24"
  next_hop {
    ip_address              = "192.168.245.100"
    administrative_distance = "1" 
    logical_router_port_id  = "${nsxt_logical_router_downlink_port.downlink_port.id}"
  }
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
  ip_address                    = "10.29.15.209/28"
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
  ip_address                    = "192.168.247.1/24"
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

# Create NSService for App service that listens on port 8443
resource "nsxt_l4_port_set_ns_service" "app" {
  description       = "L4 Port range provisioned by Terraform"
  display_name      = "App Service"
  protocol          = "TCP"
  destination_ports = ["8443"]
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}
# Create NSService for multiple ports, we will use it later in the fw section for some rules
resource "nsxt_l4_port_set_ns_service" "web" {
  description       = "L4 Port range provisioned by Terraform"
  display_name      = "HTTP"
  protocol          = "TCP"
  destination_ports = ["443", "80"]
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create NSService for MySQL
resource "nsxt_l4_port_set_ns_service" "mysql" {
  description       = "L4 Port range provisioned by Terraform"
  display_name      = "MySQL"
  protocol          = "TCP"
  destination_ports = ["3306"]
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}


# Create NSService for SSH, we will use it later in the fw section for some rules
resource "nsxt_l4_port_set_ns_service" "ssh_l4" {
  description       = "L4 Port range provisioned by Terraform"
  display_name      = "SSH"
  protocol          = "TCP"
  destination_ports = ["22"]
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
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
  ip_addresses = ["10.19.12.201", "10.29.12.219", "10.29.12.220"]
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
      target_id   = "${nsxt_l4_port_set_ns_service.web.id}"
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
      target_id   = "${nsxt_l4_port_set_ns_service.ssh_l4.id}"
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
      target_id   = "${nsxt_l4_port_set_ns_service.mysql.id}"
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

# Create 1 to 1 NAT for outgoing traffic from one VM
resource "nsxt_nat_rule" "rule1" {
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "App 1to1-in"
  action                    = "SNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "10.29.15.229"
  match_source_network      = "192.168.245.2/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create 1 to 1 NAT for incomming traffic to one VM
resource "nsxt_nat_rule" "rule2" {
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "App 1to1-out"
  action                    = "DNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "192.168.245.2"
  match_destination_network = "10.29.15.229/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create 1 to 1 NAT for outgoing traffic from one VM
resource "nsxt_nat_rule" "rule3" {
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "App 1to1-in"
  action                    = "SNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "10.29.15.228"
  match_source_network      = "192.168.247.2/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}

# Create 1 to 1 NAT for incomming traffic to one VM
resource "nsxt_nat_rule" "rule4" {
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "1 to 1 NAT provisioned by Terraform"
  display_name              = "App 1to1-out"
  action                    = "DNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "192.168.247.2"
  match_destination_network = "10.29.15.228/32"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}
# Create SNAT rule to enable all VMs in my network to access outside
resource "nsxt_nat_rule" "rule5" {
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "SNAT provisioned by Terraform"
  display_name              = "SNAT rule 1"
  action                    = "SNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "10.29.15.230"
  match_source_network      = "192.168.0.0/16"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}


# Configure the VMware vSphere Provider
provider "vsphere" {
    user           = "${var.vsphere_user}"
    password       = "${var.vsphere_password}"
    vsphere_server = "${var.vsphere_ip}"
    allow_unverified_ssl = true
}

# data source for my vSphere Data Center
data "vsphere_datacenter" "dc" {
  name = "MyDC1"
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
  name          = "NFS"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# data source for my cluster's default resource pool
data "vsphere_resource_pool" "pool" {
  name          = "T_Cluster/Resources"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Data source for the template I am going to use to clone my VM from
data "vsphere_virtual_machine" "template" {
    name = "t_template_novra"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Clone a VM from the template above and attach it to the newly created logical switch
resource "vsphere_virtual_machine" "appvm" {
    name             = "tf-app"
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
	label = "tf-app.vmdk"
        size = 16
        thin_provisioned = true
    }
    clone {
	template_uuid = "${data.vsphere_virtual_machine.template.id}"

	# Guest customization to supply hostname and ip addresses to the guest
	customize {
	    linux_options {
		host_name = "tfapp"
		domain = "yasen.local"
	    }
	    network_interface {
		ipv4_address = "192.168.245.2"
		ipv4_netmask = 24
		dns_server_list = ["10.29.12.201", "8.8.8.8"]
		dns_domain = "yasen.local"
	    }
	    ipv4_gateway = "192.168.245.1"
	}
    }
    connection {
	type = "ssh",
	agent = "false"
	# refer to the network interface if you have direct routing to this ip space
	#host = "${vsphere_virtual_machine.vm.network_interface.0.ipv4_address}"
	# refer to the network interface if you have direct routing to this ip space
	host = "10.29.15.229"
	user = "root"
	password = "VMware1!"
	script_path = "/root/tf.sh"
    }
    provisioner "remote-exec" {
	inline = [ 
	    "echo 'nameserver 10.29.12.201' >> /etc/resolv.conf", # By some reason guest customization didnt configure DNS, so this is a workaround
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
	    "/bin/sed -i 's/MEDAPP_DB_HOST/${var.db_host}/g' /var/www/html2/index.php",
	    "/bin/sed -i 's/MEDAPP_DB_NAME/${var.db_name}/g' /var/www/html2/index.php",
	    
	    # httpd configuration
	    "/usr/bin/echo 'ServerName appserver.corp.local' > /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo 'Listen ${var.app_listen}' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo 'SSLCertificateFile /etc/ssl/cert.pem' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo 'SSLCertificateKeyFile /etc/ssl/cert.key' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '' >> /etc/httpd/conf.d/ssl.conf",
	    "/usr/bin/echo '<VirtualHost _default_:${var.app_listen}>' >> /etc/httpd/conf.d/ssl.conf",
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
    name             = "tf-web"
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
	label = "tf-web.vmdk"
        size = 16
        thin_provisioned = true
    }
    clone {
	template_uuid = "${data.vsphere_virtual_machine.template.id}"

	# Guest customization to supply hostname and ip addresses to the guest
	customize {
	    linux_options {
		host_name = "tfweb"
		domain = "yasen.local"
	    }
	    network_interface {
		ipv4_address = "10.29.15.210"
		ipv4_netmask = 28
		dns_server_list = ["10.29.12.201", "8.8.8.8"]
		dns_domain = "yasen.local"
	    }
	    ipv4_gateway = "10.29.15.209"
	}
    }
    connection {
	type = "ssh",
	agent = "false"
	# refer to the network interface if you have direct routing to this ip space
	host = "10.29.15.210"
	# refer to the network interface if you have direct routing to this ip space
	user = "root"
	password = "VMware1!"
	script_path = "/root/tf.sh"
    }
    provisioner "remote-exec" {
	inline = [ 
	    "echo 'nameserver 10.29.12.201' >> /etc/resolv.conf", # By some reason guest customization didnt configure DNS, so this is a workaround
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
	    "/usr/bin/echo \"    proxy_pass https://192.168.245.2:${var.app_listen};\" >> /etc/nginx/default.d/ssl.conf",
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
    name             = "tf-db"
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
	label = "tf-db.vmdk"
        size = 16
        thin_provisioned = true
    }
    clone {
	template_uuid = "${data.vsphere_virtual_machine.template.id}"

	# Guest customization to supply hostname and ip addresses to the guest
	customize {
	    linux_options {
		host_name = "tfdb"
		domain = "yasen.local"
	    }
	    network_interface {
		ipv4_address = "192.168.247.2"
		ipv4_netmask = 24
		dns_server_list = ["10.29.12.201", "8.8.8.8"]
		dns_domain = "yasen.local"
	    }
	    ipv4_gateway = "192.168.247.1"
	}
    }
    connection {
	type = "ssh",
	agent = "false"
	# refer to the network interface if you have direct routing to this ip space
	#host = "${vsphere_virtual_machine.vm.network_interface.0.ipv4_address}"
	# refer to the network interface if you have direct routing to this ip space
	host = "10.29.15.228"
	user = "root"
	password = "VMware1!"
	script_path = "/root/tf.sh"
    }
    provisioner "remote-exec" {
	inline = [ 
	    "echo 'nameserver 10.29.12.201' >> /etc/resolv.conf", # By some reason guest customization didnt configure DNS, so this is a workaround
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
