module "aws-prod" {
   source = "../../infra"
   instancia = "t2.micro"
   regiao_aws = "us-west-2"
   chave = "IaC-Prod"
   grupoDeSeguranca = "Producao"
   nomeGrupo = "Prod"
   minimo = 2
   maximo = 10
   producao = true
    
}

# output "IP" {
#     value = module.aws-prod.IP_publico
# }