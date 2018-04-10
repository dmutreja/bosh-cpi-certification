data "oci_identity_compartments" "Compartments" {
  compartment_id = "${var.oracle_tenancy_ocid}"
  filter {
    name = "name"
    values = ["${var.oracle_compartment_name}"]
  }
}

data "null_data_source" "SetupConfig" {
  inputs = {
    compartment_id = "${lookup(data.oci_identity_compartments.Compartments.compartments[0],"id")}"
  }
}