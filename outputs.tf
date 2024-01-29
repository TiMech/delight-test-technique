output "dtt_ec2_ip" {
    value = aws_eip.dtt_compute_eip["dtt-compute-instance-1"].public_ip
    depends_on = [aws_eip.dtt_compute_eip]
}

output "dtt_ec2_dns" {
    value = aws_eip.dtt_compute_eip["dtt-compute-instance-1"].public_dns
    depends_on = [aws_eip.dtt_compute_eip]
}

output "dtt_rds_endpoint" {
    value = aws_db_instance.dtt_rds.address
    depends_on = [aws_db_instance.dtt_rds]
}

output "connect_to_ssh" {
    value = "Commande de connection ssh : ssh -i \"dtt_compute_key\" ec2-user@${aws_eip.dtt_compute_eip["dtt-compute-instance-1"].public_dns} -v"
    depends_on = [aws_eip.dtt_compute_eip]
}