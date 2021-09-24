provider "aws" {
  region = var.region
}

resource "aws_vpc" "peer" {
  cidr_block = "172.31.0.0/16"
}

data "aws_arn" "peer" {
  arn = aws_vpc.peer.arn
}

resource "hcp_aws_network_peering" "peer" {
  hvn_id              = hcp_hvn.example_hvn.hvn_id
  peering_id          = var.peering_id
  peer_vpc_id         = aws_vpc.peer.id
  peer_account_id     = aws_vpc.peer.owner_id
  peer_vpc_region     = data.aws_arn.peer.region
}

resource "hcp_hvn_route" "peer_route" {
  hvn_link         = hcp_hvn.example_hvn.self_link
  hvn_route_id     = var.route_id
  destination_cidr = aws_vpc.peer.cidr_block
  target_link      = hcp_aws_network_peering.peer.self_link
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = hcp_aws_network_peering.peer.provider_peering_id
  auto_accept               = true
}

resource "aws_ec2_transit_gateway" "example" {
  tags = {
    Name = "example-tgw"
  }
}

resource "aws_ram_resource_share" "example" {
  name                      = "example-resource-share"
  allow_external_principals = true
}

resource "aws_ram_principal_association" "example" {
  resource_share_arn = aws_ram_resource_share.example.arn
  principal          = hcp_hvn.example_hvn.provider_account_id
}

resource "aws_ram_resource_association" "example" {
  resource_share_arn = aws_ram_resource_share.example.arn
  resource_arn       = aws_ec2_transit_gateway.example.arn
}

resource "hcp_aws_transit_gateway_attachment" "example" {
  depends_on = [
    aws_ram_principal_association.example,
    aws_ram_resource_association.example,
  ]

  hvn_id                        = hcp_hvn.example_hvn.hvn_id
  transit_gateway_attachment_id = "example-tgw-attachment"
  transit_gateway_id            = aws_ec2_transit_gateway.example.id
  resource_share_arn            = aws_ram_resource_share.example.arn
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "example" {
  transit_gateway_attachment_id = hcp_aws_transit_gateway_attachment.example.provider_transit_gateway_attachment_id
}
