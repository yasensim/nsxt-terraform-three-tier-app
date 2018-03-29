nsx = {
    ip  = "10.29.15.73"
    user = "admin"
    password = "VMware1!"
}
nsx_data_vars = {
    transport_zone  = "tz1"
    t0_router_name = "DefaultT0Router"
    edge_cluster = "EdgeCluster1"
    t1_router_name = "tf-router1"
}
nsx_rs_vars = {
    t1_router_name = "tf-router1"
}

ipset = ["10.19.12.201", "10.29.12.219", "10.29.12.220"]


nsx_tag_scope = "project"
nsx_tag = "terraform-demo"

vsphere{
    vsphere_user = "administrator@yasen.local"
    vsphere_password = "VMware1!"
    vsphere_ip = "10.29.15.69"
    dc = "MyDC1"
    datastore = "NFS"
    resource_pool = "T_Cluster/Resources"
    vm_template = "t_template_novra"
}


app_listen_port = "8443"

db_user = "medicalappuser" # Database details 
db_name = "medicalapp"
db_pass = "VMware1!"

dns_server_list = ["10.29.12.201", "8.8.8.8"]


web = {
    ip = "10.29.15.210"
    gw = "10.29.15.209"
    mask = "28"
    nat_ip = ""
    vm_name = "web"
    domain = "yasen.local"
    connect_to = "10.29.15.210" # If configure_nat is True this must be the same value as nat_ip, otherwise it must be the same value as ip
    user = "root" # Credentails to access the VM
    pass = "VMware1!"
}

app = {
    ip = "192.168.245.2"
    gw = "192.168.245.1"
    mask = "24"
    nat_ip = "10.29.15.229"
    vm_name = "app"
    domain = "yasen.local"
    connect_to = "10.29.15.229"
    user = "root"
    pass = "VMware1!"
}

db = {
    ip = "192.168.247.2"
    gw = "192.168.247.1"
    mask = "24"
    nat_ip = "10.29.15.228" # if configure_nat = False you still need to put something here but it will be ignored
    vm_name = "db"
    domain = "yasen.local"
    connect_to = "10.29.15.228" # If configure_nat is True this must be the same value as nat_ip, otherwise it must be the same value as ip
    user = "root" # Credentails to access the VM
    pass = "VMware1!"
}

