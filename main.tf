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
variable "nsx_switch_name" {
    default = "terraform-demo-ls"
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
    default = "192.168.245.10"
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

# Create NSX-T Logical Switch
resource "nsxt_logical_switch" "switch1" {
    admin_state = "UP"
    description = "LS created by Terraform"
    display_name = "${var.nsx_switch_name}"
    transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
    replication_mode = "MTEP"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
    tag {
	scope = "tenant"
	tag = "second_example_tag"
    }
    provisioner "local-exec" { # WORKAROUND FOR A KNOWN ISSUE. WILL BE FIXED IN NEXT NSX RELEASE
	command = "sleep 10"
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

# Create a switchport on our logical switch
resource "nsxt_logical_port" "logical_port1" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "LP1"
  logical_switch_id = "${nsxt_logical_switch.switch1.id}"
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

# Create NSService for multiple ports, we will use it later in the fw section for some rules
resource "nsxt_l4_port_set_ns_service" "http_l4" {
  description       = "L4 Port range provisioned by Terraform"
  display_name      = "HTTP"
  protocol          = "TCP"
  destination_ports = ["80", "8080", "443", "8443"]
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

# Allow communication to my VMs only on the ports we defined earlier as NSService
  rule {
    display_name = "Allow IN"
    description  = "In going rule"
    action       = "ALLOW"
    logged       = false
    ip_protocol  = "IPV4"
    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.nsgroup.id}"
    }
    service {
      target_type = "NSService"
      target_id   = "${nsxt_l4_port_set_ns_service.http_l4.id}"
    }
    service {
      target_type = "NSService"
      target_id   = "${nsxt_l4_port_set_ns_service.ssh_l4.id}"
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
  display_name              = "1to1-in"
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
  display_name              = "1to1-out"
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

# Create SNAT rule to enable all VMs in my network to access outside
resource "nsxt_nat_rule" "rule3" {
  logical_router_id         = "${nsxt_logical_tier1_router.tier1_router.id}"
  description               = "SNAT provisioned by Terraform"
  display_name              = "SNAT rule 1"
  action                    = "SNAT"
  enabled                   = true
  logging                   = false
  nat_pass                  = true
  translated_network        = "10.29.15.228"
  match_source_network      = "192.168.245.0/24"
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
data "vsphere_network" "terraform_switch1" {
    name = "${nsxt_logical_switch.switch1.display_name}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
    depends_on = ["nsxt_logical_switch.switch1"]
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
    name = "t_centos"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Clone a VM from the template above and attach it to the newly created logical switch
resource "vsphere_virtual_machine" "vm" {
    name             = "terraform-test1"
    resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
    datastore_id     = "${data.vsphere_datastore.datastore.id}"
    num_cpus = 1
    memory   = 1024
    guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
    scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"
    # Attach the VM to the network data source that refers to the newly created logical switch
    network_interface {
      network_id = "${data.vsphere_network.terraform_switch1.id}"
    }
    disk {
	label = "terraform-test1.vmdk"
        size = 16
        thin_provisioned = true
    }
    clone {
	template_uuid = "${data.vsphere_virtual_machine.template.id}"

	# Guest customization to supply hostname and ip addresses to the guest
	customize {
	    linux_options {
		host_name = "vm1"
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
	    "/usr/bin/systemctl stop firewalld",
	    "/usr/bin/systemctl disable firewalld",
	    "/usr/bin/yum makecache",
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
    instance_id = "${vsphere_virtual_machine.vm.id}"
    tag {
	scope = "${var.nsx_tag_scope}"
	tag = "${var.nsx_tag}"
    }
}
