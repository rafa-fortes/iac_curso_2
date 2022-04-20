module "aws-dev" {
   source = "../../infra"
   instancia = "t2.micro"
   regiao_aws = "us-west-2"
   chave = "IaC-DEV"
   grupoDeSeguranca = "Dev"
   nomeGrupo = "DEV"
   minimo = 0
   maximo = 1
   producao = false
}
