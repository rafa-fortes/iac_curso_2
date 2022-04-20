resource "aws_security_group" "acesso_geral" {
    name = var.grupoDeSeguranca          // Alterarmos o nome para ser essa variável
    ingress{                            // ingress que é entrada da máquina. 
        cidr_blocks = [ "0.0.0.0/0" ]  // Aqui são os IPs do tipo IPv4 que podem entrar. Então ele aceita string "0.0.0.0/0" para ser todas as máquinas e o "/0" para ele poder alterar à vontade qualquer um desses IPs. Então assim disponibilizamos todos os IPs.
        ipv6_cidr_blocks = [ "::/0" ]  // Aqui são os IPs do tipo IPv6 que podem entrar.
        from_port = 0                 // Como a porta 0 não é uma porta real, digamos assim, as portas começam no número 1, então quando você coloca número 0 você está indicando todas as portas.
        to_port = 0
        protocol = "-1"               // Podemos definir "HTTP", "HTTPs", "SSH" ou podemos definir protocol = “-1” para liberar todos os protocolos.
    } 
    egress{
        cidr_blocks = [ "0.0.0.0/0" ]
        ipv6_cidr_blocks = [ "::/0" ]
        from_port = 0
        to_port = 0
        protocol = "-1" 
    }
    tags = {
        Name = "acesso_geral"
    }
}    